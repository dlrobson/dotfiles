_:

{
  programs.vim = {
    enable = true;

    # Fixes backspace in insert mode and the arrow keys.
    extraConfig = ''
      set nocompatible
      set backspace=2
    '';
  };
}
