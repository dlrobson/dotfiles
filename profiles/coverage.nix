{ lib, ... }:

let
  homeDirectory = builtins.getEnv "HOME";
  username = builtins.getEnv "USER";
in
{
  # Not a deployment target — a test fixture. `minimal` and `desktop` leave
  # every per-deployment option at its off/empty default, so the code paths
  # behind them are never built by `run-tests` and break silently in the
  # consuming repo instead. This profile turns all of them on with
  # representative values so those paths are compiled here.
  #
  # Values are deliberately fake. Nothing is deployed from this file, and none
  # of these options resolve their values at build time — paths are
  # interpolated into config, not read.
  #
  # Adding a per-deployment option? Add it here too, or it is untested.
  imports = [ ../home ];

  home-manager-configuration = {
    enable = true;
    profile = "desktop";
    inherit username homeDirectory;
  };

  # Exercises pi.nix: the package, both JSON files, the shipped skill built by
  # `authoredSkills`, consumer-supplied `skills` and `context` entries, and the
  # `auth requires provider` assertion's passing branch.
  pi = {
    enable = true;
    provider = "opencode-go";
    model = "deepseek-v4.1-flash";
    auth = "!cat /run/agenix/opencode-go";
    context = ''
      # Coverage fixture
      Overrides the Claude Code default.
    '';
    skills.example = ./fixtures/example-skill;
  };

  # Exercises paseo.nix: the patched package, the user service, the
  # `0.0.0.0`-with-EnvironmentFile assertion's passing branch, the hostnames
  # and relay env, and the rendered settings JSON.
  paseo = {
    enable = true;
    listenAddress = "0.0.0.0";
    hostnames = [ "nixos-server.example.ts.net" ];
    environmentFile = "/run/agenix/paseo/env";
    settings.daemon.mcp.enabled = true;
  };

  # `desktop` already enables the trigger, but leaves the schedule empty, so
  # the timer builds with no OnCalendar entry.
  claude-window-trigger.schedule = [ "*-*-* 06:00:00" ];

  # Exercises the conditional `includes` block in git.nix. `private.nix` sets
  # these as plain definitions rather than `mkDefault`, so overriding them takes
  # `mkForce` — the same thing the consuming repo does for
  # `claude-window-trigger`.
  private = {
    available = lib.mkForce true;
    dir = lib.mkForce "/nonexistent/nixos-config-private";
  };

  nixpkgs.config.allowUnfree = true;
}
