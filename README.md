# dlrobson's dotfiles

This repo contains my dotfiles, and a script to install them. It also contains a Dockerfile to create a dev image with the dotfiles baked in.

## Published Images

The following images are published to ghcr.io:

| Image                                                                                           | Description                                       |
| ----------------------------------------------------------------------------------------------- | ------------------------------------------------- |
| [dlrobson/dotfiles/base](https://github.com/dlrobson/dotfiles/pkgs/container/dotfiles%2Fbase)   | Base configuration for dotfiles                   |
| [dlrobson/dotfiles/rust](https://github.com/dlrobson/dotfiles/pkgs/container/dotfiles%2Frust)   | Dotfiles with configurations for Rust development |
| [dlrobson/dotfiles/latex](https://github.com/dlrobson/dotfiles/pkgs/container/dotfiles%2Flatex) | Dotfiles tailored for LaTeX development           |

## .github/workflows/build_image_reusable.yml

This workflow builds a target image for both amd64 and arm64, and pushes it to ghcr.io. This is used by other repos to build images and push them to ghcr.io.

Clone the repo to your home directory, and setup the dotfiles:

```bash
git clone https://github.com/dlrobson/dotfiles.git
cd dotfiles
./setup.sh
```

## Install Recommended p10k font

See [here](https://github.com/romkatv/powerlevel10k#meslo-nerd-font-patched-for-powerlevel10k) for instructions on how to install the font.

## Create a Dev Image with the dotfiles baked in

Run:

```bash
docker build --progress=plain \
    --build-arg UID=$(id -u) \
    --build-arg GID=$(id -g) \
    --build-arg BASE_IMAGE=<base-image> \
    -t docker.io/dlrobson/dotfiles -f <path-to-dockerfile> <path-to-repo>
```

# TODO: Features installed with new computer

Had to:

- Install the latest rolling stable version of git for gitconfig features
- Install kmonad
- Added Global Protect VPN: `add-apt-repository ppa:yuezk/globalprotect-openconnect`
- Installed Brave Browser
- Added vscode keyring and installed using apt
- Install htop
- Install nvm curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

