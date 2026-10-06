{
  config,
  lib,
  pkgs,
  ...
}:
let
  sources = import ../../npins;
  cfg = config.paseo;

  # The patched build, shared by every consumer — the NixOS server enables
  # this module rather than carrying its own copy — for two reasons:
  #
  # 1. The node-pty native addon is missing from the traced output, so the
  #    daemon dies at startup with "Failed to load native module: pty.node".
  #    nft can't trace it (it's loaded via a runtime-computed path) and
  #    upstream's scripts/trace-daemon.mjs pins it to the *root*
  #    `node_modules/node-pty/prebuilds/<plat>/pty.node`, but npm nests
  #    node-pty under packages/server/node_modules in this workspace, so the
  #    glob matches nothing. Copy the nested package in ourselves — postInstall
  #    runs before fixupPhase, so autoPatchelfHook still patches the addon.
  # 2. fetchNpmDeps' output hash depends on the nixpkgs revision. The default
  #    in upstream's nix/npm-deps.hash is computed against the nixpkgs their CI
  #    uses, so ours differs. A nixpkgs-unstable bump that changes it fails the
  #    build loudly with a "got:" hash — paste that here.
  paseo =
    (config.unstablePkgs.callPackage "${sources.paseo}/nix/package.nix" {
      npmDepsHash = "sha256-uG7EkoQMVLk5CzDEbJbR5aPxeq59x4vjF21JGatxD7k=";
    }).overrideAttrs
      (old: {
        postInstall = (old.postInstall or "") + ''
          while IFS= read -r src; do
            rel="''${src#./}"
            dest="$out/lib/paseo/$(dirname "$rel")/node-pty"
            mkdir -p "$dest"
            cp -a "$src/." "$dest/"
          done < <(find . -type d -path "*/node_modules/node-pty")
        '';
      });

  jsonFormat = pkgs.formats.json { };

  settingsFile = jsonFormat.generate "paseo-config.json" cfg.settings;

  # `%h`/`%u` are systemd specifiers resolved by the user manager. A user unit
  # does not inherit a login PATH, and the agents the daemon spawns need the
  # user's CLIs, so set it explicitly.
  servicePath = lib.concatStringsSep ":" [
    "%h/.nix-profile/bin"
    "%h/.local/state/nix/profile/bin"
    "/etc/profiles/per-user/%u/bin"
    "/run/current-system/sw/bin"
    "/run/wrappers/bin"
    "/nix/var/nix/profiles/default/bin"
  ];

  environment = {
    PASEO_HOME = cfg.dataDir;
    PASEO_LISTEN = "${cfg.listenAddress}:${toString cfg.port}";
    PATH = servicePath;
  }
  // lib.optionalAttrs (cfg.hostnames != [ ]) {
    PASEO_HOSTNAMES = lib.concatStringsSep "," cfg.hostnames;
  }
  // cfg.environment;
in
{
  options.paseo = {
    # Off by default so a consuming deployment opts in, matching `opencode`.
    # This repo's profiles build standalone, so a consumer that enables it is
    # the only place it really runs; `profiles/coverage.nix` exercises it.
    enable = lib.mkEnableOption "the Paseo daemon";

    package = lib.mkOption {
      type = lib.types.package;
      default = paseo;
      defaultText = lib.literalExpression "patched paseo built from the npins pin";
      description = "Paseo package to run.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 6767;
      description = "Port the daemon listens on.";
    };

    # Paseo is a user service here, not the upstream system service, so its
    # firewall rule is not ours to make. `0.0.0.0` keeps loopback working for
    # the CLI and Paseo's SSH transport and avoids waiting on tailscale0 coming
    # up, but then the tailnet-scoped rule in the consuming NixOS config is the
    # only thing keeping the port off the LAN. The assertion below is the
    # in-repo half of that guard.
    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      example = "0.0.0.0";
      description = ''
        Address for the daemon to bind to. Defaults to loopback; `0.0.0.0` is
        common for tailnet-only deployments, where the firewall does the
        scoping.
      '';
    };

    hostnames = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "nixos-server.tailnet.example" ];
      description = ''
        Hostnames the daemon accepts in the Host header (DNS-rebinding
        protection). Localhost and IP addresses are always accepted; this only
        adds names, for clients reaching it by MagicDNS rather than by IP.
      '';
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.paseo";
      description = "Directory for daemon state (PASEO_HOME).";
    };

    # The daemon hashes PASEO_PASSWORD in memory at startup and never persists
    # it. An EnvironmentFile keeps the plaintext out of the world-readable
    # store, so this is a path the consuming deployment provides — this repo
    # owns no secrets of its own.
    #
    # Deliberately `str` and not `path`: a path *literal* here (`./paseo.env`)
    # would be copied into the world-readable Nix store, leaking the password.
    # Consumers without agenix (e.g. the Ubuntu desktop) must pass an absolute
    # path string to a file they manage themselves.
    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/agenix/paseo/env";
      description = ''
        Absolute path to a systemd EnvironmentFile supplying `PASEO_PASSWORD`.
        Must be a string, not a path literal — see the comment above.
      '';
    };

    relay.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to register with the hosted app.paseo.sh relay. Off by
        default: tailnet-only.
      '';
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Extra environment variables for the daemon.";
    };

    settings = lib.mkOption {
      inherit (jsonFormat) type;
      default = { };
      description = ''
        Rendered to JSON and installed as `$PASEO_HOME/config.json` on every
        start, mirroring upstream's module. Runtime mutations (CLI, mobile app)
        are overwritten on restart — pick one, not both.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Refusing to build beats printing a warning nobody reads: an
    # unauthenticated daemon on loopback is a reasonable local convenience, but
    # the moment it is reachable from elsewhere the password stops being
    # optional. Mirrors the opencode web assertion.
    assertions = [
      {
        assertion = cfg.listenAddress == "127.0.0.1" || cfg.environmentFile != null;
        message = ''
          paseo.listenAddress is "${cfg.listenAddress}" but no environmentFile
          is set, so the daemon would accept unauthenticated requests from the
          network — and it can run shell commands as you. Set
          `paseo.environmentFile` to a file defining PASEO_PASSWORD, and make
          sure the port is reachable only where you intend (a tailnet-scoped
          firewall rule on NixOS, `tailscale serve` elsewhere).
        '';
      }
    ];

    home.packages = [ cfg.package ];

    systemd.user.services.paseo = {
      Unit = {
        Description = "Paseo - self-hosted daemon for AI coding agents";
        After = [ "network.target" ];
      };

      Service = {
        Type = "simple";
        ExecStart =
          "${cfg.package}/bin/paseo-server" + lib.optionalString (!cfg.relay.enable) " --no-relay";
        Environment = lib.mapAttrsToList (k: v: "${k}=${v}") environment;
        EnvironmentFile = lib.optional (cfg.environmentFile != null) cfg.environmentFile;

        # home-manager has no `systemd.user.tmpfiles`, so create the state dir
        # here; install the rendered config too, as upstream's module does.
        ExecStartPre = pkgs.writeShellScript "paseo-prepare" ''
          mkdir -p ${lib.escapeShellArg cfg.dataDir}
          ${lib.optionalString (cfg.settings != { }) ''
            install -m 0600 ${settingsFile} ${lib.escapeShellArg cfg.dataDir}/config.json
          ''}
        '';

        Restart = "on-failure";
        RestartSec = 5;
        KillSignal = "SIGTERM";
        TimeoutStopSec = 15;
      };

      Install.WantedBy = [ "default.target" ];
    };
  };
}
