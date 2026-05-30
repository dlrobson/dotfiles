{
  config,
  lib,
  pkgs,
  ...
}:

let
  baseIgnores = [
    ".direnv"
    ".claude/settings.local.json"
  ];
in
{
  imports = [
    ../../modules/common/private.nix
    ../../modules/common/unstable-pkgs.nix
  ];

  programs.difftastic = {
    enable = true;
    package = config.unstablePkgs.difftastic;
    git.enable = true;
  };

  programs.git = {
    enable = true;
    package = config.unstablePkgs.git;
    ignores = baseIgnores;

    settings = {
      core.editor = "vi";
      fetch.prune = true;
      init.defaultBranch = "main";
      pull.rebase = true;
      user = {
        email = "danr.236@gmail.com";
        name = "Daniel Robson";
      };
    };

    includes = lib.optionals config.private.available [
      {
        contents.core.hooksPath = "${config.private.dir}/.githooks";
      }
    ];
  };
}
