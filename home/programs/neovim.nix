{ config, pkgs, ... }:

let
  sources = import ../../npins;
  nixvimFlake = import sources.nixvim;
  nixvimLib = nixvimFlake.lib.nixvim;

  # Transitional VSCode-style chords, added one at a time as they're needed.
  # Each entry is independent - delete individually as vim-native habits take
  # over (see the description for the vim-native equivalent of each).
  vscodeKeymaps = [
    {
      key = "<C-p>";
      mode = "n";
      action = nixvimLib.mkRaw "require('fzf-lua').files";
      options.desc = "VSCode Quick Open (vim-native: :e + tab-complete, or :FzfLua files)";
    }
    {
      key = "<C-S-f>";
      mode = "n";
      action = nixvimLib.mkRaw "require('fzf-lua').live_grep";
      options.desc = "VSCode Find in Files (vim-native: :grep + :copen, or :FzfLua live_grep)";
    }
  ];
in
{
  imports = [
    ../../modules/common/unstable-pkgs.nix
    nixvimFlake.homeModules.nixvim
  ];

  programs.nixvim = {
    enable = true;
    package = config.unstablePkgs.neovim-unwrapped;

    # Makes `vi`/`vim` (and git's `core.editor = "vi"` in git.nix) resolve to
    # this Neovim, and sets $EDITOR.
    viAlias = true;
    vimAlias = true;
    defaultEditor = true;

    # Matches VSCode's "Monokai" (workbench.colorTheme in settings.json) -
    # not nixvim's `colorschemes.vscode`, which is a Dark+ port and doesn't
    # match this theme.
    colorscheme = "monokai";
    extraPlugins = [ pkgs.vimPlugins.vim-monokai ];

    plugins = {
      # Syntax highlighting - installs all grammar parsers via Nix (reproducible,
      # no runtime compilation). Without this, buffers (including diffview's
      # panes) render as plain text regardless of colorscheme.
      treesitter = {
        enable = true;
        highlight.enable = true;
        indent.enable = true;
      };

      # File icons for fzf-lua's picker and diffview's file panel. Ghostty
      # (our terminal) has built-in Nerd Font symbol fallback since 1.2, so
      # no font/terminal config is needed for these to render.
      web-devicons.enable = true;

      # Live gutter signs for uncommitted hunks vs HEAD - no push/commit needed.
      gitsigns = {
        enable = true;
        settings.on_attach = ''
          function(bufnr)
            local gitsigns = require('gitsigns')
            vim.keymap.set('n', ']c', gitsigns.next_hunk, { buffer = bufnr })
            vim.keymap.set('n', '[c', gitsigns.prev_hunk, { buffer = bufnr })
            vim.keymap.set('n', '<leader>hp', gitsigns.preview_hunk, { buffer = bufnr })
          end
        '';
      };

      # :DiffviewOpen for the working-tree diff, or `:DiffviewOpen main...HEAD`
      # (or any local ref) to review a branch - entirely local, no push needed.
      diffview.enable = true;

      # Picker UI for LSP definitions/references/symbols below.
      fzf-lua.enable = true;
    };

    # Server binaries are NOT installed here - they come from each project's
    # own direnv environment (see e.g. ouster-perception/.envrc: `use nix`).
    # `package = null` stops Nixvim from adding its own copy to PATH; a
    # server only activates if its binary is already on PATH.
    lsp.servers = {
      clangd = {
        enable = true;
        package = null;
      };
      rust_analyzer = {
        enable = true;
        package = null;
      };
      basedpyright = {
        enable = true;
        package = null;
      };
      vtsls = {
        enable = true;
        package = null;
      };
      nixd = {
        enable = true;
        package = null;
      };
    };

    keymaps = vscodeKeymaps;

    lsp.keymaps = [
      {
        key = "gd";
        action = nixvimLib.mkRaw "require('fzf-lua').lsp_definitions";
      }
      {
        key = "gr";
        action = nixvimLib.mkRaw "require('fzf-lua').lsp_references";
      }
      {
        key = "gO";
        action = nixvimLib.mkRaw "require('fzf-lua').lsp_document_symbols";
      }
      # VSCode transitional duplicates of gd/gr above - delete independently
      # once F12/Shift+F12 stop getting reached for.
      {
        key = "<F12>";
        action = nixvimLib.mkRaw "require('fzf-lua').lsp_definitions";
      }
      {
        key = "<S-F12>";
        action = nixvimLib.mkRaw "require('fzf-lua').lsp_references";
      }
      # VSCode transitional: rename symbol (vim-native: vim.lsp.buf.rename()
      # via a keymap of your choosing - delete this once <F2> stops getting
      # reached for).
      {
        key = "<F2>";
        lspBufAction = "rename";
      }
    ];
  };
}
