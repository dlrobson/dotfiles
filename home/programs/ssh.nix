{
  config,
  lib,
  pkgs,
  ...
}:

{
  services.ssh-agent = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.ssh = {
    enable = true;
    extraConfig = ''
      Include ~/.ssh/config.local*
    '';
    enableDefaultConfig = false;
    matchBlocks."*" = {
      addKeysToAgent = "yes";
      extraOptions.SetEnv = "TERM=xterm-256color";
    };
  };
}
