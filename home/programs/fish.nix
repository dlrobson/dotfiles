{ config, pkgs, ... }:

{
  imports = [ ../../modules/common/unstable-pkgs.nix ];

  programs.fish = {
    enable = true;
    package = config.unstablePkgs.fish;
    generateCompletions = false;
    interactiveShellInit = ''
      set fish_greeting # Disable greeting
      # Disable fzf-fish's ctrl-r override to keep fish's native history pager
      fzf_configure_bindings --history=
      bind \e\ct _fzf_search_current_token
      bind -M insert \e\ct _fzf_search_current_token
      # Difftastic default context lines
      set -gx DFT_CONTEXT 8
    '';
    plugins = [
      {
        name = "plugin-git";
        inherit (pkgs.fishPlugins.plugin-git) src;
      }
      {
        name = "done";
        inherit (pkgs.fishPlugins.done) src;
      }
      {
        name = "z";
        inherit (pkgs.fishPlugins.z) src;
      }
      {
        name = "hydro";
        inherit (pkgs.fishPlugins.hydro) src;
      }
      {
        name = "fzf-fish";
        inherit (pkgs.fishPlugins.fzf-fish) src;
      }
    ];
    shellAbbrs = {
      grb = "git rebase --update-refs";
      grbo = "git rebase --update-refs --onto";
      claude-haiku = "claude --model claude-haiku-4-5 --effort low";
      claude-haiku-xhigh = "claude --model claude-haiku-4-5 --effort xhigh";
      claude-haiku-max = "claude --model claude-haiku-4-5 --effort max";
      claude-sonnet = "claude --model claude-sonnet-5 --effort high";
      claude-opus = "claude --model claude-opus-4-8 --effort high";
    };
    functions = {
      clean_branches = ''
        set current_branch (git rev-parse --abbrev-ref HEAD)
        set branches_to_delete (git for-each-ref --format='%(if:equals=[gone])%(upstream:track)%(then)%(refname:short)%(end)' refs/heads/ | string match -v ''')

        if test (count $branches_to_delete) -eq 0
          echo "No stale branches to clean up"
          return
        end

        # Filter out current branch from deletion list if present
        set filtered_branches (string match -v "$current_branch" $branches_to_delete)

        # Check if current branch was removed from list
        if test (count $branches_to_delete) -ne (count $filtered_branches)
          echo "Skipping current branch ($current_branch) from deletion"
        end

        if test (count $filtered_branches) -eq 0
          echo "No branches to delete after filtering"
        else
          echo "Deleting stale branches: $filtered_branches"
          git branch -D $filtered_branches
        end
      '';
      gdiff-full = ''
        set -lx DFT_CONTEXT 999
        git diff $argv
      '';
      gdiff-ctx = ''
        if test (count $argv) -lt 1
          echo "Usage: gdiff-ctx <context-lines>"
          return 1
        end
        set -lx DFT_CONTEXT $argv[1]
        git diff $argv[2..]
      '';
    };
  };
}
