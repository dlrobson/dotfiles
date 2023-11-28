# Setup
First, ensure that all dependencies are installed:
```bash
sudo apt-get install -y stow git ca-certificates curl zsh tmux
```

Clone the repo to your home directory, and setup the dotfiles:
```bash
git clone https://github.com/dlrobson/dotfiles.git
cd dotfiles
./setup.sh
```

## Install Recommended p10k font

See [here](https://github.com/romkatv/powerlevel10k#meslo-nerd-font-patched-for-powerlevel10k) for instructions on how to install the font.

## DockerHub Image

The docker image is available on [DockerHub](https://hub.docker.com/repository/docker/dlrobson/dotfiles).

## Create a Dev Image with the dotfiles baked in

Run:
```bash
docker build --progress=plain \
    --build-arg UID=$(id -u) \
    --build-arg GID=$(id -g) \
    --build-arg USERNAME=<username> \
    --build-arg BASE_IMAGE=<base-image> \
    -t docker.io/dlrobson/dotfiles -f <path-to-dockerfile> <path-to-repo>
```
