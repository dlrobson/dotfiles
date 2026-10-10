_:

{
  # This is the OpenSSH agent: the right one for shells, and the only kind an
  # unattended process should ever rely on. On a NixOS host that also runs
  # GNOME a second agent appears for free — services.gnome.gcr-ssh-agent,
  # whose `enable` defaults to services.gnome.gnome-keyring.enable and which
  # the GNOME desktop module turns on as well.
  #
  # The two coexist, but they serve different lifetimes. gcr-ssh-agent's socket
  # unit runs `systemctl --user set-environment SSH_AUTH_SOCK=%t/gcr/ssh`, so
  # everything started by the *systemd user manager* (daemons, extension hosts,
  # non-login shells) inherits the GNOME agent, while login shells get this one
  # via sshAuthSock.initialization, which home-manager injects into each
  # shell's profile. On a desktop that is harmless: the login keyring is
  # unlocked at graphical login and gcr signs silently. On a host with no
  # graphical session it is not — gcr holds the key but cannot reach its
  # passphrase, so every request becomes a GTK prompt through
  # org.gnome.keyring.SystemPrompter, which exits with "cannot open display"
  # and fails whatever needed the key.
  #
  # For such a host: give the unattended job its own passphrase-free key so it
  # needs no agent at all, and disable the GNOME agent with
  # `services.gnome.gcr-ssh-agent.enable = false;`. Both are worked through in
  # the monolith repo — see docs/invariants/auth-secrets.md there.
  services.ssh-agent = {
    enable = true;
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    extraConfig = ''
      Include ~/.ssh/config.local*
    '';
    settings."*" = {
      AddKeysToAgent = "yes";
      SetEnv = {
        TERM = "xterm-256color";
      };
    };
  };
}
