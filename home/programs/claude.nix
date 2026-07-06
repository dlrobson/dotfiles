{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.claude-window-trigger;
  sources = import ../../npins;
  pluginMarketplace = sources.plugin-marketplace;
  claudePluginsOfficial = sources.claude-plugins-official;
  # Enable every plugin listed in the marketplace's manifest automatically,
  # so new plugins added to the repo don't need to be listed here by hand.
  localMarketplaceManifest = builtins.fromJSON (
    builtins.readFile "${pluginMarketplace}/.claude-plugin/marketplace.json"
  );
  localEnabledPlugins = lib.listToAttrs (
    map (
      plugin: lib.nameValuePair "${plugin.name}@dlrobson-plugins" true
    ) localMarketplaceManifest.plugins
  );
in
{
  options.claude-window-trigger = {
    enable = lib.mkEnableOption "Claude Code usage window triggers";
    schedule = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "OnCalendar entries for the window trigger timer.";
    };
  };

  config = {
    programs.claude-code = {
      enable = true;
      package = config.unstablePkgs.claude-code;
      context = ''
        # Global Claude Code Rules

        ## Git workflow
        When pushing a new branch upstream for the first time, return the PR creation URL (from `gh pr create`).
      '';
      settings = {
        # Flicker-free alt-screen renderer with virtualized scrollback
        # (equivalent to CLAUDE_CODE_NO_FLICKER=1; toggle live via /tui).
        tui = "fullscreen";
        # Retain sessions/tasks/backups for 60 days (default is shorter), so
        # older sessions remain scrollable and backups recoverable.
        # Note: the nixpkgs claude-code wrapper already sets DISABLE_AUTOUPDATER=1,
        # so no env entry is needed to stop the bundled updater.
        cleanupPeriodDays = 60;
        autoMemoryEnabled = true;
        autoDreamEnabled = true;
        remoteControlAtStartup = true;
        agentPushNotifEnabled = true;
        skipAutoPermissionPrompt = true;
        # Default 1% budget truncates a handful of skill descriptions (full
        # listing is ~1.7% of context); actual cost is negligible either way
        # (~3.3k tokens total), so raise the cap to stop the startup warning.
        skillListingBudgetFraction = 0.02;
        # Always run Bash commands inside the bubblewrap sandbox (filesystem
        # writes confined to cwd/scratch, network confined to an allowlist).
        # autoAllowBashIfSandboxed skips the per-command permission prompt
        # since the sandbox itself is the safety boundary. allowUnsandboxedCommands
        # is true so a sandbox-caused failure (e.g. writing outside cwd/scratch,
        # a non-allowlisted host, or the ~/.ssh/config ownership issue under
        # bwrap's uid remap) lets Claude retry with dangerouslyDisableSandbox
        # instead of dead-ending — that retry still goes through the normal
        # permission prompt, since autoAllowBashIfSandboxed only covers
        # commands that stay inside the sandbox.
        sandbox = {
          enabled = true;
          autoAllowBashIfSandboxed = true;
          allowUnsandboxedCommands = true;
          # git commands that shell out to ssh always hit the ~/.ssh/config
          # ownership issue above (bwrap's user namespace only maps our own
          # uid; the Nix-store-owned config file resolves to nobody:nogroup
          # inside the sandbox, and OpenSSH refuses to use it). Excluding
          # these skips the sandboxed attempt + retry roundtrip entirely.
          # nix-shell is excluded too: it needs real write access to
          # ~/.cache/nix for npins' fetchTarball cache (sandboxed, this
          # failed with "unable to open database file"), so it's simpler to
          # run it unsandboxed outright rather than carve out a filesystem
          # exception.
          excludedCommands = [
            "git push"
            "git pull"
            "git fetch"
            "git clone"
            "ssh"
            "nix-shell"
          ];
          network = {
            allowedDomains = [
              "github.com"
              "api.github.com"
              "objects.githubusercontent.com"
              "registry.npmjs.org"
              "api.anthropic.com"
            ];
          };
        };
        # Pre-approved actions recurring across repos (surfaced by scanning
        # each repo's .claude/settings.local.json). Most Bash commands are
        # deliberately NOT listed here (e.g. git add/commit): with
        # sandbox.enabled + autoAllowBashIfSandboxed both true above, every
        # sandboxed Bash command already auto-runs without a prompt
        # regardless of this list, so an allow entry for them would be
        # functionally inert. The nix-shell targets below are the exception:
        # nix-shell is in sandbox.excludedCommands (runs unsandboxed), so it
        # needs an explicit allow entry to skip the prompt too. Scoped to
        # these known-safe targets rather than a `Bash(nix-shell *)`
        # wildcard, since nix-shell runs unsandboxed now — a blanket rule
        # would let arbitrary `nix-shell -p ... --run ...` invocations
        # execute unprompted as well as unsandboxed.
        permissions = {
          allow = [
            "Bash(nix-shell --run \"check\")"
            "Bash(nix-shell --run \"build\")"
            "Bash(nix-shell --run \"run-tests\")"
            "Bash(nix-shell --run \"fix\")"
            "Bash(nix-shell --run \"format\")"
            # Recurring in 2+ repos' local settings (audit-claude-settings);
            # the nix plugin is enabled globally but the MCP tool itself was
            # never allowlisted.
            "mcp__plugin_nix_mcp-nixos__nix"
            "WebFetch(domain:tailscale.com)"
            "WebFetch(domain:mynixos.com)"
            "WebFetch(domain:codeload.github.com)"
            "WebSearch"
            "Skill(superpowers:brainstorming)"
            "Skill(superpowers:writing-plans)"
            "Skill(superpowers:subagent-driven-development)"
            "Skill(superpowers:systematic-debugging)"
            "Skill(superpowers:test-driven-development)"
            "Skill(superpowers:verification-before-completion)"
            "Skill(superpowers:requesting-code-review)"
            "Skill(superpowers:receiving-code-review)"
            "Skill(superpowers:using-git-worktrees)"
            "Skill(code-review)"
            "Skill(simplify)"
            "Skill(verify)"
            "Skill(pr-review-toolkit:review-pr)"
            "Agent(pr-review-toolkit:code-reviewer)"
            "Agent(pr-review-toolkit:code-simplifier)"
            "Agent(pr-review-toolkit:comment-analyzer)"
            "Agent(pr-review-toolkit:pr-test-analyzer)"
            "Agent(pr-review-toolkit:silent-failure-hunter)"
            "Agent(pr-review-toolkit:type-design-analyzer)"
          ];
        };
        attribution = {
          commit = "";
          pr = "";
          sessionUrl = false;
        };
        # Plugins resolved from the marketplaces registered below, keyed as
        # `plugin-id@marketplace-id`.
        enabledPlugins = {
          "claude-md-management@claude-plugins-official" = true;
          "claude-code-setup@claude-plugins-official" = true;
          "superpowers@claude-plugins-official" = true;
          "pr-review-toolkit@claude-plugins-official" = true;
          "rust-analyzer@claude-code-lsps" = true;
          "nixd@claude-code-lsps" = true;
          "vtsls@claude-code-lsps" = true;
          "ast-grep@ast-grep-marketplace" = true;
        }
        // localEnabledPlugins;
      };
      marketplaces = {
        claude-plugins-official = claudePluginsOfficial;
        inherit (sources) claude-code-lsps;
        ast-grep-marketplace = sources.ast-grep-skill;
        dlrobson-plugins = pluginMarketplace;
      };
    };

    home = {
      # These three are all fully derived from settings above, so always
      # overwrite rather than backing up (avoids "would be clobbered"
      # failures when a stale real file/.backup already exists — this bit
      # settings.json specifically: a pre-existing real file at that path,
      # e.g. one Claude Code itself wrote before this repo managed it, made
      # every activation silently skip re-linking it ("Existing file
      # '.../.claude/settings.json' would be clobbered" in the
      # home-manager-admin.service journal) instead of failing loudly, so
      # config changes there never actually took effect).
      file = {
        "${config.programs.claude-code.configDir}/plugins/known_marketplaces.json".force = true;
        "${config.home.homeDirectory}/.claude/CLAUDE.md".force = true;
        "${config.home.homeDirectory}/.claude/settings.json".force = true;
      };

      # Runtime deps for the `nix` plugin's mcp-nixos server, which launches
      # via `UV_PYTHON=$(which python3) uvx mcp-nixos`
      # (see plugin-marketplace/plugins/nix/.mcp.json). uvx runs the server;
      # python3 is the interpreter uv builds its environment against.
      packages = [
        pkgs.uv
        pkgs.python3
        # Binary for the ast-grep-skill plugin (pinned above). Unstable to
        # stay aligned with the skill, which tracks the upstream repo's main.
        config.unstablePkgs.ast-grep
      ];

      sessionPath = [
        "${config.home.homeDirectory}/.npm-global/bin"
        "${config.home.homeDirectory}/.local/bin"
      ];
    };

    systemd.user = {
      services.claude-window-trigger = lib.mkIf cfg.enable {
        Unit.Description = "Trigger Claude Code usage window";
        Service = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "claude-window-trigger" ''
            export PATH="${config.unstablePkgs.claude-code}/bin:$PATH"
            claude -p "hi" --output-format text --system-prompt "" --model claude-haiku-4-5-20251001
          '';
        };
      };

      timers.claude-window-trigger = lib.mkIf cfg.enable {
        Unit.Description = "Claude Code usage window trigger timer";
        Timer = {
          OnCalendar = cfg.schedule;
          Persistent = true;
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
  };
}
