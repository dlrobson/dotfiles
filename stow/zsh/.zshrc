function _initialize_p10k_prompt() {
  # Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
  # Initialization code that may require console input (password prompts, [y/n]
  # confirmations, etc.) must go above this block; everything else may go below.
  if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
  fi
}

function _initialize_zgenom() {
  # load zgenom
  source "${HOME}/.zgenom/zgenom.zsh"

  # Check for plugin and zgenom updates every 7 days
  # This does not increase the startup time.
  zgenom autoupdate

  # If the init script doesn't exist
  if ! zgenom saved; then
    # Plugins
    zgenom oh-my-zsh
    zgenom oh-my-zsh plugins/git
    zgenom oh-my-zsh plugins/gitfast
    zgenom oh-my-zsh plugins/wd
    zgenom oh-my-zsh plugins/command-not-found
    zgenom load zsh-users/zsh-syntax-highlighting
    zgenom load zsh-users/zsh-autosuggestions

    # fzf
    zgenom load unixorn/fzf-zsh-plugin

    # Theme
    zgenom load romkatv/powerlevel10k powerlevel10k

    # generate the init script from plugins above
    zgenom save

    # Compile your zsh files
    zgenom compile "$HOME/.zshrc"
  fi
}

function _main() {
  source $HOME/.zsh-common.sh

  _update_path

  _initialize_p10k_prompt

  _initialize_zgenom

  # Increase history file sizes, so we can store all history
  export HISTSIZE=1000000000
  export SAVEHIST=1000000000

  export TERM=screen-256color

  # Set fzf to use ag if ag is available. It's faster
  if type ag > /dev/null; then
    export FZF_DEFAULT_COMMAND='ag -g ""'
  fi

  # See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
  ZSH_THEME="robbyrussell"

  # To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
  [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
}

_main

# Aliases
clean_branches() {
  git fetch --all --prune && git branch -D $(git branch -vv | grep ': gone]'|  grep -v "\*" | awk '{ print $1; }')
}

# Function to check if an update is available for the dotfiles repo
function _is_update_available() {
  # Resolve the path to the dotfiles repo
  local dotfiles_root_path=$(dotfiles_path)

  # Fetch the latest changes from the remote without merging
  git -C "$dotfiles_root_path" fetch origin

  # Get the current branch name
  local current_branch=$(git -C "$dotfiles_root_path" rev-parse --abbrev-ref HEAD)

  # Get the latest commit hash of the remote current branch
  local remote_commit=$(git -C "$dotfiles_root_path" rev-parse "origin/$current_branch")

  # Get the latest commit hash of the local current branch
  local local_commit=$(git -C "$dotfiles_root_path" rev-parse "$current_branch")

  # Compare the commit hashes to check if an update is available
  if [ "$local_commit" != "$remote_commit" ]; then
    # Update available: The remote branch has changes
    return 0
  else
    # No update available: The local branch is up-to-date
    return 1
  fi
}

# Pulls the latest dotfiles, then runs the setup.sh script in that repo.
# Sources the .zshrc file afterwards. Returns a warning if the current branch is not master.
update_dotfiles() {
  # Resolve the path to the dotfiles repo
  local dotfiles_root_path=$(dotfiles_path)

  # Check the current branch
  local current_branch=$(git -C "$dotfiles_root_path" rev-parse --abbrev-ref HEAD)

  # Warn if the current branch is not master
  local MASTER_BRANCH="master"
  if [ "$current_branch" != "$MASTER_BRANCH" ]; then
    echo "Warning: You are on branch '$current_branch', not '$MASTER_BRANCH'."
  fi

  # Call the _is_update_available function and exit if an update
  # is available. This will source the zshrc
  if ! _is_update_available; then
    echo "No update available for dotfiles."
    return
  fi

  # Pull the latest changes from the remote
  git -C "$dotfiles_root_path" pull

  # Run the setup.sh script in the dotfiles repo
  sh "$dotfiles_root_path/setup.sh"

  echo "Updated dotfiles. Run `source ~/.zshrc` to get the latest changes."
}
