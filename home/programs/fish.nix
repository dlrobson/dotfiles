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
    # Benchmark scores from https://cursor.com/cursorbench
    shellAbbrs = {
      grb = "git rebase --update-refs";
      grbo = "git rebase --update-refs --onto";
      # cursorbench: not ranked
      claude-haiku = "claude --model claude-haiku-4-5";
      # cursorbench: 54.9% | 27,469 tokens | 53 steps
      claude-sonnet-medium = "claude --model claude-sonnet-5 --effort medium";
      # cursorbench: 58.4% | 58,228 tokens | 86 steps
      claude-sonnet-xhigh = "claude --model claude-sonnet-5 --effort xhigh";
      # cursorbench: 62.1% | 55,622 tokens | 54 steps
      claude-opus = "claude --model claude-opus-4-8 --effort xhigh";
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
    };
  };
}
