{
  lib,
  pkgs,
  config,
  ...
}:
with lib;
let
  cfg = config.home-manager-desktop-configuration;
  isNixOS = builtins.pathExists "/etc/nixos";
  isGnomeRunning = builtins.match ".*GNOME.*" (builtins.getEnv "XDG_CURRENT_DESKTOP") != null;
  gnomeExtensions = with pkgs.gnomeExtensions; [
    alphabetical-app-grid
    quick-settings-audio-devices-hider
  ];
in
{
  imports = [
    ../../modules/common/unstable-pkgs.nix
    ./nixgl-pkgs.nix
  ];

  options.home-manager-desktop-configuration = {
    enable = mkEnableOption "Enable home-manager desktop configuration";
    homeDirectory = mkOption {
      type = types.str;
      description = "The home directory of the user.";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      programs = {
        chromium = {
          enable = true;
          package =
            if isNixOS then config.unstablePkgs.brave else config.lib.nixGL.wrap config.unstablePkgs.brave;
          extensions = [
            { id = "nngceckbapebfimnlniiiahkandclblb"; } # Bitwarden
            { id = "neebplgakaahbhdphmkckjjcegoiijjo"; } # Keepa
            { id = "idpbkophnbfijcnlffdmmppgnncgappc"; } # Rakuten
            { id = "nffaoalbilbmmfgbnbgppjihopabppdk"; } # Video Speed Controller
          ];
        };

        ghostty = {
          enable = true;
          package =
            if isNixOS then config.unstablePkgs.ghostty else config.lib.nixGL.wrap config.unstablePkgs.ghostty;
          settings = {
            theme = "dark:Catppuccin Frappe,light:Catppuccin Latte";
            term = "xterm-ghostty";
          };
        };

        vscode = {
          enable = true;
          package = config.unstablePkgs.vscode;
          profiles.default.extensions =
            with config.unstablePkgs.vscode-extensions;
            [
              ms-vscode-remote.remote-ssh
              mkhl.direnv
              eamodio.gitlens
            ]
            ++ [
              (pkgs.vscode-utils.extensionFromVscodeMarketplace {
                name = "save-as-root";
                publisher = "yy0931";
                version = "1.11.0";
                sha256 = "sha256-NziiIY/qTFvJMwPoIIu2xLMPL9mn3gB3VSaItHIvfCI=";
              })
              (pkgs.vscode-utils.extensionFromVscodeMarketplace {
                name = "back-n-forth";
                publisher = "nick-rudenko";
                version = "3.1.1";
                sha256 = "sha256-yircrP2CjlTWd0thVYoOip/KPve24Ivr9f6HbJN0Haw=";
              })
            ];
        };
      };

      home = {
        file = {
          ".config/Code/User/prompts/spec-sidecar.instructions.md".source = ./spec-sidecar.instructions.md;
          ".config/wezterm/wezterm.lua".source = ./wezterm.lua;
        };

        # Trialing as a Ghostty alternative: better native SSH multiplexing
        # (built-in panes/tabs/SSH domains instead of relying on tmux, which
        # has its own OSC52/OSC9 passthrough bugs over SSH - see neovim.nix).
        packages = [
          (if isNixOS then config.unstablePkgs.wezterm else config.lib.nixGL.wrap config.unstablePkgs.wezterm)
        ];
      };
    }

    (mkIf isGnomeRunning {
      home.packages = gnomeExtensions;

      dconf = {
        enable = true;
        settings = {
          "org/gnome/shell" = {
            disable-user-extensions = false;
            enabled-extensions = map (ext: ext.extensionUuid) gnomeExtensions;
            disabed-extensions = [ ];
          };
          "org/gnome/settings-daemon/plugins/media-keys" = {
            terminal = lib.hm.gvariant.mkArray lib.hm.gvariant.type.string [ ];
            custom-keybindings = [
              "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
            ];
          };
          "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
            binding = "<Primary><Alt>t";
            command = "${cfg.homeDirectory}/.nix-profile/bin/ghostty";
            name = "open-terminal";
          };
        };
      };
    })

    (mkIf (!isNixOS) {
      targets.genericLinux.enable = true;
      xdg.mime.enable = true;
      xdg.systemDirs.data = [ "${cfg.homeDirectory}/.nix-profile/share/applications" ];

      home.packages = with pkgs; [ kmonad ];

      home.file.".config/thinkpad.kbd".source = ../../kmonad/thinkpad.kbd;

      systemd.user.services.kmonad-mapping = {
        Unit.Description = "Start KMonad with custom mapping";
        Service = {
          ExecStart = "${pkgs.kmonad}/bin/kmonad %h/.config/thinkpad.kbd";
          Restart = "on-failure";
        };
        Install.WantedBy = [ "default.target" ];
      };
    })
  ]);
}
