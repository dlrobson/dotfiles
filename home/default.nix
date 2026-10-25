{
  lib,
  config,
  ...
}:
with lib;
let
  cfg = config.home-manager-configuration;
  constants = import ../modules/common/constants.nix { inherit lib; };
in
{
  imports = [
    ./programs
    ./desktop
    ../modules/common/unstable-pkgs.nix
  ];

  options.home-manager-configuration = {
    enable = mkEnableOption "enable home-manager configuration";

    profile = mkOption {
      type = types.enum constants.profiles.options;
      description = ''
        Configuration profile to use:
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (name: desc: "- ${name}: ${desc}") constants.profiles.descriptions
        )}
      '';
      inherit (constants.profiles) default;
    };

    username = mkOption {
      type = types.str;
      description = ''
        The username of the user to manage.
        This is usually the same as the current user.
      '';
    };
    homeDirectory = mkOption {
      type = types.str;
      description = ''
        The home directory of the user to manage.
        This is usually the same as the current user's home directory.
      '';
    };
  };

  config = mkIf cfg.enable {
    home = {
      inherit (cfg) username homeDirectory;
      stateVersion = "25.11";
    };

    home-manager-desktop-configuration.enable = cfg.profile == "desktop";
    home-manager-desktop-configuration.homeDirectory = cfg.homeDirectory;
    # `desktop` means "install the GUI applications", so it merely seeds these.
    # `mkDefault` keeps a consumer free to disagree without `mkForce`: a host
    # can want the GUI apps but not an agent harness, or Claude Code on a
    # `minimal` account. See `claude.nix` for what `claude.enable` gates — the
    # package, settings and fish abbreviations are all behind it.
    claude.enable = mkDefault (cfg.profile == "desktop");
    claude-window-trigger.enable = mkDefault (cfg.profile == "desktop");
  };
}
