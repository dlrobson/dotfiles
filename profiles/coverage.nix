{ lib, pkgs, ... }:

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

  # Exercises pi.nix: the package, all three JSON files, the shipped skill built by
  # `authoredSkills`, the shipped agents built by `authoredAgents`,
  # consumer-supplied `agents`, `skills` and `context` entries, the always-on
  # reply prompt wiring, the window trigger as the `window-trigger` job (its
  # service and timer), the general `jobs` service and timer (inline and file
  # prompts, tool allowlists, output redirection, a working directory, the
  # MCP/skills/context-file opt-ins, every attachment form, `path`, both run
  # steps, a kept session, a `notify` job with its `pi-job` command, notice
  # and failure unit, and a disabled entry), and the passing branches of the
  # `auth requires provider`, `trigger requires model`, `trigger job defined
  # once`, `jobs require model` and job-name assertions.
  pi = {
    enable = true;
    provider = "opencode-go";
    model = "deepseek-v4.1-flash";
    auth = "!cat /run/agenix/opencode-go";
    windowTrigger = {
      enable = true;
      schedule = [ "*-*-* 06:00:00" ];
      model = "opencode-go/deepseek-v4.1-flash";
    };
    jobs = {
      news = {
        enable = true;
        schedule = [ "*-*-* 07:00:00" ];
        prompt = "Summarise the top five stories from the last day.";
        tools = [
          "web_search"
          "fetch_content"
        ];
        output = "${homeDirectory}/notes/news.md";
        # `sessionDir` left to its `notify` default.
        notify = true;
      };
      # No schedule: the service exists, the timer does not. Every opt-in and
      # the file-prompt branch are on, so both shapes are built.
      repository = {
        enable = true;
        prompt = ./fixtures/job-prompt.md;
        model = "opencode-go/deepseek-v4.1-flash";
        thinking = "low";
        tools = [
          "read"
          "bash"
          "edit"
          "write"
        ];
        mcp = true;
        skills = true;
        contextFiles = true;
        workingDirectory = "/tmp";
        extraArgs = [ "--no-approve" ];
        # One attachment of each form: a path literal, an absolute string and
        # a file written by `preRun`. No `output`, so `postRun` reads the
        # answer from the run directory.
        attachments = [
          ./fixtures/job-prompt.md
          "/etc/os-release"
          "status.txt"
        ];
        path = [
          pkgs.jq
          "${homeDirectory}/.nix-profile"
        ];
        # Writes `skip` when there is nothing to report, so the skip branch
        # is built too.
        preRun = ''
          git -C /tmp log -1 > status.txt
          test -s status.txt || echo "no commits" > skip
        '';
        postRun = ''
          wc -l "$PI_JOB_ANSWER"
        '';
        sessionDir = "${homeDirectory}/.local/state/pi-jobs/repository";
      };
      disabled = {
        enable = false;
        prompt = "Never runs.";
      };
    };
    context = ''
      # Coverage fixture
      Overrides the Claude Code default.
    '';
    skills.example = ./fixtures/example-skill;
    agents.example = ./fixtures/example-agent.md;
    # Consumer-supplied servers, merged over the shipped `nixos` one: one of
    # each shape Pi accepts (stdio, HTTP with a credential command, a bare
    # OAuth URL), plus a partial override of the shipped server so the
    # recursive merge is built, not just the defaults.
    mcpServers = {
      nixos.exposure = "deferred";
      filesystem = {
        command = "npx";
        args = [
          "-y"
          "@modelcontextprotocol/server-filesystem"
          "."
        ];
      };
      docs = {
        url = "https://example.com/mcp";
        headers.Authorization = "!echo Bearer $(cat /run/agenix/docs-token)";
      };
      oauth-example.url = "https://mcp.example.com/mcp";
    };
  };

  # Exercises paseo.nix: the patched package, the user service, the
  # `0.0.0.0`-with-EnvironmentFile assertion's passing branch, the hostnames,
  # relay and web UI env, the git-identity wrapper, the SSH agent passthrough
  # and its `services.ssh-agent` assertion, the rendered settings JSON, and the
  # desktop (Electron) build. The desktop build is by far the expensive part of
  # `run-tests` — and the point: nothing else catches upstream renaming
  # `nix/desktop-package.nix` or adding a required argument to it.
  paseo = {
    enable = true;
    listenAddress = "0.0.0.0";
    hostnames = [ "nixos-server.example.ts.net" ];
    webUi.enable = true;
    environmentFile = "/run/agenix/paseo/env";
    gitIdentityFile = "/run/agenix/server/paseo-repo-key";
    forwardSshAgent = true;
    settings.daemon.mcp.enabled = true;
    desktop.enable = true;
  };

  # Exercises the conditional `includes` block in git.nix. `private.nix` sets
  # these as plain definitions rather than `mkDefault`, so overriding them takes
  # `mkForce`.
  private = {
    available = lib.mkForce true;
    dir = lib.mkForce "/nonexistent/nixos-config-private";
  };

  nixpkgs.config.allowUnfree = true;
}
