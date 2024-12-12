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
function _setup_ssh_agent() {
  # Check if keychain exists, and load all available SSH keys
  if ! ssh-add -L >/dev/null 2>&1; then
    keys=(~/.ssh/id_*) # Collect matching files in an array
    if [[ -e ${keys[0]} ]]; then # Check if at least one match exists
      for key in ~/.ssh/id_*; do
        [[ -f "$key" && ! "$key" =~ \.pub$ ]] && keychain "$key"
      done
    else
      echo "No SSH keys found in ~/.ssh"
    fi
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
