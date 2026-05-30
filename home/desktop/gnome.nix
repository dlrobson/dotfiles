{
  lib,
  pkgs,
  config,
  ...
}:
with lib;
let
  cfg = config.gnome-configuration;

  isNixOS = builtins.pathExists "/etc/nixos";

  isGnomeRunning = builtins.match ".*GNOME.*" (builtins.getEnv "XDG_CURRENT_DESKTOP") != null;

  gnomeExtensions = with pkgs.gnomeExtensions; [
    alphabetical-app-grid
    quick-settings-audio-devices-hider
  ];
in
{
  imports = [ ];

  options.gnome-configuration = {
    enable = mkEnableOption "Whether to enable the GNOME configuration";
    homeDirectory = mkOption {
      type = types.str;
      description = "The home directory of the user.";
    };
  };

  config = mkMerge [
    (mkIf (cfg.enable && isGnomeRunning) {
      home.packages = gnomeExtensions;

      dconf = {
        enable = true;
        settings = {
          "org/gnome/shell" = {
            disable-user-extensions = false;
            enabled-extensions = map (extension: extension.extensionUuid) gnomeExtensions;
            disabed-extensions = [ ];
          };

          "org/gnome/settings-daemon/plugins/media-keys" = {
            custom-keybindings = [
              "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
            ];
          };
          "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
            binding = "<Primary><Alt>t";
            command = "ghostty";
            name = "open-terminal";
          };
        };
      };
    })

    # This displays home-manager applications on non-NixOS systems
    (mkIf (cfg.enable && !isNixOS) {
      targets.genericLinux.enable = true;
      xdg.mime.enable = true;
      xdg.systemDirs.data = [ "${cfg.homeDirectory}/.nix-profile/share/applications" ];
    })
  ];
}
