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
    variables = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Contents of nixos-config-private/variables.nix, or {} if unavailable.";
    };
    secretsDir = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Absolute path to nixos-config-private/. Aborts if unavailable.";
    };
  };

  config.private = {
    available = false;
    dir = "";
    variables = { };
    secretsDir = "";
  };
}
