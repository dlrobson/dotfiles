{
  config,
  lib,
  pkgs,
  ...
}:

{
  services.ssh-agent = {
    enable = true;
  };

  programs.ssh = {
    enable = true;
    extraConfig = ''
      Include ~/.ssh/config.local*
    '';
    matchBlocks."*" = {
      extraOptions = {
        AddKeysToAgent = "yes";
        SetEnv = "TERM=xterm-256color";
      };
    };
  };
}
