# This function appends common directories to the PATH environment variable.
function _update_path() {
  # set PATH so it includes user's private bin if it exists, and is not already in PATH
  if [ -d "$HOME/bin" ] && [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
    PATH="$HOME/bin:$PATH"
  fi

  # set PATH so it includes user's private bin if it exists, and is not already in PATH
  if [ -d "$HOME/.local/bin" ] && [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    PATH="$HOME/.local/bin:$PATH"
  fi
}

# This function sets up the SSH agent and adds any common private keys.
# Useful for vscode dev containers.
_setup_ssh_agent() {
  # Get all the identities in the ~/.ssh directory
  keys=($(find ~/.ssh -type f -name 'id_*' -not -name '*.pub'))
  
  # If there are no keys, return
  if [ ${#keys[@]} -eq 0 ]; then
    return
  fi

  if type keychain > /dev/null; then
    eval $(keychain --eval --agents ssh --quick --quiet)

    # Add all found keys to the ssh-agent
    for key in "${keys[@]}"; do
      keychain "$key" --quiet
    done
  fi
}

# This function resolves the path to dotfiles repo path.
function dotfiles_path() {
  local full_path=$(readlink -f "$HOME/.zshrc")

  # Extract the DOTFILES_ROOT_PATH by removing '/stow/zsh/.zshrc'
  local dotfiles_root=$(dirname "$(dirname "$(dirname "$full_path")")")

  # Print the DOTFILES_ROOT_PATH
  echo "$dotfiles_root"
}
