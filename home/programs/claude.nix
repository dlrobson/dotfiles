{
  config,
  lib,
  ...
}:
let
  cfg = config.claude;
in
{
  options = {
    claude = {
      # Off by default so a consuming deployment opts in, matching `pi.enable`.
      enable = lib.mkEnableOption "Claude Code";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.claude-code = {
      enable = true;
      package = config.unstablePkgs.claude-code;
      # The global rules live in a harness-neutral file, shared verbatim with
      # Pi. Keeping them here rather than inline means they are not gated
      # behind this `mkIf cfg.enable` — disabled Claude Code would otherwise
      # blank the context Pi reads.
      context = ./agent-rules.md;
      # The same `mcp-nixos` server Pi ships, from nixpkgs rather than `uvx`, so
      # it needs no `uv`, Python or network at runtime. Home Manager serves
      # these servers from a generated `claude-code-home-manager` plugin, which
      # is why its tools are named `mcp__plugin_claude-code-home-manager_*`.
      mcpServers.nixos.command = lib.getExe config.unstablePkgs.mcp-nixos;
      # The testing rules are one skill both harnesses read. Pi builds the same
      # directory from `./pi/skills/` (it needs the build step to carry
      # `pi-docs/`); here the source directory is linked as-is.
      skills.test-design = ./pi/skills/test-design;
      settings = {
        # Flicker-free alt-screen renderer with virtualized scrollback
        # (equivalent to CLAUDE_CODE_NO_FLICKER=1; toggle live via /tui).
        tui = "fullscreen";
        cleanupPeriodDays = 60;
        autoMemoryEnabled = false;
        skipAutoPermissionPrompt = true;
        # Default 1% budget truncates a handful of skill descriptions (full
        # listing is ~1.7% of context); actual cost is negligible either way
        # (~3.3k tokens total), so raise the cap to stop the startup warning.
        skillListingBudgetFraction = 0.02;
        # Pre-approved actions recurring across repos. Without the sandbox,
        # every Bash command prompts unless it matches an entry here — the
        # routine read-only ones (git fetch/pull) are allowed; anything that
        # mutates shared state (push, reset) still asks.
        permissions = {
          deny = [
            # Hard block, backstopping the "never run sudo" rule in `context`
            # above (a prose instruction the model could ignore or have
            # overridden mid-conversation) with harness-level enforcement.
            "Bash(sudo *)"
          ];
          ask = [
            "Bash(git push *)"
            "Bash(git reset *)"
          ];
          allow = [
            "Bash(git fetch *)"
            "Bash(git pull *)"
            "mcp__plugin_claude-code-home-manager_nixos__nix"
            "WebFetch(domain:tailscale.com)"
            "WebFetch(domain:mynixos.com)"
            "WebFetch(domain:codeload.github.com)"
            "WebFetch(domain:raw.githubusercontent.com)"
            "WebSearch"
            "Skill(code-review)"
            "Skill(simplify)"
            "Skill(verify)"
          ];
        };
        attribution = {
          commit = "";
          pr = "";
          sessionUrl = false;
        };
        # Loads the project's direnv environment into every Bash command,
        # re-exported on a directory change so it follows `cd`.
        hooks =
          let
            direnvExport = [
              {
                hooks = [
                  {
                    type = "command";
                    command = ''${lib.getExe config.programs.direnv.package} export bash > "$CLAUDE_ENV_FILE"'';
                  }
                ];
              }
            ];
          in
          {
            SessionStart = direnvExport;
            CwdChanged = direnvExport;
          };
      };
    };

    home = {
      # These two are fully derived from settings above, so always
      # overwrite rather than backing up (avoids "would be clobbered"
      # failures when a stale real file/.backup already exists — this bit
      # settings.json specifically: a pre-existing real file at that path,
      # e.g. one Claude Code itself wrote before this repo managed it, made
      # every activation silently skip re-linking it ("Existing file
      # '.../.claude/settings.json' would be clobbered" in the
      # home-manager-admin.service journal) instead of failing loudly, so
      # config changes there never actually took effect).
      file = {
        "${config.home.homeDirectory}/.claude/CLAUDE.md".force = true;
        "${config.home.homeDirectory}/.claude/settings.json".force = true;
      };

      sessionPath = [
        "${config.home.homeDirectory}/.npm-global/bin"
        "${config.home.homeDirectory}/.local/bin"
      ];
    };
  };
}
