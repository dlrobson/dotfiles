# This function sets up the SSH agent and adds any common private keys.
# Useful for vscode dev containers.
function _setup_ssh_agent() {
  # If keychain exists, use it to manage the ssh agent
  if type keychain > /dev/null; then
    eval $(keychain --eval --agents ssh --quick --quiet)
  fi
}

# Source the common file
source $HOME/.zsh-common.sh

# Update the path to include the local bin directories
_update_path

# Setup the ssh agent
_setup_ssh_agent
