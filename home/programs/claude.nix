{
  config,
  pkgs,
  lib,
  ...
}:

{
  home = {
    packages = [ config.unstablePkgs.claude-code ];

    sessionPath = [ "${config.home.homeDirectory}/.npm-global/bin" ];

    activation = {
      installClaudeCodeMarketplace = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        export PATH="${config.unstablePkgs.claude-code}/bin:${pkgs.git}/bin:${pkgs.jq}/bin:${pkgs.openssh}/bin:$PATH"

        marketplaceName="dlrobson-plugins"
        $DRY_RUN_CMD claude plugin marketplace add "dlrobson/plugin-marketplace"
        $DRY_RUN_CMD claude plugin marketplace update "$marketplaceName"

        # Discover all plugins currently in the marketplace
        tmpfile=$(mktemp)
        trap 'rm -f "$tmpfile"' EXIT
        claude plugin list --available --json 2>/dev/null > "$tmpfile"
        currentPlugins=$(jq -r --arg m "$marketplaceName" \
          '.available[] | select(.marketplaceName == $m) | .pluginId' "$tmpfile")

        # Install all plugins from the marketplace
        while IFS= read -r plugin; do
          [ -n "$plugin" ] && $DRY_RUN_CMD claude plugin install "$plugin"
        done <<< "$currentPlugins"
      '';
    };
  };
}
