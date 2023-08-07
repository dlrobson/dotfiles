#!/bin/sh

# This script sets up symlinks to all the dotfiles
# in the user's home directory.
base=${HOME}/dotfiles

# Set up tmux plugin manager:
mkdir -p ~/.tmux/plugins
if [ ! -d ~/.tmux/plugins/tpm ]; then
	git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi

# If zgen is not installed, install it
if [ ! -d ${HOME}/.zgen/zgen.zsh ]; then
	git clone https://github.com/tarjoilija/zgen.git "${HOME}/.zgen"
fi


# Set up all of the configs:
cd ${base}/stow

# This for loop iterates through all directories
# contained in the stow directory. This makes
# it easy to add configurations for new applications
# without having to modify this script.
for app in */; do
	stow --override="(.*?)" -t ${HOME} $app
done;
