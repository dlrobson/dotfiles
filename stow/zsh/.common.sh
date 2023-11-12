# This function sets up the SSH agent and adds any common private keys.
function setup_ssh_agent() {
  # Check if the .ssh directory exists
  if [ -d "$HOME/.ssh" ]; then
    # Check if an SSH agent is already running
    RUNNING_AGENT=$(ps -ax | grep 'ssh-agent -s' | grep -v grep | wc -l | tr -d '[:space:]')

    # If there is no agent running, start one
    if [ "$RUNNING_AGENT" = "0" ]; then
      # Start a new instance of the SSH agent. 
      ssh-agent -s &> $HOME/.ssh/ssh-agent
    fi

    # Load the SSH agent environment variables
    eval `cat $HOME/.ssh/ssh-agent`

    # List of common private key filenames to check
    common_key_filenames=("id_rsa" "id_dsa" "id_ecdsa" "id_ed25519")
    key_added=false

    for key_filename in "${common_key_filenames[@]}"; do
      if [ -f "$HOME/.ssh/$key_filename" ]; then
        ssh-add "$HOME/.ssh/$key_filename" &>/dev/null
        if [ $? -eq 0 ]; then
          key_added=true
          echo "Added key: $HOME/.ssh/$key_filename"
        fi
      fi
    done

    if [ "$key_added" = false ]; then
      echo "No common private keys found in ~/.ssh/."
    fi
  else
    echo "Error when setting up SSH agent: ~/.ssh/ does not exist."
  fi
}

# This function appends common directories to the PATH environment variable.
function update_path() {
  # set PATH so it includes user's private bin if it exists, and is not already in PATH
  if [ -d "$HOME/bin" ] && [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
    PATH="$HOME/bin:$PATH"
  fi

  # set PATH so it includes user's private bin if it exists, and is not already in PATH
  if [ -d "$HOME/.local/bin" ] && [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    PATH="$HOME/.local/bin:$PATH"
  fi
}

update_path

setup_ssh_agent
