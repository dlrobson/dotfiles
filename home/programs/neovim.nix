{ config, ... }:

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

    # Fixes tmux zoom/unzoom (or any terminal resize) leaving one window
    # squeezed to 1 column: a window with winfixwidth set (e.g. a sidebar
    # plugin's file panel) refuses to shrink, so all the size change gets
    # dumped onto the other window instead of being shared. `wincmd =`
    # rebalances every window that isn't fixed-width/height back to equal
    # size; re-running it on every resize keeps this from compounding.
    autoCmd = [
      {
        event = "VimResized";
        command = "wincmd =";
      }
      # Line wrapping breaks diff alignment on narrow windows: a wrapped line
      # spills onto extra screen rows, throwing off the row-for-row alignment
      # diff mode depends on. OptionSet fires exactly when a window enters or
      # exits diff mode, so this only touches diff windows, not normal ones.
      {
        event = "OptionSet";
        pattern = "diff";
        command = "if &diff | setlocal nowrap | endif";
      }
    ];

    # Moved off monokai-pro: its DiffAdd/DiffChange/DiffDelete/override
    # highlights are cached to disk (~/.cache/nvim/monokai-pro-<filter>.json),
    # outside Nix's control - config changes weren't taking effect even after
    # rebuilding + restarting, and deleting the cache file didn't resolve it
    # either. gruvbox.nvim's DiffAdd/DiffChange/DiffDelete are bg-only by
    # default (only DiffText sets fg, intentionally, for the exact changed
    # word) - no override needed for syntax highlighting to show through on
    # changed lines.
    colorschemes.gruvbox = {
      enable = true;
      settings.contrast = "soft";
    };

    # <leader>tt toggles dark/light background and reapplies gruvbox, which
    # reads vim.o.background directly at load time.
    keymaps = vscodeKeymaps ++ [
      {
        key = "<leader>tt";
        action = nixvimLib.mkRaw ''
          function()
            vim.o.background = vim.o.background == "light" and "dark" or "light"
            vim.cmd.colorscheme("gruvbox")
          end
        '';
        options.desc = "Toggle dark/light background";
      }
    ];

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
    #
    # `lsp.servers.<name>.enable` alone only calls `vim.lsp.enable(name)` - it
    # supplies no cmd/filetypes/root_markers unless set explicitly. Neovim's
    # own built-in bundled configs cover only a handful of servers, so
    # plugins.lspconfig (nvim-lspconfig) is needed for the rest (basedpyright,
    # vtsls, nixd) to actually have a cmd/filetypes/root_markers registered at
    # all - it ships default configs, it doesn't enable/start anything itself.
    plugins.lspconfig.enable = true;

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
