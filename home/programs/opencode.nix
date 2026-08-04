{
  config,
  lib,
  pkgs,
  ...
}:
let
  sources = import ../../npins;
  pluginsDir = "${sources.plugin-marketplace}/plugins";

  subDirs =
    dir: builtins.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir dir));

  # opencode consumes bare skill directories rather than plugin manifests, so
  # any `SKILL.md` tree Claude Code already uses works here unchanged — the
  # frontmatter contract is the same. Both agents read the same registry
  # (`agent-plugins.nix`) rather than one reading the other's settings.
  inherit (config.agentPlugins) enabled;

  # Marketplaces don't agree on where a plugin lives: `dlrobson-plugins` and
  # `claude-plugins-official-mirror` nest under `plugins/`, `ast-grep-marketplace`
  # puts it at the top level, and `engram` *is* the plugin. Probe the three
  # layouts for one that has the requested subdirectory; a plugin that ships
  # none of it (e.g. `claude-code-lsps`, whose value is superseded here by
  # `lsp = true`) simply contributes nothing.
  contentDirOf =
    kind: name: marketplace:
    let
      src = config.agentPlugins.marketplaces.${marketplace};
      candidates = map (dir: "${dir}/${kind}") [
        "${src}/plugins/${name}"
        "${src}/${name}"
        "${src}"
      ];
    in
    lib.findFirst builtins.pathExists null candidates;

  contentDirs =
    kind:
    lib.filter (dir: dir != null) (
      map (
        ref:
        let
          parts = lib.splitString "@" ref;
        in
        contentDirOf kind (builtins.head parts) (lib.last parts)
      ) enabled
    );

  skillsDirOf = contentDirOf "skills";

  # A plugin that ships a native opencode plugin (superpowers vendors
  # `.opencode/plugins/superpowers.js`) is left to install itself. Its plugin
  # pushes its own skills directory onto `config.skills.paths` at runtime, so
  # copying the same skills in through the `skills` option as well would
  # register every one of them twice. It also injects a bootstrap preamble
  # translating skill instructions to opencode's tool names — the thing we
  # hand-rewrite for agents — so upstream's own translation is preferable to
  # ours.
  nativePluginDirOf = contentDirOf ".opencode/plugins";

  hasNativePlugin =
    ref:
    let
      parts = lib.splitString "@" ref;
    in
    nativePluginDirOf (builtins.head parts) (lib.last parts) != null;

  # Vendored from the pinned source rather than declared in `settings.plugin`,
  # which takes npm specs that Bun resolves over the network at startup —
  # upstream's documented `superpowers@git+https://...` install. The plugin
  # resolves its skills relative to its own realpath, which stays inside the
  # store path through the symlink, so linking the file alone is enough.
  nativePluginFiles = lib.listToAttrs (
    lib.concatMap (
      ref:
      let
        parts = lib.splitString "@" ref;
        dir = nativePluginDirOf (builtins.head parts) (lib.last parts);
      in
      lib.optionals (dir != null) (
        map (file: lib.nameValuePair "opencode/plugins/${file}" { source = "${dir}/${file}"; }) (
          lib.filter (lib.hasSuffix ".js") (builtins.attrNames (builtins.readDir dir))
        )
      )
    ) enabled
  );

  # Skill directory names are unique across the enabled set today. If two
  # plugins ever ship the same skill name, `listToAttrs` keeps the last — which
  # would silently shadow one, so `run-tests` output is worth a glance when
  # enabling a new marketplace.
  marketplaceSkills = lib.listToAttrs (
    lib.concatMap (
      ref:
      let
        parts = lib.splitString "@" ref;
        skillsDir = skillsDirOf (builtins.head parts) (lib.last parts);
      in
      lib.optionals (skillsDir != null) (
        map (skill: lib.nameValuePair skill "${skillsDir}/${skill}") (
          # A `skills/` tree can hold non-skill directories of shared assets
          # (engram's `_shared`), which opencode would reject for having no
          # frontmatter — a `SKILL.md` is what makes a directory a skill.
          lib.filter (skill: builtins.pathExists "${skillsDir}/${skill}/SKILL.md") (subDirs skillsDir)
        )
      )
    ) (lib.filter (ref: !hasNativePlugin ref) enabled)
  );

  # Claude and opencode both define agents as markdown with YAML frontmatter,
  # but the dialects differ, so the files can't be linked through as skills are:
  #   - `name`  — opencode takes the identifier from the filename instead
  #   - `model` — opencode wants `provider/model`; Claude's `opus`/`inherit`
  #                are meaningless to it. Dropping the key inherits the default
  #                model, which is the intent of `inherit` anyway.
  #   - `color` — no opencode equivalent
  #   - `tools` — kept, but translated: both harnesses have the key and
  #                disagree on names and shape. See `mapTools` below.
  #   - `mode`  — required here, absent there. Without `mode: subagent` these
  #                would register as primary (Tab-switchable) agents, but they
  #                exist to be dispatched by a primary agent, not talked to.
  # The rewrite happens at build time, so the result is a plain store path with
  # no runtime translation step.
  #
  # Only top-level keys are stripped: the `^` anchors matter because a block
  # scalar (`description: |`, as `code-simplifier` uses) indents its content,
  # so a body line can never be mistaken for a key.

  # opencode's tool ids, read out of the binary rather than the docs. An
  # allowlist has to name every one of them: opencode treats an unlisted tool
  # as *enabled*, so restricting to a few means explicitly disabling the rest.
  # The cost of that is this list going stale — a tool added upstream is
  # silently granted to restricted agents until it's added here.
  opencodeTools = [
    "bash"
    "edit"
    "write"
    "read"
    "grep"
    "glob"
    "list"
    "patch"
    "task"
    "skill"
    "webfetch"
    "websearch"
    "todowrite"
    "question"
    "lsp"
  ];

  # Claude's tool names lowercase directly onto opencode's for everything our
  # agents actually use (Read, Write, Grep, Glob, Bash, WebSearch, WebFetch).
  # These are the few that don't.
  toolAliases = [
    "askuserquestion=question"
    "ls=list"
    "notebookread=read"
  ];

  rewriteMarkdown =
    {
      name,
      dirs,
      dropKeys,
      addLines ? [ ],
      substitutions ? [ ],
      mapTools ? false,
    }:
    pkgs.runCommand name { } ''
      mkdir -p "$out"
      for dir in ${lib.escapeShellArgs dirs}; do
        for file in "$dir"/*.md; do
          [ -e "$file" ] || continue
          awk -v mapTools=${if mapTools then "1" else "0"} \
              -v allTools=${lib.escapeShellArg (lib.concatStringsSep " " opencodeTools)} \
              -v aliases=${lib.escapeShellArg (lib.concatStringsSep " " toolAliases)} '
            BEGIN {
              split(allTools, toolList, " ")
              n = split(aliases, pairs, " ")
              for (i = 1; i <= n; i++) { split(pairs[i], kv, "="); alias[kv[1]] = kv[2] }
            }
            NR == 1 && $0 == "---" { inFrontmatter = 1; print; next }
            inFrontmatter && $0 == "---" {
              ${lib.concatMapStrings (line: ''print "${line}"; '') addLines}print
              inFrontmatter = 0; dropping = 0; next
            }
            # A dropped key takes its value with it. The value can span lines
            # — `create-plugin` writes `allowed-tools:` above a bracketed list
            # on twelve following lines — and leaving those behind produces
            # invalid YAML. Keep skipping until the next top-level key, which
            # is the only thing that can appear unindented inside frontmatter.
            inFrontmatter && /^(${dropKeys}):/ { dropping = 1; next }
            # Claude declares an allowlist; opencode wants a per-tool mapping
            # and treats anything unlisted as enabled, so the allowlist has to
            # be expanded into explicit false for every other tool. Handles
            # both spellings upstream uses — ["Read", "Grep"] and Read, Grep —
            # and strips any Bash(git add:*) argument pattern, which opencode
            # expresses through `permission.bash` rather than per agent.
            mapTools && inFrontmatter && /^tools:/ {
              value = substr($0, 7)
              gsub(/[][""]/, "", value)
              delete allowed
              count = split(value, requested, ",")
              for (i = 1; i <= count; i++) {
                tool = requested[i]
                sub(/\(.*/, "", tool)
                gsub(/^[ \t]+|[ \t]+$/, "", tool)
                tool = tolower(tool)
                if (tool in alias) tool = alias[tool]
                if (tool != "") allowed[tool] = 1
              }
              print "tools:"
              for (i = 1; i in toolList; i++)
                print "  " toolList[i] ": " (toolList[i] in allowed ? "true" : "false")
              next
            }
            # Some upstream descriptions are unquoted scalars containing ": "
            # (silent-failure-hunter embeds "Examples:" and "Context:"), which
            # YAML reads as a nested mapping and rejects — the file is already
            # invalid upstream, Claude Code just parses leniently. Re-emit
            # those as a block scalar, which needs no escaping and preserves
            # the text byte for byte. Values that are already quoted or
            # already block scalars are left alone.
            inFrontmatter && /^description: / && $0 !~ /^description: *["\047|>]/ \
              && substr($0, 14) ~ /: / {
              print "description: |-"; print "  " substr($0, 14); next
            }
            inFrontmatter && /^[A-Za-z_-]+:/ { dropping = 0 }
            inFrontmatter && dropping { next }
            { print }
          ' "$file" ${
            lib.concatMapStringsSep " " (expr: "| sed ${lib.escapeShellArg expr}") substitutions
          } > "$out/$(basename "$file")"
        done
      done
    '';

  agentsDir = rewriteMarkdown {
    name = "opencode-agents";
    dirs = contentDirs "agents";
    dropKeys = "name|model|color";
    addLines = [ "mode: subagent" ];
    mapTools = true;
  };

  # Commands need a smaller frontmatter delta than agents: `description` is
  # common to both and nothing has to be added (opencode takes the prompt from
  # the body). `argument-hint` has no opencode equivalent, and `allowed-tools`
  # is dropped for the same names-and-shape mismatch as `tools` above.
  #
  # The body needs three exact-string fixes. `$ARGUMENTS` and the bare agent
  # names it dispatches (`code-reviewer`, ...) already match opencode, so
  # nothing else carries over badly:
  #   1. Seven usage examples invoke the command by its Claude-qualified name.
  #      opencode derives the name from the filename, so `/review-pr`.
  #   2. opencode has no `/agents` listing; subagents surface via `@` mentions.
  #   3. "Agents use appropriate models for their complexity" was true under
  #      Claude Code (code-reviewer on opus, rest inheriting) but is false here
  #      — dropping `model` puts all of them on the default. Leaving the claim
  #      in would assert a differentiation that no longer exists.
  commandsDir = rewriteMarkdown {
    name = "opencode-commands";
    dirs = contentDirs "commands";
    dropKeys = "argument-hint|allowed-tools";
    substitutions = [
      "s|/pr-review-toolkit:review-pr|/review-pr|g"
      "s|^- All agents available in `/agents` list$|- All agents available via `@` mentions|"
      "/^- Agents use appropriate models for their complexity$/d"
    ];
  };

  # Desktop/tmux notification on session.idle — the opencode counterpart to
  # `claude.nix`'s Stop/Notification hooks. Binary paths are substituted in so
  # the plugin doesn't depend on whatever PATH opencode inherits.
  #
  # opencode has no native notification support (the `notify` strings in the
  # binary are HTTP methods and the autoupdate setting), so all three targets
  # — OSC 777, notify-send, tmux — are the plugin's own doing.
  notifyPlugin = pkgs.replaceVars ./opencode-notify.js {
    notifySend = "${pkgs.libnotify}/bin/notify-send";
    tmux = "${pkgs.tmux}/bin/tmux";
  };

  # Same `.mcp.json` that `claude.nix` (via the `nix` plugin) and `codex.nix`
  # read — one source of truth for the mcp-nixos server. opencode's schema
  # differs from Claude's, so translate rather than splat: it wants a `type`
  # discriminator and a single flat argv instead of `command` + `args`.
  # home-manager's opencode module has this exact translation internally, but
  # only reachable through `programs.mcp.servers`, which this repo doesn't use
  # (moving all three agents onto it would be a separate change).
  toOpencodeMcp = _name: server: {
    type = "local";
    command = [ server.command ] ++ (server.args or [ ]);
    enabled = true;
  };
in
{
  # Bypasses `programs.opencode.agents`, which gates on `lib.isPath` and so
  # silently ignores a derivation (`skills` uses `lib.hm.strings.isPathLike`,
  # which does accept one — hence the inconsistency between the two here).
  config.xdg.configFile = {
    "opencode/agents" = {
      source = agentsDir;
      recursive = true;
    };
    "opencode/commands" = {
      source = commandsDir;
      recursive = true;
    };
    # Local plugin files are auto-discovered from this directory; the
    # `settings.plugin` config key is for npm packages only.
    "opencode/plugins/notify.js".source = notifyPlugin;
  }
  // nativePluginFiles;

  config.programs.opencode = {
    # Unconditional, unlike `programs.codex.enable`: Codex is opt-in because
    # its `projects` trust map is inherently per-deployment, whereas opencode
    # has no equivalent machine-specific state.
    enable = true;
    package = config.unstablePkgs.opencode;

    # Same global rules as Claude Code and Codex — single source of truth.
    # The module writes this to `~/.config/opencode/AGENTS.md`.
    context = config.programs.claude-code.context;

    # Runtime deps for the mcp-nixos server below, which launches via
    # `UV_PYTHON=$(which python3) uvx mcp-nixos`. Wrapped onto opencode's own
    # PATH so the module stands alone, even though `claude.nix` also installs
    # them globally for the same reason.
    extraPackages = [
      pkgs.uv
      pkgs.python3
    ];

    skills = marketplaceSkills;

    settings = {
      # Anthropic prohibits third-party harnesses from using Claude Pro/Max
      # OAuth (https://code.claude.com/docs/en/legal-and-compliance), so
      # opencode can't spend the subscription — point it at opencode Zen's
      # free tier instead. The API key is entered interactively via `/connect`
      # and stored in ~/.local/share/opencode/auth.json, so there's nothing to
      # manage here. Note Zen's free models may retain data for training;
      # don't point opencode at anything sensitive.
      model = "opencode/deepseek-v4-flash-free";
      # Built in, so no equivalent of the `claude-code-lsps` marketplace
      # plugins is needed.
      lsp = true;
      mcp = lib.mapAttrs toOpencodeMcp (
        builtins.fromJSON (builtins.readFile "${pluginsDir}/nix/.mcp.json")
      );
      # Ported from `claude.nix`'s `settings.permissions`, with one structural
      # difference: there is no bubblewrap equivalent here. Claude Code can
      # afford to auto-run everything because the sandbox is the safety
      # boundary; opencode has only these pattern rules, so they *are* the
      # boundary. Rules are evaluated last-match-wins, hence the `"*"`
      # catch-all first and the specific overrides after it.
      permission = {
        bash = {
          "*" = "allow";
          # Backstops the "never run sudo" rule in the shared `context` above
          # (prose the model could ignore) with harness-level enforcement,
          # mirroring the `Bash(sudo *)` deny in `claude.nix`.
          "sudo *" = "deny";
          "git push *" = "ask";
          "git reset *" = "ask";
        };
        edit = "allow";
        webfetch = "allow";
        # Reaching outside the project is the one thing the missing sandbox
        # made cheap to do by accident, so keep a prompt on it.
        external_directory = "ask";
      };
    };
  };
}
