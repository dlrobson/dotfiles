{ lib, ... }:
let
  sources = import ../../pins.nix;
in
{
  # Single declaration site for the Claude Code plugin marketplaces and the
  # enabled plugin set, split out of `programs.claude-code.settings` so the
  # registry is readable on its own rather than buried in Claude's harness
  # config.
  options.agentPlugins = {
    marketplaces = lib.mkOption {
      type = with lib.types; attrsOf (either package path);
      default = { };
      description = ''
        Plugin marketplaces, keyed by marketplace id. Each value is a
        directory containing a `.claude-plugin/marketplace.json`.
      '';
    };

    enabled = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Enabled plugins as `plugin-id@marketplace-id`, referencing a
        marketplace declared above.
      '';
    };
  };

  config.agentPlugins = {
    marketplaces = {
      # Named away from "claude-plugins-official": Claude Code hardcodes
      # an exact-match set of reserved marketplace names (including
      # "claude-plugins-official" and, as of 2.1.209, "anthropic-plugins")
      # and refuses to load any of them from a source it can't verify as
      # the anthropics GitHub org - which a vendored nix-store directory
      # source never satisfies, even when the content genuinely is
      # anthropics/claude-plugins-official. Any name outside that fixed
      # set (exact string match, not a substring/pattern check) works.
      # https://github.com/anthropics/claude-code/issues/18329
      claude-plugins-official-mirror = sources.claude-plugins-official;
    };

    enabled = [
      "claude-code-setup@claude-plugins-official-mirror"
      "plugin-dev@claude-plugins-official-mirror"
      "pr-review-toolkit@claude-plugins-official-mirror"
    ];
  };
}
