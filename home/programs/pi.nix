{
  config,
  options,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.pi;
  sources = import ../../pins.nix;
  jsonFormat = pkgs.formats.json { };

  # Upstream default, kept as a path rather than a literal so `PI_CODING_AGENT_DIR`
  # only has to be exported if a consumer moves it. The module that will
  # eventually replace this file hardcodes the same string.
  configDir = "${config.home.homeDirectory}/.pi/agent";

  # Skills this repo ships are authored under `./pi/skills/` and built into
  # self-contained directories here; `home.file` symlinks each into
  # `<agent-dir>/skills/` below.
  authoredSkillsDir = ./pi/skills;

  piPackage = config.unstablePkgs.pi-coding-agent;

  # The docs bundled with the exact Pi build this repo installs. Linking them
  # into a skill as `pi-docs/` keeps the guidance in step with the harness it
  # describes, rather than vendoring a copy that drifts on every pi update.
  # Named away from `references/` so an authored skill can still ship its own.
  piDocs = "${piPackage}/lib/node_modules/pi-monorepo/docs";

  # The reply-style rules are written to APPEND_SYSTEM.md and reused by the
  # `/plain` prompt template, so the two cannot drift. Both files are installed
  # whenever Pi is enabled.
  plainRules = builtins.readFile ./pi/plain/rules.md;

  # Pi takes a lock on auth.json through its *resolved* path (proper-lockfile
  # without `realpath: false`, since 1.5.2), so a symlink into the read-only
  # store makes every credential read fail with EROFS when Pi tries to create
  # `<store-path>.lock` beside it. The generated file stays in the store, but
  # activation installs a real copy rather than linking it.
  authFile = jsonFormat.generate "pi-auth.json" {
    ${cfg.provider} = {
      type = "api_key";
      key = cfg.auth;
    };
  };

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

  # Third-party skills, linked straight from their pins. Pi stops descending at
  # the first directory holding `SKILL.md`, so anything a skill ships below its
  # root (`agents-md` keeps eval fixtures with their own `SKILL.md` files there)
  # is never discovered as a separate skill.
  vendoredSkills = {
    # Audits and refactors AGENTS.md files against the repo: verifies commands
    # and paths, holds a size budget, and cuts lines that prevent no mistake.
    agents-md = "${sources.mblode-agent-skills}/skills/agents-md";
  };

  # Authored and vendored skills plus whatever a consuming deployment adds.
  # Merged rather than replaced so a consumer cannot drop the shared ones by
  # setting the option. Each is symlinked into Pi's conventional `<agent-dir>/skills/`,
  # which makes `home.file` the GC root of the generation, rather than listing
  # store paths in `settings.json`.
  allSkills = authoredSkills // vendoredSkills // cfg.skills;

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
  # the same server `claude.nix` gives Claude Code, taken from nixpkgs rather
  # than launched through `uvx`, so it needs no `uv`, Python or network at
  # runtime and no `PATH` entry — the store path is the command. Unstable,
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

  # A disabled job leaves no unit behind, so a deployment can declare a job
  # once and turn it off per host.
  enabledJobs = lib.filterAttrs (_: job: job.enable) cfg.jobs;

  # Job names become systemd unit names (`pi-job-<name>`), so keep them to the
  # characters a unit name cannot misread.
  badJobNames = lib.filter (name: builtins.match "[A-Za-z0-9_-]+" name == null) (
    lib.attrNames cfg.jobs
  );

  # The window trigger job is left out: its own assertion names the option to
  # set, and its model never falls back to `pi.model`.
  modellessJobs = lib.attrNames (
    lib.filterAttrs (
      name: job: job.model == null && !(cfg.windowTrigger.enable && name == "window-trigger")
    ) enabledJobs
  );

  # A definition counts unless every branch of it is a false `mkIf`, so a
  # consumer's `mkIf` that is off on this host does not trip the assertion.
  isLiveDefinition =
    value:
    if value._type or "" == "merge" then
      lib.any isLiveDefinition value.contents
    else if value._type or "" == "if" then
      value.condition && isLiveDefinition value.content
    else if value._type or "" == "override" then
      isLiveDefinition value.content
    else
      true;

  # Every module definition of `pi.jobs.window-trigger`, this module's
  # included. `attrsOf` merges definitions of one name silently, so more than
  # one while the trigger is enabled means a consumer's job is mixed into it.
  windowTriggerDefinitions = lib.filter (
    def:
    lib.isAttrs def.value && def.value ? window-trigger && isLiveDefinition def.value.window-trigger
  ) options.pi.jobs.definitionsWithLocations;

  # Where `notify` jobs keep their latest answer, their sessions by default,
  # and the `unread` and `failed` markers that `pi-job` and the shell notice
  # read.
  jobsStateRoot = "${config.xdg.stateHome}/pi-jobs";
  jobStateDir = name: "${jobsStateRoot}/${name}";
  notifyJobs = lib.filterAttrs (_: job: job.notify) enabledJobs;

  # Shared by every scheduled run: one-shot, and none of the resources that
  # only matter interactively. Tools, MCP, skills, context files and whether
  # the session is kept are per job. Extensions stay loaded because a provider
  # package in `pi.packages` can decide how a request is authenticated and
  # billed.
  jobArgs =
    job:
    [
      "--print"
    ]
    ++ (
      if job.sessionDir == null then
        [ "--no-session" ]
      else
        [
          "--session-dir"
          job.sessionDir
        ]
    )
    ++ [
      "--thinking"
      job.thinking
    ]
    ++ (
      if job.tools == [ ] then
        [ "--no-tools" ]
      else
        [
          "--tools"
          (lib.concatStringsSep "," job.tools)
        ]
    )
    ++ lib.optionals (!job.mcp) [ "--no-mcp" ]
    ++ lib.optionals (!job.skills) [ "--no-skills" ]
    ++ lib.optionals (!job.contextFiles) [ "--no-context-files" ]
    ++ [
      "--no-prompt-templates"
      "--no-themes"
    ]
    ++ lib.optionals (job.model != null) [
      "--model"
      job.model
    ]
    ++ job.extraArgs;

  # A run works in a fresh directory, `$PI_JOB_DIR`, deleted when it ends:
  # `preRun` writes there, relative attachments are read from there, and the
  # answer lands there before `output` or `postRun` see it. `set -e` stops the
  # run at the first failing step, so Pi never prompts on a partial `preRun`
  # and `postRun` never handles a failed answer.
  #
  # `output` is written through a temporary file beside it, so a failed run
  # leaves the previous answer rather than half of a new one.
  mkJobScript =
    name: job:
    let
      prompt =
        if lib.isPath job.prompt then
          # Read at build time, not run time: a source path from the consuming
          # repo is not in the store, so a unit that pointed at it would break
          # as soon as that checkout moved or disappeared.
          lib.escapeShellArg (builtins.readFile job.prompt)
        else
          lib.escapeShellArg job.prompt;

      # A path literal is copied to the store. An absolute string is used as
      # is. A relative string names a file `preRun` wrote into `$PI_JOB_DIR`.
      attachment =
        file:
        if lib.isPath file || lib.hasPrefix "/" file then
          lib.escapeShellArg "@${file}"
        else
          ''@"$PI_JOB_DIR"/${lib.escapeShellArg file}'';

      step =
        stepName: text:
        pkgs.writeShellScript "pi-job-${name}-${stepName}" ''
          set -euo pipefail
          ${text}
        '';
    in
    pkgs.writeShellScript "pi-job-${name}" ''
      set -euo pipefail
      ${lib.optionalString (job.path != [ ]) ''
        export PATH=${lib.escapeShellArg (lib.makeBinPath job.path)}:"$PATH"
      ''}
      PI_JOB_DIR=$(${pkgs.coreutils}/bin/mktemp -d -t pi-job-${name}.XXXXXX)
      export PI_JOB_DIR
      trap '${pkgs.coreutils}/bin/rm -rf "$PI_JOB_DIR"' EXIT

      ${lib.optionalString (job.preRun != "") ''
        (cd "$PI_JOB_DIR" && ${step "pre-run" job.preRun})
        if [ -e "$PI_JOB_DIR/skip" ]; then
          echo "Skipped: $(${pkgs.coreutils}/bin/cat "$PI_JOB_DIR/skip")"
          exit 0
        fi
      ''}
      ${lib.optionalString (job.sessionDir != null) ''
        ${pkgs.coreutils}/bin/mkdir -p ${lib.escapeShellArg job.sessionDir}
      ''}
      ${piPackage}/bin/pi ${lib.escapeShellArgs (jobArgs job)} -- ${
        lib.concatMapStringsSep " " attachment job.attachments
      } ${prompt} > "$PI_JOB_DIR/answer"

      ${
        if job.output != null then
          ''
            PI_JOB_ANSWER=${lib.escapeShellArg job.output}
            ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$PI_JOB_ANSWER")"
            tmp="$PI_JOB_ANSWER.tmp.$$"
            trap '${pkgs.coreutils}/bin/rm -rf "$PI_JOB_DIR" "$tmp"' EXIT
            ${pkgs.coreutils}/bin/cp "$PI_JOB_DIR/answer" "$tmp"
            ${pkgs.coreutils}/bin/mv -f "$tmp" "$PI_JOB_ANSWER"
          ''
        else
          ''
            PI_JOB_ANSWER="$PI_JOB_DIR/answer"
            ${pkgs.coreutils}/bin/cat "$PI_JOB_ANSWER"
          ''
      }
      export PI_JOB_ANSWER
      ${lib.optionalString (job.postRun != "") ''
        (cd "$PI_JOB_DIR" && ${step "post-run" job.postRun})
      ''}
      ${lib.optionalString job.notify ''
        state=${lib.escapeShellArg (jobStateDir name)}
        ${pkgs.coreutils}/bin/mkdir -p "$state"
        ${pkgs.coreutils}/bin/cp "$PI_JOB_ANSWER" "$state/answer.md.tmp"
        ${pkgs.coreutils}/bin/mv -f "$state/answer.md.tmp" "$state/answer.md"
        ${pkgs.coreutils}/bin/rm -f "$state/failed"
        ${pkgs.coreutils}/bin/date -Is > "$state/unread"
      ''}
    '';

  # Written by `OnFailure=` rather than by the job script, so a run killed by
  # a signal or a timeout is still reported.
  markFailed = pkgs.writeShellScript "pi-job-failed" ''
    set -eu
    state=${lib.escapeShellArg jobsStateRoot}/"$1"
    ${pkgs.coreutils}/bin/mkdir -p "$state"
    ${pkgs.coreutils}/bin/date -Is > "$state/failed"
  '';

  # Bash arrays describing the jobs, read by ./pi/pi-job.bash.
  bashArray = values: "(" + lib.concatMapStringsSep " " lib.escapeShellArg values + ")";
  bashMap =
    attrs:
    "("
    + lib.concatStringsSep " " (
      lib.mapAttrsToList (name: value: "[${lib.escapeShellArg name}]=${lib.escapeShellArg value}") attrs
    )
    + ")";

  piJob = pkgs.writeShellApplication {
    name = "pi-job";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.glow
      pkgs.gnused
      pkgs.jq
    ];
    text = ''
      pi=${piPackage}/bin/pi
      state_root=${lib.escapeShellArg jobsStateRoot}
      jobs=${bashArray (lib.attrNames enabledJobs)}
      declare -A notify=${bashMap (lib.mapAttrs (_: _: "1") notifyJobs)}
      declare -A sessions=${
        bashMap (
          lib.mapAttrs (_: job: job.sessionDir) (lib.filterAttrs (_: job: job.sessionDir != null) enabledJobs)
        )
      }

      ${builtins.readFile ./pi/pi-job.bash}
    '';
  };

  jobCompletions =
    let
      names = jobs: lib.escapeShellArg (lib.concatStringsSep " " (lib.attrNames jobs));
      sessionJobs = lib.filterAttrs (_: job: job.sessionDir != null) enabledJobs;
      answerJobs = lib.filterAttrs (_: job: job.notify || job.sessionDir != null) enabledJobs;
      words = n: "test (count (commandline -opc)) -eq ${toString n}";
    in
    ''
      complete -c pi-job -f
      complete -c pi-job -n __fish_use_subcommand -a list -d 'List jobs and their state'
      complete -c pi-job -n __fish_use_subcommand -a history -d 'List the runs of a job'
      complete -c pi-job -n __fish_use_subcommand -a open -d 'Open the session of a run in Pi'
      complete -c pi-job -n __fish_use_subcommand -a show -d 'Print the answer of a run'
      complete -c pi-job -n __fish_use_subcommand -a run -d 'Start the job now'
      complete -c pi-job -n __fish_use_subcommand -a log -d 'Show the job journal'
      complete -c pi-job -n '__fish_seen_subcommand_from history open; and ${words 2}' -a ${names sessionJobs}
      complete -c pi-job -n '__fish_seen_subcommand_from show; and ${words 2}' -a ${names answerJobs}
      complete -c pi-job -n '__fish_seen_subcommand_from run log; and ${words 2}' -a ${names enabledJobs}
      # The run number, described by when it started.
      complete -c pi-job -n '__fish_seen_subcommand_from open show; and ${words 3}' -k -a '(pi-job __complete-runs (commandline -opc)[3])'
    '';

  # Builtins only, no subprocess, so every new shell stays fast.
  jobNotice = ''
    begin
        set -l ready
        set -l failed
        for name in ${lib.escapeShellArgs (lib.attrNames notifyJobs)}
            test -e ${lib.escapeShellArg jobsStateRoot}/$name/unread; and set -a ready $name
            test -e ${lib.escapeShellArg jobsStateRoot}/$name/failed; and set -a failed $name
        end
        if set -q ready[1]
            echo "Pi jobs ready: "(string join ', ' $ready)". Run 'pi-job open <name>'."
        end
        if set -q failed[1]
            echo "Pi jobs failed: "(string join ', ' $failed)". Run 'pi-job log <name>'."
        end
    end
  '';

  # A way in when the installed Pi will not start. What usually breaks is a file
  # this module generates or a package it installs, and repairing that can need
  # a working Pi. This runs the same harness from a throwaway agent directory and
  # a fresh evaluation of nixpkgs-unstable, so none of the generated files, the
  # installed extensions or the npm packages into `<agent-dir>/npm` are read.
  #
  # `auth.json` is the one file copied across: a provider that needs a credential
  # is not what the fallback is for. `--no-auth` leaves it out as well.
  fallback = pkgs.writeShellApplication {
    name = "pi-fallback";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      auth=1
      while [[ $# -gt 0 ]]; do
        case $1 in
          --no-auth)
            auth=0
            shift
            ;;
          --)
            shift
            break
            ;;
          -h | --help)
            cat <<'USAGE'
      pi-fallback: run Pi from a freshly fetched nixpkgs with an empty agent directory.

      Nothing this module generates is read: settings.json, mcp.json, AGENTS.md,
      skills, prompts, themes, and the npm packages and extensions installed into
      the directory. auth.json is copied so a provider that is already configured
      keeps working. The directory is throwaway and deleted on exit, so no
      session, extension install or fresh login outlives the run.

      Usage: pi-fallback [--no-auth] [pi arguments...]

        --no-auth   Start with no credentials, to log in afresh. Useful when the
                    credential itself is what is failing.

      Needs network access (nixpkgs-unstable is fetched) and nix-shell on PATH.
      USAGE
            exit 0
            ;;
          *) break ;;
        esac
      done

      if ! command -v nix-shell >/dev/null; then
        echo "pi-fallback: nix-shell is not on PATH" >&2
        exit 1
      fi

      dir=$(mktemp -d)
      trap 'rm -rf "$dir"' EXIT

      # `PI_CODING_AGENT_DIR` wins when set, so a consumer that moved the agent
      # directory still gets its credentials copied.
      source_dir=''${PI_CODING_AGENT_DIR:-${configDir}}
      if [[ $auth -eq 1 && -f $source_dir/auth.json ]]; then
        cp "$source_dir/auth.json" "$dir/auth.json"
        echo "pi-fallback: agent dir $dir, credentials copied from $source_dir/auth.json" >&2
      else
        echo "pi-fallback: agent dir $dir, starting with no credentials" >&2
      fi

      # The branch, not this repo's pin: the pin built the install that is broken.
      expr='let pkgs = import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixpkgs-unstable.tar.gz") { }; in pkgs.mkShell { packages = [ pkgs.pi-coding-agent ]; }'

      # `--run` takes one shell string, so quote each argument for it.
      cmd="pi"
      for arg in "$@"; do
        cmd+=" $(printf '%q' "$arg")"
      done

      PI_CODING_AGENT_DIR="$dir" nix-shell -E "$expr" --run "$cmd"
    '';
  };
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

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "npm:@cortexkit/pi-anthropic-auth@2.2.4" ];
      description = ''
        Extra Pi package specs, appended to the ones this module ships
        (`pi-web-access`, `pi-subagents`) in the `packages` key of
        settings.json. Pin a version: Pi reinstalls when the spec changes.
        `settings.json` is a read-only symlink, so `pi install` fails; add
        packages here instead.
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

    # A provider's usage window starts at the first request after the last
    # one expired. A one-word prompt on a schedule opens it before work begins.
    # Enabling it defines the `window-trigger` entry of `pi.jobs`, so the unit
    # is `pi-job-window-trigger`. The name is reserved while it is enabled.
    windowTrigger = {
      enable = lib.mkEnableOption "scheduled one-word Pi prompts that open a provider's usage window";

      schedule = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "*-*-* 06:00:00 America/New_York" ];
        description = "`OnCalendar` entries for the window trigger timer.";
      };

      # No default, like `pi.provider`: which subscription has a window to
      # open is a per-deployment choice.
      model = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "anthropic/claude-haiku-5-5";
        description = ''
          Model the trigger prompts, as `provider/id`, passed to `pi --model`.
          Use the cheapest model on the provider whose window should open.
        '';
      };
    };

    # Any number of prompts on their own schedules. The only job this module
    # defines is `window-trigger`, from `pi.windowTrigger`. Every other job is a
    # deployment's choice, because what is worth reading on a schedule is not
    # this repo's to decide.
    jobs = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, config, ... }:
          {
            options = {
              enable = lib.mkEnableOption "this scheduled Pi job";

              notify = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = ''
                  Whether to keep the job's results for `pi-job` and announce
                  them in new fish shells. Each successful run saves its answer
                  to {file}`$XDG_STATE_HOME/pi-jobs/<name>/answer.md` and marks
                  it unread, and a failed run is marked failed. New interactive
                  fish shells list the unread and failed jobs until
                  `pi-job open`, `pi-job show` or `pi-job log` clears them.

                  Also keeps the session by default, under
                  {file}`$XDG_STATE_HOME/pi-jobs/<name>/sessions`, so
                  `pi-job open <name>` can carry on from the answer. It reopens
                  the session with every tool enabled, not the job's
                  {option}`tools`, because the run is over and a person is now
                  asking the questions.
                '';
              };

              schedule = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                example = [ "*-*-* 07:00:00 America/New_York" ];
                description = ''
                  `OnCalendar` entries for the job's timer, in systemd's calendar
                  syntax. An empty list creates the service without a timer, so
                  `systemctl --user start pi-job-<name>` still runs it on demand.
                '';
              };

              prompt = lib.mkOption {
                type = lib.types.either lib.types.lines lib.types.path;
                example = "Summarise today's top five stories in one paragraph each.";
                description = ''
                  Prompt passed to `pi --print`, as inline text or a path to a
                  file. The file is read when the configuration is built, so the
                  prompt is part of the unit rather than a path the service has
                  to find at run time.

                  The job runs unattended, so the prompt is the whole
                  instruction. There is no conversation to correct it.
                '';
              };

              model = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = cfg.model;
                defaultText = lib.literalExpression "config.pi.model";
                example = "opencode-go/deepseek-v4.1-flash";
                description = ''
                  Model the job prompts, as `provider/id`, passed to `pi --model`.
                  Defaults to {option}`pi.model`, so a deployment sets this only
                  for a job that should use a different one.
                '';
              };

              thinking = lib.mkOption {
                type = lib.types.enum [
                  "off"
                  "minimal"
                  "low"
                  "medium"
                  "high"
                  "xhigh"
                  "max"
                ];
                default = "off";
                description = ''
                  Reasoning level, passed to `pi --thinking`. Off by default
                  because nobody is watching the run: raise it for a job whose
                  answer needs reasoning rather than retrieval.
                '';
              };

              tools = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                example = [
                  "web_search"
                  "fetch_content"
                ];
                description = ''
                  Tools the job may call, passed to `pi --tools` as a
                  comma-separated allowlist. Empty disables every tool with
                  `--no-tools`, the default: a scheduled run reads and writes
                  nothing unless the job names what it needs.

                  Extension tools count, so `pi-web-access`'s `web_search`,
                  `source_check`, `fetch_content` and `get_search_content` are
                  available to a job that lists them.

                  MCP tools are filtered only once an entry starts with `mcp__`.
                  A list with no such entry leaves every MCP tool enabled when
                  {option}`mcp` is on, so name them, e.g.
                  `mcp__slack__slack_search_public`.
                '';
              };

              mcp = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = ''
                  Whether the job connects the servers in {option}`pi.mcpServers`.
                  Off by default, because starting those servers is startup work
                  a scheduled run rarely needs.
                '';
              };

              skills = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = ''
                  Whether the job loads installed skills. Off by default, because
                  a prompt that depends on a skill is better written to say so.
                '';
              };

              contextFiles = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = ''
                  Whether Pi discovers `AGENTS.md` and `CLAUDE.md` from the
                  working directory. Off by default, so a job's behaviour comes
                  from its prompt rather than from whichever repository it runs
                  in.
                '';
              };

              workingDirectory = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                example = "/home/daniel/src/notes";
                description = ''
                  Directory the job runs in, as the unit's `WorkingDirectory`.
                  Null leaves systemd's default, the user's home directory. Pi
                  resolves project configuration and relative paths from it.
                '';
              };

              output = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                example = "/home/daniel/notes/news.md";
                description = ''
                  File the final answer is written to, replacing what was there.
                  Its parent directory is created if missing, and the write goes
                  through a temporary file, so a failed run leaves the previous
                  answer intact.

                  Null sends the answer to the journal instead, readable with
                  `journalctl --user -u pi-job-<name>`. It must be a string, not
                  a Nix path literal: a path literal names a read-only store
                  location.
                '';
              };

              attachments = lib.mkOption {
                type = lib.types.listOf (lib.types.either lib.types.path lib.types.str);
                default = [ ];
                example = lib.literalExpression ''
                  [
                    ./weekly/format.md
                    "activity.json"
                  ]
                '';
                description = ''
                  Files whose contents are added to the prompt, passed to Pi as
                  `@file` ahead of it. A job given its input this way needs no
                  `read` tool to see it.

                  A path literal is copied to the store when the configuration
                  is built. An absolute string is read at run time. A relative
                  string names a file in `$PI_JOB_DIR`, the run's own directory,
                  which is how a file written by {option}`preRun` reaches the
                  prompt.
                '';
              };

              path = lib.mkOption {
                type = lib.types.listOf (lib.types.either lib.types.package lib.types.str);
                default = [ ];
                example = lib.literalExpression "[ pkgs.jq pkgs.glab ]";
                description = ''
                  Packages whose {file}`bin` directories go at the front of
                  `PATH` for the whole run: {option}`preRun`, Pi and its tools,
                  and {option}`postRun`. A string names a prefix such as
                  `config.home.profileDirectory`, whose {file}`bin` is added the
                  same way. A systemd user service otherwise sees only the
                  user manager's `PATH`, which on a non-NixOS host leaves out
                  the Nix profile.
                '';
              };

              preRun = lib.mkOption {
                type = lib.types.lines;
                default = "";
                example = ''
                  curl -fsS https://example.com/status.json > status.json
                '';
                description = ''
                  Shell commands run before Pi, in `$PI_JOB_DIR`, a fresh
                  directory deleted when the run ends. Files written there can be
                  passed to Pi with a relative {option}`attachments` entry. Runs
                  with `set -euo pipefail`, and a failure ends the run before Pi
                  starts.

                  Writing a file named `skip` in `$PI_JOB_DIR` ends the run
                  successfully without Pi, for a run with nothing to do. Its
                  contents go to the journal as the reason. Nothing else
                  happens: no answer is written, {option}`postRun` does not
                  run, and a {option}`notify` job keeps its previous answer and
                  is not marked unread.
                '';
              };

              postRun = lib.mkOption {
                type = lib.types.lines;
                default = "";
                example = ''
                  cp "$PI_JOB_ANSWER" "$HOME/archive/$(date +%F).md"
                '';
                description = ''
                  Shell commands run after Pi succeeds, in `$PI_JOB_DIR`.
                  `$PI_JOB_ANSWER` names the file holding the answer:
                  {option}`output` when it is set, otherwise a file in
                  `$PI_JOB_DIR`. Runs with `set -euo pipefail`, and a failure
                  fails the unit. Not run when Pi or {option}`preRun` fails.
                '';
              };

              sessionDir = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = if config.notify then "${jobStateDir name}/sessions" else null;
                defaultText = lib.literalExpression ''
                  if notify then "''${config.xdg.stateHome}/pi-jobs/<name>/sessions" else null
                '';
                example = "/home/daniel/.local/state/pi-jobs/news";
                description = ''
                  Directory the run's session is saved in, passed to
                  `pi --session-dir`. Null runs with `--no-session`, so nothing
                  is kept.

                  `pi-job open <name>` reopens the newest session to carry on
                  from the answer. Outside `pi-job`, use
                  `pi --session <file>`: session file names start with their
                  creation time, so the last in sort order is the newest.
                  `pi --continue` finds it only when run from the job's
                  {option}`workingDirectory`, because it looks only at sessions
                  started in the current directory. The directory is not
                  pruned, so each run adds a session to it.
                '';
              };

              extraArgs = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                example = [
                  "--no-approve"
                  "--offline"
                ];
                description = ''
                  Extra arguments passed to `pi` after the generated ones and
                  ahead of the prompt, for anything the options above do not
                  cover.
                '';
              };
            };
          }
        )
      );
      default = { };
      example = lib.literalExpression ''
        {
          news = {
            enable = true;
            schedule = [ "*-*-* 07:00:00" ];
            prompt = "Summarise the top five Nix stories from the last day.";
            tools = [ "web_search" "fetch_content" ];
            output = "/home/daniel/notes/news.md";
          };
        }
      '';
      description = ''
        Scheduled Pi prompts, keyed by name. Each enabled entry becomes a
        `pi-job-<name>` systemd user service, plus a timer when it has a
        schedule.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !cfg.windowTrigger.enable || cfg.windowTrigger.model != null;
        message = ''
          pi.windowTrigger is enabled but pi.windowTrigger.model is null, so
          the trigger has no model to prompt. Set it, e.g.
          `pi.windowTrigger.model = "anthropic/claude-haiku-5-5";`.
        '';
      }
      {
        assertion = !cfg.windowTrigger.enable || lib.length windowTriggerDefinitions <= 1;
        message = ''
          pi.windowTrigger is enabled, and it defines pi.jobs.window-trigger, but
          that job is also defined elsewhere, so the two would merge into one.
          Rename the other job, or disable pi.windowTrigger. Definitions:
          ${lib.concatMapStringsSep "\n" (def: "  - ${def.file}") windowTriggerDefinitions}
        '';
      }
      {
        assertion = modellessJobs == [ ];
        message = ''
          pi.jobs has enabled jobs with no model to run: ${lib.concatStringsSep ", " modellessJobs}.
          Set pi.model as the fallback, or set `model` on each job.
        '';
      }
      {
        assertion = badJobNames == [ ];
        message = ''
          pi.jobs has names that cannot become systemd unit names: ${lib.concatStringsSep ", " badJobNames}.
          Names may contain only letters, digits, `-` and `_`.
        '';
      }
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

    home = {
      packages = [
        piPackage
        fallback
      ]
      ++ lib.optional (enabledJobs != { }) piJob;

      file = {
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
        # The reply-style prompt is always installed. `APPEND_SYSTEM.md` adds it to
        # every request, and `/plain` runs the same rules on demand against the
        # previous reply.
        "${configDir}/APPEND_SYSTEM.md".text = plainRules;
        "${configDir}/prompts/plain.md".text = builtins.readFile ./pi/plain/plain.md + plainRules;
      }
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
            ]
            ++ cfg.packages;
          }
          // lib.optionalAttrs (cfg.provider != null) { defaultProvider = cfg.provider; }
          // lib.optionalAttrs (cfg.model != null) { defaultModel = cfg.model; }
        );
      };

      # See `authFile` above for why this is a copy instead of a `home.file`
      # symlink. `mv` replaces the destination rather than writing through it, so
      # the first activation also replaces any old store symlink, and an
      # interrupted activation cannot leave a partial auth.json behind. Pi owns
      # the file (`/login` and `/logout` rewrite it), so each activation restores
      # the declared credential command, matching the previous `force` behaviour.
      activation = lib.optionalAttrs (cfg.auth != null) {
        piAuth = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          $DRY_RUN_CMD install -m 600 ${authFile} "${configDir}/auth.json.tmp"
          $DRY_RUN_CMD mv -f "${configDir}/auth.json.tmp" "${configDir}/auth.json"
        '';
      };
    };

    # The job defaults already leave out tools, MCP, skills, context files,
    # prompt templates, themes, thinking and the session. An empty system
    # prompt removes the last tokens the request does not need. The model is
    # passed as set, so a null one stays null and never becomes `pi.model`.
    pi.jobs.window-trigger = lib.mkIf cfg.windowTrigger.enable {
      enable = true;
      inherit (cfg.windowTrigger) schedule model;
      prompt = "hi";
      extraArgs = [
        "--system-prompt"
        ""
      ];
    };

    xdg.configFile = lib.optionalAttrs (enabledJobs != { }) {
      "fish/completions/pi-job.fish".text = jobCompletions;
    };

    programs.fish.interactiveShellInit = lib.mkIf (notifyJobs != { }) jobNotice;

    systemd.user = {
      services =
        lib.optionalAttrs (notifyJobs != { }) {
          "pi-job-failed@" = {
            Unit.Description = "Mark Pi job %i as failed";
            Service = {
              Type = "oneshot";
              ExecStart = "${markFailed} %i";
            };
          };
        }
        // lib.mapAttrs' (
          name: job:
          lib.nameValuePair "pi-job-${name}" {
            Unit = {
              Description = "Scheduled Pi job: ${name}";
            }
            // lib.optionalAttrs job.notify {
              OnFailure = [ "pi-job-failed@${name}.service" ];
            };
            Service = {
              Type = "oneshot";
              ExecStart = mkJobScript name job;
            }
            // lib.optionalAttrs (job.workingDirectory != null) {
              WorkingDirectory = job.workingDirectory;
            };
          }
        ) enabledJobs;

      timers = lib.mapAttrs' (
        name: job:
        lib.nameValuePair "pi-job-${name}" {
          Unit.Description = "Pi job timer: ${name}";
          Timer = {
            OnCalendar = job.schedule;
            # Catches up a run missed while the machine was off.
            Persistent = true;
          };
          Install.WantedBy = [ "timers.target" ];
        }
      ) (lib.filterAttrs (_: job: job.schedule != [ ]) enabledJobs);
    };
  };
}
