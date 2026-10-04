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
  # which makes `home.file` the GC root of the generation — the same shape
  # `programs.opencode.skills` uses, rather than listing store paths in
  # `settings.json`.
  allSkills = authoredSkills // cfg.skills;
in
{
  options.pi = {
    # Off by default so a consuming deployment opts in, matching
    # `claude.enable` and `opencode.enable`. Declared here and never assigned in
    # `home/default.nix`, so a consumer sets it plainly without needing
    # `mkForce` to override anything.
    enable = lib.mkEnableOption "pi";

    # No defaults for the next three, for the same reason `opencode.model` has
    # none: each names a provider or a credential, and a shared dotfiles repo
    # doesn't know which subscription a given machine pays for. Left null the
    # corresponding key is omitted from the generated JSON rather than
    # asserted, so enabling pi never obliges a consumer to configure a provider
    # it doesn't want.
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
        decrypt — the same split `opencode.web.environmentFile` already uses.

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
        Code and opencode use — so no harness owns the source. Override it to
        give Pi its own.
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
    ];

    home.file = {
      # Pi's global rules are AGENTS.md in the agent directory, which it loads
      # for every working directory. `pi.context` defaults to the shared
      # `agent-rules.md` (the same file Claude Code and opencode use), so a
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
    // lib.mapAttrs' (
      name: skill: lib.nameValuePair "${configDir}/skills/${name}" { source = skill; }
    ) allSkills
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
          packages = [
            "npm:pi-web-access@${lib.removePrefix "v" sources.pi-web-access.version}"
          ];
        }
        // lib.optionalAttrs (cfg.provider != null) { defaultProvider = cfg.provider; }
        // lib.optionalAttrs (cfg.model != null) { defaultModel = cfg.model; }
      );
    };
  };
}
