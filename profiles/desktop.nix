_:

let
  homeDirectory = builtins.getEnv "HOME";
  username = builtins.getEnv "USER";
in
{
  imports = [ ../home ];

  home-manager-configuration = {
    enable = true;
    profile = "desktop";
    inherit username homeDirectory;
  };

  nixpkgs.config.allowUnfree = true;

  # The desktop client, not the daemon: the app bundles and manages its own
  # daemon, so `paseo.enable` stays off here (the consuming deployment decides
  # where the daemon actually runs). Pulls in the Electron build — a
  # several-hundred-MB closure — so drop this line on profiles that do not open
  # the app.
  paseo.desktop.enable = true;
}
