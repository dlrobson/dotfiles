# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi


# Check if z-plug is installed or not. If not, install it:
if [[ ! -d ~/.zplug ]]; then
  echo "z-plug not installed. Installing it."
  curl -sL --proto-redir -all,https https://raw.githubusercontent.com/zplug/installer/master/installer.zsh | zsh
fi

source ~/.zplug/init.zsh

# Bundles from robbyrussell's oh-my-zsh.
zplug "plugins/git", from:oh-my-zsh
zplug "plugins/gitfast", from:oh-my-zsh # Faster git command line completion
zplug "plugins/wd", from:oh-my-zsh # Warp directory - easily switch to particular directories
zplug "plugins/command-not-found", from:oh-my-zsh
zplug "plugins/vi-mode", from:oh-my-zsh
zplug "lib/completion", from:oh-my-zsh # Better tab completion
zplug "lib/directories", from:oh-my-zsh # Provides the directory stack
zplug "lib/history", from:oh-my-zsh # Provides history management
zplug "lib/completion", from:oh-my-zsh # Provides completion of dot directories
zplug "lib/theme-and-appearance", from:oh-my-zsh # Provides auto cd, and some other appearance things

# Syntax highlighting bundle.
zplug "zsh-users/zsh-syntax-highlighting"

# fzf
zplug "zsh-users/zsh-autosuggestions"

# Load the theme.
zplug romkatv/powerlevel10k, as:theme, depth:1

# Install plugins if there are plugins that have not been installed
if ! zplug check --verbose; then
    printf "Install? [y/N]: "
    if read -q; then
        echo; zplug install
    fi
fi


# Then, source plugins and add commands to $PATH
zplug load

# Increase history file sizes, so we can store all history
export HISTSIZE=1000000000
export SAVEHIST=1000000000

# Set fzf to use ag if ag is available:
if type ag > /dev/null; then
  export FZF_DEFAULT_COMMAND='ag -g ""'
fi
# Nord colour scheme for fzf
export FZF_DEFAULT_OPTS='--color dark'


# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"


[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/home/daniel.robson/dev/ouster-perception/google-cloud-sdk/path.zsh.inc' ]; then . '/home/daniel.robson/dev/ouster-perception/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/home/daniel.robson/dev/ouster-perception/google-cloud-sdk/completion.zsh.inc' ]; then . '/home/daniel.robson/dev/ouster-perception/google-cloud-sdk/completion.zsh.inc'; fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
