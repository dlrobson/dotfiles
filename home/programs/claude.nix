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
        Whenever pushing to a remote branch, surface the URL the remote prints in the `git push`
        output (e.g. GitHub's "Create a pull request" hint line), not just on the first push.

        ## Safety
        Never run `sudo`. Ask the user to run the privileged command themselves.
      '';
      settings = {
        # Flicker-free alt-screen renderer with virtualized scrollback
        # (equivalent to CLAUDE_CODE_NO_FLICKER=1; toggle live via /tui).
        tui = "fullscreen";
        cleanupPeriodDays = 60;
        autoMemoryEnabled = false;
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
          # These all evaluate npins-pinned sources (nixpkgs/home-manager)
          # via fetchTarball, and even a cache-hit store query goes through
          # the daemon on a multi-user install — nix-shell via shell.nix,
          # nix-build/nix-instantiate via setup.sh. The sandbox blocks the
          # daemon socket outright (no allowUnixSockets entry — opening it
          # would let fixed-output derivations bypass network.allowedDomains
          # entirely), so a sandboxed attempt always fails first with a
          # confusing, not-obviously-sandbox-related error before falling
          # back to unsandboxed; excluding them skips the doomed attempt.
          #
          # git fetch/pull/push all use the SSH remote (origin is
          # git@github.com:...), which is doubly broken under bwrap: (1)
          # ~/.ssh/config is a home-manager symlink into /nix/store, owned by
          # root on the host — bwrap's user namespace only maps our own uid,
          # so root-owned files appear as nobody:nogroup inside the sandbox,
          # which fails OpenSSH's "owned by self or root" strict-permissions
          # check; (2) even bypassing that, the sandboxed network namespace
          # has no path for a non-proxy-aware raw TCP/DNS client like ssh
          # (confirmed: "Could not resolve hostname" inside the sandbox).
          # Fixing that would mean an SSH ProxyCommand through the sandbox's
          # SOCKS proxy, which is fragile and still wouldn't fix (1).
          excludedCommands = [
            "nix-shell *"
            "nix-build *"
            "nix-instantiate *"
            "git fetch *"
            "git pull *"
            "git push *"
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
          # Sandboxed commands otherwise have unrestricted filesystem read
          # access, so explicitly deny the credential stores that matter most:
          # SSH private keys (including the agenix decrypt key) and the gh
          # CLI's stored OAuth token.
          credentials = {
            files =
              map
                (path: {
                  inherit path;
                  mode = "deny";
                })
                [
                  "~/.ssh/"
                  "~/.config/gh/hosts.yml"
                ];
          };
        };
        # Pre-approved actions recurring across repos. Most Bash commands need
        # no entry: with sandbox.enabled + autoAllowBashIfSandboxed, every
        # sandboxed command already auto-runs (dev-shell commands like
        # check/run-tests included — direnv puts them on PATH). Only the
        # unsandboxed commands in sandbox.excludedCommands need an allow entry
        # to skip the prompt — hence git fetch/pull below.
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
            "mcp__plugin_nix_mcp-nixos__nix"
            "WebFetch(domain:tailscale.com)"
            "WebFetch(domain:mynixos.com)"
            "WebFetch(domain:codeload.github.com)"
            "WebFetch(domain:raw.githubusercontent.com)"
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
        # Desktop/tmux/Ghostty notifications when Claude finishes or needs
        # attention. Native here (not a marketplace plugin) because it's
        # specific to this machine: the dbus bus path, this tmux config's
        # @claude_done indicator, and Ghostty's OSC 777 escape sequence.
        hooks = {
          Stop = [
            {
              matcher = "";
              hooks = [
                {
                  type = "command";
                  command = ''
                    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus" notify-send 'Claude Code' 'Claude finished' 2>/dev/null || true; [ -n "$TMUX_PANE" ] && tmux set-window-option -t "$TMUX_PANE" @claude_done " !"; seq=$(printf '\033]777;notify;Claude Code;Claude finished\007'); jq -nc --arg seq "$seq" '{terminalSequence: $seq}'
                  '';
                }
              ];
            }
          ];
          Notification = [
            {
              matcher = "";
              hooks = [
                {
                  type = "command";
                  command = ''
                    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus" notify-send 'Claude Code' 'Claude needs your attention' 2>/dev/null || true; [ -n "$TMUX_PANE" ] && tmux set-window-option -t "$TMUX_PANE" @claude_done " !"; seq=$(printf '\033]777;notify;Claude Code;Claude needs your attention\007'); jq -nc --arg seq "$seq" '{terminalSequence: $seq}'
                  '';
                }
              ];
            }
          ];
        };
        # Plugins resolved from the marketplaces registered below, keyed as
        # `plugin-id@marketplace-id`.
        enabledPlugins = {
          "claude-md-management@anthropic-plugins" = true;
          "claude-code-setup@anthropic-plugins" = true;
          "superpowers@anthropic-plugins" = true;
          "plugin-dev@anthropic-plugins" = true;
          "pr-review-toolkit@anthropic-plugins" = true;
          "rust-analyzer@claude-code-lsps" = true;
          "nixd@claude-code-lsps" = true;
          "vtsls@claude-code-lsps" = true;
          "ast-grep@ast-grep-marketplace" = true;
          "engram@engram" = true;
        }
        // localEnabledPlugins;
      };
      marketplaces = {
        # Named away from the upstream "claude-plugins-official" id: Claude
        # Code's reserved-name check for that name fires even when the
        # source genuinely is anthropics/claude-plugins-official (it's a
        # nix-store directory source, not a recognized GitHub-org source),
        # so keeping the reserved name here just breaks marketplace loading.
        # https://github.com/anthropics/claude-code/issues/18329
        anthropic-plugins = claudePluginsOfficial;
        inherit (sources) claude-code-lsps;
        ast-grep-marketplace = sources.ast-grep-skill;
        dlrobson-plugins = pluginMarketplace;
        inherit (sources) engram;
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
