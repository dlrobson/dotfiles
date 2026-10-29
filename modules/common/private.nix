{ lib, ... }:

{
  options.private = {
    available = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether nixos-config-private is present.";
    };
    dir = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Absolute path to nixos-config-private/. Always set; check available first.";
    };
  };

  config.private = {
    available = false;
    dir = "";
  };
}
