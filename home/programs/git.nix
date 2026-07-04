{
  config,
  lib,
  ...
}:

let
  ignores = import ./git-base-ignores.nix;
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
    inherit ignores;

    settings = {
      core.editor = "vi";
      # `git diff` uses difftastic (via programs.difftastic.git.enable above);
      # `git difftool` uses Neovim's built-in diff mode instead.
      diff.tool = "nvimdiff";
      difftool.prompt = false;
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
