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
  ousterIgnores = baseIgnores ++ [
    "CLAUDE.md"
    ".envrc"
    "shell.nix"
    "docs/superpowers"
  ];
in
{
  imports = [
    ../../modules/common/private.nix
    ../../modules/common/unstable-pkgs.nix
  ];

  home.file.".config/git/ignore-ouster".text = lib.concatStringsSep "\n" ousterIgnores;

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

    includes = [
      {
        condition = "hasconfig:remote.*.url:git@gitlab.com:work/*/**";
        contents = {
          user.email = "REDACTED";
          core.excludesFile = "~/.config/git/ignore-ouster";
        };
      }
    ]
    ++ lib.optionals config.private.available [
      {
        contents.core.hooksPath = "${config.private.dir}/.githooks";
      }
    ];
  };
}
