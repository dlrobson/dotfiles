# dlrobson's dotfiles

A collection of dotfiles managed using [Home Manager](https://github.com/nix-community/home-manager) and [Nix](https://nixos.org/).

## Installation

### Supported Systems

| System Type | Support |
|-------------|---------|
| Debian/Ubuntu | ✅ |
| NixOS | ✅ |

### Prerequisites

The installation script will automatically install required dependencies, but you'll need:
- A Unix-like system from the supported list above
- sudo access (you will be prompted during installation if needed)

### Setup

1. Clone this repository:
```bash
git clone https://github.com/dlrobson/dotfiles.git
cd dotfiles
```

2. Run the installation script:
```bash
./setup.sh
```

This script will:
- Install required packages
- Install and configure Nix
- Install Home Manager
- Deploy the configuration

### Post-Installation

After installation, you'll need to set Fish as your default shell:
```bash
chsh -s $(which fish)
```

Log out and log back in for the changes to take effect.

## KMonad Setup (Ubuntu/Debian Only)

KMonad keyboard remapping is only supported on Ubuntu/Debian systems. NixOS users should use the built-in keyboard configuration options instead.

If you want to use KMonad on Ubuntu/Debian:

1. Make sure Home Manager has installed the configuration
2. Run the KMonad setup script:
```bash
./kmonad/kmonad-setup.sh
```

This will:
- Set up required udev rules
- Add your user to necessary groups
- Enable and start the KMonad service

### KMonad Service Management

- Check status: `systemctl --user status kmonad-mapping.service`
- Stop service: `systemctl --user stop kmonad-mapping.service`
- Disable service: `systemctl --user disable kmonad-mapping.service`
- Enable service: `systemctl --user enable kmonad-mapping.service`

## Configuration

All configurations are managed through Home Manager and can be found in:
- `home.nix`: Main Home Manager configuration
- `kmonad/`: KMonad-related configurations

## Managing Features

To add new dotfile features:
1. Edit `home.nix` to add your new configuration
2. Apply changes by running:
```bash
home-manager switch
```
