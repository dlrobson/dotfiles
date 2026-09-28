{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.pi;
  jsonFormat = pkgs.formats.json { };

  # Upstream default, kept as a path rather than a literal so `PI_CODING_AGENT_DIR`
  # only has to be exported if a consumer moves it. The module that will
  # eventually replace this file hardcodes the same string.
  configDir = "${config.home.homeDirectory}/.pi/agent";
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
      # `context` is Claude Code's global-rules string, read back out rather
      # than duplicated — the module writes it to ~/.config/opencode/AGENTS.md
      # the same way (see `opencode.nix`). Pi's equivalent file is AGENTS.md in
      # the agent directory, which it loads for every working directory.
      # Empty when Claude Code is disabled, and an empty context file is
      # indistinguishable from none, so skip it rather than link a blank one.
    }
    // lib.optionalAttrs (config.programs.claude-code.context != "") {
      "${configDir}/AGENTS.md".text = config.programs.claude-code.context;
    }
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
    // lib.optionalAttrs (cfg.provider != null || cfg.model != null) {
      "${configDir}/settings.json".source = jsonFormat.generate "pi-settings.json" (
        {
          # Flicker-free alt-screen renderer, matching `tui = "fullscreen"` in
          # `claude.nix`.
          tuiMode = "fullscreen";
        }
        // lib.optionalAttrs (cfg.provider != null) { defaultProvider = cfg.provider; }
        // lib.optionalAttrs (cfg.model != null) { defaultModel = cfg.model; }
      );
    };
  };
}
