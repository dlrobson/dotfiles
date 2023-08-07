# load zgen
source "${HOME}/.zgen/zgen.zsh"

# If the init script doesn't exist
if ! zgen saved; then

  # Plugins
  zgen oh-my-zsh

  # generate the init script from plugins above
  zgen save
fi
