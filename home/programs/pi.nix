{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.pi;
  sources = import ../../npins;
  jsonFormat = pkgs.formats.json { };

  # Upstream default, kept as a path rather than a literal so `PI_CODING_AGENT_DIR`
  # only has to be exported if a consumer moves it. The module that will
  # eventually replace this file hardcodes the same string.
  configDir = "${config.home.homeDirectory}/.pi/agent";

  # Skills this repo ships are authored under `./pi/skills/` and built into
  # self-contained directories here; `home.file` symlinks each into
  # `<agent-dir>/skills/` below.
  authoredSkillsDir = ./pi/skills;

  # The docs bundled with the exact Pi build this repo installs. Linking them
  # into a skill as `pi-docs/` keeps the guidance in step with the harness it
  # describes, rather than vendoring a copy that drifts on every pi update.
  # Named away from `references/` so an authored skill can still ship its own.
  piDocs = "${config.unstablePkgs.pi-coding-agent}/lib/node_modules/pi-monorepo/docs";

  mkSkill =
    name:
    pkgs.runCommand "pi-skill-${name}" { } ''
      mkdir -p "$out"
      cp -r ${authoredSkillsDir}/${name}/. "$out/"
      ln -s ${piDocs} "$out/pi-docs"
    '';

  authoredSkills = lib.mapAttrs (name: _: mkSkill name) (
    lib.filterAttrs (_: type: type == "directory") (builtins.readDir authoredSkillsDir)
  );

  # Authored skills plus whatever a consuming deployment adds. Merged rather
  # than replaced so a consumer cannot drop the shared ones by setting the
  # option. Each is symlinked into Pi's conventional `<agent-dir>/skills/`,
  # which makes `home.file` the GC root of the generation, rather than listing
  # store paths in `settings.json`.
  allSkills = authoredSkills // cfg.skills;

  # Agent definitions for the `pi-subagents` extension, authored under
  # `./pi/agents/` as flat Markdown files. Flat rather than a directory per
  # agent, so unlike skills they need no build step to become self-contained —
  # `home.file` symlinks each into `<agent-dir>/agents/`, the user-level scope
  # pi-subagents scans.
  authoredAgentsDir = ./pi/agents;

  authoredAgents =
    lib.mapAttrs'
      (name: _: lib.nameValuePair (lib.removeSuffix ".md" name) (authoredAgentsDir + "/${name}"))
      (
        lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".md" name) (
          builtins.readDir authoredAgentsDir
        )
      );

  # Same merge rule as skills, for the same reason.
  allAgents = authoredAgents // cfg.agents;

  # MCP servers this repo ships, always present in `mcp.json`. `mcp-nixos` is
  # the same server the Claude Code `nix` plugin runs, but taken from nixpkgs
  # rather than launched through `uvx`, so it needs no `uv`, Python or network
  # at runtime and no `PATH` entry — the store path is the command. Unstable,
  # like Pi itself: the server moves quickly and the stable channel lags it by a
  # major version.
  #
  # `direct` exposure declares its two tools (`nix`, `nix_versions`) to the
  # model like built-ins, so it needn't go through `codemode` to look up an
  # option or package — which this repo's own rules ask for before editing nix.
  authoredMcpServers = {
    nixos = {
      command = lib.getExe config.unstablePkgs.mcp-nixos;
      description = "Search NixOS, Home Manager and nix-darwin options, Nixpkgs packages and package versions";
      exposure = "direct";
    };
  };

  # Merged recursively, unlike skills and agents, so a consumer can adjust a
  # shipped server (`pi.mcpServers.nixos.enabled = false`) without restating
  # its `command`.
  allMcpServers = lib.recursiveUpdate authoredMcpServers cfg.mcpServers;

  # Pi only accepts server names made of letters, digits, `_` and `-`.
  badMcpNames = lib.filter (name: builtins.match "[A-Za-z0-9_-]+" name == null) (
    lib.attrNames allMcpServers
  );
in
{
  options.pi = {
    # Off by default so a consuming deployment opts in, matching
    # `claude.enable`. Declared here and never assigned in
    # `home/default.nix`, so a consumer sets it plainly without needing
    # `mkForce` to override anything.
    enable = lib.mkEnableOption "pi";

    # No defaults for the next three: each names a provider or a credential,
    # and a shared dotfiles repo doesn't know which subscription a given machine
    # pays for. Left null the corresponding key is omitted from the generated
    # JSON rather than asserted, so enabling pi never obliges a consumer to
    # configure a provider it doesn't want.
    provider = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "opencode-go";
      description = ''
        Provider to start on, written as `defaultProvider` in settings.json.
        Any of Pi's built-in providers works; `/login` and `/model` switch
        between them interactively.

        Anthropic prohibits third-party harnesses from using Claude Pro/Max
        OAuth (https://code.claude.com/docs/en/legal-and-compliance), so Pi
        cannot spend a Claude subscription either — hence a separate
        subscription-backed provider such as OpenCode's `opencode-go`.
      '';
    };

    model = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "deepseek-v4.1-flash";
      description = ''
        Model ID to start on, written as `defaultModel` in settings.json. A
        bare model ID, not `provider/model` — the provider is
        {option}`pi.provider`'s half of the pair, and Pi splits the two.
      '';
    };

    auth = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "!cat /run/agenix/opencode-go";
      description = ''
        Shell command whose standard output is the API key, written to
        {file}`auth.json` under {option}`pi.provider`. Pi runs it when the key
        is first needed and caches the result for the process lifetime.

        The `!` prefix is Pi's own credential-command syntax
        (https://pi.dev/docs/latest/providers), and it exists precisely so a
        secret manager can supply the key without it ever being resolved to
        disk. Pointing it at an agenix-decrypted file keeps the secret out of
        the world-readable Nix store while leaving nothing in this repo to
        decrypt — the same split `paseo.environmentFile` already uses.

        Note the failure mode is quiet: empty output, a timeout, or a nonzero
        exit leaves the key unresolved until Pi restarts, rather than reporting
        a missing file. A `/run` path is gone after every reboot until the
        secret service runs again.
      '';
    };

    context = lib.mkOption {
      type = lib.types.either lib.types.lines lib.types.path;
      default = ./agent-rules.md;
      defaultText = lib.literalExpression "./agent-rules.md";
      description = ''
        Global rules written to {file}`AGENTS.md` in Pi's agent directory,
        which Pi loads for every working directory. Either inline text or a
        path to a file.

        Defaults to the shared {file}`agent-rules.md` — the same rules Claude
        Code uses — so no harness owns the source. Override it to give Pi its
        own.
      '';
      example = lib.literalExpression "./AGENTS.md";
    };

    # Authored skills in this repo are wired by the module itself (see
    # `authoredSkills` above); this option is the extension point for a
    # consuming deployment's own skills. Values are merged with the shipped
    # ones rather than replacing them.
    skills = lib.mkOption {
      type = lib.types.attrsOf (lib.types.either lib.types.package lib.types.path);
      default = { };
      example = {
        pdf-tools = ./skills/pdf-tools;
      };
      description = ''
        User-level skills to install, keyed by a local identifier. Pi derives
        the real skill name from each directory's `SKILL.md`, so the key only
        names the entry here.

        Each value is a directory containing `SKILL.md` — a path in a consuming
        repo or a derivation producing one. Symlinked into
        {file}`<agent-dir>/skills/`, Pi's conventional skill directory, so Pi
        discovers it through its normal discovery rather than through a
        settings key.
      '';
    };

    # Authored agents in this repo are wired by the module itself (see
    # `authoredAgents` above); this option is the extension point for a
    # consuming deployment's own agents. Values are merged with the shipped
    # ones rather than replacing them.
    agents = lib.mkOption {
      type = lib.types.attrsOf (lib.types.either lib.types.package lib.types.path);
      default = { };
      example = {
        security-reviewer = ./agents/security-reviewer.md;
      };
      description = ''
        Agent definitions for Pi's subagent extension, keyed by the runtime
        name and written without the `.md` suffix — the module adds it.

        Each value is a Markdown file with YAML frontmatter, either a path in a
        consuming repo or a derivation producing one, symlinked into
        {file}`<agent-dir>/agents/`, the user-level scope `pi-subagents` scans.
        The `pi-subagents` package is installed alongside `pi-web-access`, so
        the extension is present wherever this module is enabled.
      '';
    };

    # Written verbatim to `mcp.json` rather than modelled as a submodule: Pi
    # owns that schema (stdio vs HTTP, `oauth`, `exposure`, ...) and extends
    # it between releases, so a typed copy here would only lag behind it.
    # Pi itself validates entries and reports bad ones at startup.
    mcpServers = lib.mkOption {
      type = lib.types.attrsOf jsonFormat.type;
      default = { };
      example = lib.literalExpression ''
        {
          filesystem = {
            command = "npx";
            args = [ "-y" "@modelcontextprotocol/server-filesystem" "." ];
          };
          docs = {
            url = "https://example.com/mcp";
            headers.Authorization = "!echo Bearer $(cat /run/agenix/docs-token)";
          };
          sentry.url = "https://mcp.sentry.dev/mcp";
        }
      '';
      description = ''
        MCP servers to connect, keyed by server name and written as the
        `mcpServers` object of {file}`mcp.json` in Pi's agent directory. Each
        value is an entry in Pi's own format (https://pi.dev/docs/latest/mcp):
        `command`/`args`/`env` for a stdio server, or `url`/`headers`/`oauth`
        for a streamable-HTTP one, plus `exposure`, `enabled` and the rest.

        Server names may contain only letters, digits, `_` and `-`.

        This module always ships a `nixos` server (`mcp-nixos`, from nixpkgs)
        and merges these entries over it recursively, so it cannot be dropped
        by setting this option. Adjust it by name, e.g.
        `pi.mcpServers.nixos.enabled = false;` to turn it off.

        The generated file lives in the world-readable Nix store, so never put
        a secret in a value. `env` and `headers` values accept `''${VAR}`
        references and `!command` (the whole value must be the command), the
        same credential syntax as {option}`pi.auth` — point it at an
        agenix-decrypted file, e.g. `"!cat /run/agenix/docs-token"`.

        OAuth servers need no credentials here (`sentry.url` above), but
        signing in is a one-off imperative step, `pi mcp login <server>`. Pi
        stores the resulting tokens in {file}`mcp-auth.json`, which this module
        does not manage because Pi rewrites it on every token refresh.

        {file}`mcp.json` is a read-only symlink, so `pi mcp add`/`remove` and
        the exposure and enable toggles in `/mcp` fail rather than drift from
        what is declared here. Change servers through this option.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ config.unstablePkgs.pi-coding-agent ];

    assertions = [
      {
        assertion = cfg.auth == null || cfg.provider != null;
        message = ''
          pi.auth is set to a credential command but pi.provider is null, so
          there is no provider to file it under in auth.json. Set
          `pi.provider`, or clear `pi.auth` to authenticate some other way.
        '';
      }
      {
        # Pi skips an invalid entry and only says so at startup, so a bad name
        # would otherwise surface as a server that is silently missing.
        assertion = badMcpNames == [ ];
        message = ''
          pi.mcpServers has server names Pi rejects: ${lib.concatStringsSep ", " badMcpNames}.
          Names may contain only letters, digits, `_` and `-`.
        '';
      }
    ];

    home.file = {
      # Pi's global rules are AGENTS.md in the agent directory, which it loads
      # for every working directory. `pi.context` defaults to the shared
      # `agent-rules.md` (the same file Claude Code uses), so a
      # consumer can override it to give Pi its own rules. A path is linked
      # as-is; an empty context is indistinguishable from none, so skip it
      # rather than link a blank file.
    }
    // (
      if lib.isPath cfg.context then
        { "${configDir}/AGENTS.md".source = cfg.context; }
      else
        lib.optionalAttrs (cfg.context != "") {
          "${configDir}/AGENTS.md".text = cfg.context;
        }
    )
    // lib.optionalAttrs (cfg.auth != null) {
      # auth.json is always force-overwritten rather than backed up. Pi owns
      # this file — `/login` and `/logout` write to it — so a stale real file
      # (or `.backup`) at the path would make activation skip re-linking it and
      # silently keep serving whatever was there, instead of failing loudly.
      # Same reasoning as the force on `~/.claude/settings.json` in `claude.nix`.
      "${configDir}/auth.json" = {
        force = true;
        source = jsonFormat.generate "pi-auth.json" {
          ${cfg.provider} = {
            type = "api_key";
            key = cfg.auth;
          };
        };
      };
    }
    // {
      # Forced for the same reason as auth.json: Pi owns this file too (`pi mcp
      # add` and the `/mcp` toggles write to it), so a real file left by one of
      # those would otherwise block re-linking. Only the user-level file is
      # generated — Pi's docs keep servers with credentials out of the project
      # `.pi/mcp.json`.
      "${configDir}/mcp.json" = {
        force = true;
        source = jsonFormat.generate "pi-mcp.json" { mcpServers = allMcpServers; };
      };
    }
    // lib.mapAttrs' (
      name: skill: lib.nameValuePair "${configDir}/skills/${name}" { source = skill; }
    ) allSkills
    // lib.mapAttrs' (
      name: agent: lib.nameValuePair "${configDir}/agents/${name}.md" { source = agent; }
    ) allAgents
    // {
      # Always written when Pi is enabled: `tuiMode` and `hideThinkingBlock`
      # are preferences that apply whether or not a provider or model is
      # configured, so they must not be gated behind those two keys.
      "${configDir}/settings.json".source = jsonFormat.generate "pi-settings.json" (
        {
          # Flicker-free alt-screen renderer, matching `tui = "fullscreen"` in
          # `claude.nix`.
          tuiMode = "fullscreen";
          # Hide reasoning blocks in the transcript. Reasoning still runs — this
          # only stops it being rendered, and `/thinking` can reveal the level.
          hideThinkingBlock = true;
          # Web search/fetch, GitHub cloning, PDF and video extraction. The
          # version comes from the `pi-web-access` npins pin, so `update-pins`
          # bumps it (and its hash) without editing this file; Pi compares the
          # installed version against this spec and reinstalls when it changes.
          # `removePrefix` drops the pin's leading `v` (tag `v0.35.0` -> npm
          # `0.35.0`). Pi installs the package into `<agent-dir>/npm` on first
          # start, not into the store.
          #
          # `pi-subagents` supplies the `subagent` tool that the
          # `reviewing-changes` skill dispatches its passes to, and the
          # `<agent-dir>/agents/` scope those pass definitions are installed
          # into. Both pins are GitHub releases whose tags match their npm
          # versions, so neither needs a hand-maintained hash.
          packages = [
            "npm:pi-web-access@${lib.removePrefix "v" sources.pi-web-access.version}"
            "npm:pi-subagents@${lib.removePrefix "v" sources.pi-subagents.version}"
          ];
        }
        // lib.optionalAttrs (cfg.provider != null) { defaultProvider = cfg.provider; }
        // lib.optionalAttrs (cfg.model != null) { defaultModel = cfg.model; }
      );
    };
  };
}
