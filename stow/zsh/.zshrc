function initialize_p10k_prompt() {
  # Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
  # Initialization code that may require console input (password prompts, [y/n]
  # confirmations, etc.) must go above this block; everything else may go below.
  if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
  fi
}

function initialize_zgenom() {
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

function main() {
  source $HOME/.zsh-common.sh

  update_path

  initialize_p10k_prompt

  initialize_zgenom

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

main
