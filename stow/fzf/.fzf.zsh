# Setup fzf
# ---------
if [[ ! "$PATH" == */home/daniel.robson/.local/share/nvim/site/pack/packer/start/fzf/bin* ]]; then
  PATH="${PATH:+${PATH}:}/home/daniel.robson/.local/share/nvim/site/pack/packer/start/fzf/bin"
fi

# Auto-completion
# ---------------
[[ $- == *i* ]] && source "/home/daniel.robson/.local/share/nvim/site/pack/packer/start/fzf/shell/completion.zsh" 2> /dev/null

# Key bindings
# ------------
source "/home/daniel.robson/.local/share/nvim/site/pack/packer/start/fzf/shell/key-bindings.zsh"
