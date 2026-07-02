{ config, ... }:

let
  sources = import ../../npins;
  nixvimFlake = import sources.nixvim;
  nixvimLib = nixvimFlake.lib.nixvim;
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

    plugins = {
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
    ];
  };
}
