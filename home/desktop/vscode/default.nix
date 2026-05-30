{ config, pkgs, ... }:

{
  imports = [ ../../../modules/common/unstable-pkgs.nix ];

  programs.vscode = {
    package = config.unstablePkgs.vscode;

    profiles.default.extensions =
      with config.unstablePkgs.vscode-extensions;
      [
        ms-vscode-remote.remote-ssh
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

  home.file = {
    ".config/Code/User/prompts/spec-sidecar.instructions.md".source = ./spec-sidecar.instructions.md;
  };
}
