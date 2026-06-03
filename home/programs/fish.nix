{ config, pkgs, ... }:

{
  imports = [ ../../modules/common/unstable-pkgs.nix ];

  programs.fish = {
    enable = true;
    package = config.unstablePkgs.fish;
    generateCompletions = false;
    interactiveShellInit = ''
      set fish_greeting # Disable greeting
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
    ];
    shellAbbrs = {
      grb = "git rebase --update-refs";
      grbo = "git rebase --update-refs --onto";
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
