---
name: audit-claude-settings
description: This skill should be used when the user asks to "audit claude settings", "check claude settings.local.json files", "find missing claude config", "scan repos for claude settings", "compare local claude settings to global config", or wants to know what per-repo Claude Code settings exist outside the home-manager–managed global config.
version: 0.1.0
---

## Purpose

Recursively scan a chosen base directory for per-repo Claude Code config files
(`.claude/settings.local.json` and `.claude/settings.json`), and diff every
setting they contain against the home-manager–managed global config
(`home/programs/claude.nix` in this repo, rendered to `~/.claude/settings.json`).
Surface settings worth promoting to the global config, and flag problems in
the local files themselves (redundant, contradictory, or overly broad rules).

This mirrors the manual survey done once by hand (grepping every sibling
repo's `settings.local.json`) — turn that into a repeatable workflow instead
of re-deriving it from scratch each time.

## Workflow

### 1. Get the base directory

Ask the user which directory to scan, recursively, for Claude Code config
files. Suggest `~/dev` (or the parent of the current repo) as a default if
the user has no preference, but do not assume it — always ask.

### 2. Find local config files

Run the bundled script rather than re-deriving the `find` invocation. Invoke
it by its full path relative to this skill's own directory (not the current
working directory, which may be a different repo):

```bash
/home/admin/dev/dotfiles/.claude/skills/audit-claude-settings/scripts/find_settings_files.sh <base_dir>
```

It prints one file path per line, already excluding `.git`, `node_modules`,
and `/nix/store/*` paths. Read each file returned.

Also enumerate every repo under the base directory, not just the ones with
hits, so step 5's per-repo table can show "none found" rather than silently
omitting repos with no local config:

```bash
find <base_dir> -maxdepth 2 -type d -name .git
```

(a repo's `.git` dir's parent is the repo root — this is the denominator for
the report; the script above only returns positive hits.)

### 3. Load the ground truth

Read two things to establish what's already covered globally:

- `~/.claude/settings.json` — the actual rendered output of the home-manager
  module. This is the ground truth for what's *currently active* (assuming
  `home-manager switch` has been run since the last edit).
- `home/programs/claude.nix` in this repo (the `programs.claude-code.settings`
  attrset) — the source of truth for making edits, since it has line-numbered
  structure and existing comments to follow. Cite exact line numbers from this
  file when recommending an edit.

If `~/.claude/settings.json` and `claude.nix`'s rendered intent appear to
disagree, note it — it likely means `home-manager switch` hasn't been run
since the last edit, not a bug.

### 4. Diff each local file against the global config

For every top-level key in a local file, not just `permissions`, check:

- **Missing globally**: the key/value exists in the local file but not in
  `~/.claude/settings.json` at all → promotion candidate.
- **`permissions.allow`/`ask`/`deny` entries**: check each entry in these
  arrays individually against the global equivalents (this is the most
  common category — call it out as its own subsection in the report).
- **Redundant**: an entry the local file grants that's already implied
  globally. Two cases worth checking specifically in this repo's config:
  - Any `Bash(...)` allow entry is likely moot if `sandbox.enabled` and
    `sandbox.autoAllowBashIfSandboxed` are both `true` globally — in
    Auto-Allow sandbox mode, essentially all sandboxed Bash commands already
    run without a prompt regardless of an explicit allowlist entry. Flag
    these as "harmless but no longer functionally necessary," not as errors.
  - An entry duplicating something already in the global `permissions.allow`
    list verbatim.

  Do not conflate `sandbox.network.allowedHosts` with `permissions.allow`
  `WebFetch(domain:...)` entries — they are different mechanisms. The former
  is the Bash sandbox's network egress allowlist (what a sandboxed shell
  command may reach); the latter is a permission-prompt bypass for the
  `WebFetch` tool specifically. A host being in one does not mean it's
  covered by the other — check each independently.
- **Contradictory**: a pattern allowed locally that matches something denied
  globally (or vice versa) — flag clearly, this is a real conflict, not just
  clutter.
- **Overly broad**: bare wildcards, or rules allowlisting interpreters/shells/
  task runners generically (e.g. `Bash(python *)`, `Bash(bash *)`,
  `Bash(nix-shell *)`) rather than specific safe subcommands. These carry
  code-execution risk regardless of sandboxing intent (arbitrary `-p`/`--run`
  arguments) — call these out even if the user didn't ask about safety.
- **Malformed/empty**: files that fail to parse as JSON, or contain an empty
  `permissions` object with no entries.

### 5. Report

Produce two sections:

1. **Per-repo table**: `Repo | Setting | Local value | Global status |
   Recommendation` for every repo scanned (including ones with no local file,
   noted as "none found," so the user has full coverage visibility).
2. **Cross-repo recurring**: anything appearing independently in 2+ repos.
   This is the strongest signal for promotion — a setting only one repo
   needs is more likely genuinely repo-specific.

Keep the report scannable — group by finding type (missing, redundant,
contradictory, overly broad), not just by repo.

### 6. Offer to apply

After reporting, ask the user (in bulk, or per finding for anything
ambiguous) whether to add selected promotion candidates to
`home/programs/claude.nix`. Only proceed on explicit confirmation — do not
apply anything unprompted.

If the user confirms:

1. Edit `home/programs/claude.nix`, following the existing structure and
   comment style already present in its `settings` block (explain *why* a
   rule exists, not just what it does, matching the file's current
   comments).
2. Validate with `check` and `run-tests` (provided on `PATH` by direnv)
   before reporting success.
3. Remind the user that `home-manager switch` is still required to apply the
   change (per this repo's convention — never run it automatically).

Never write to any of the scanned repos' own local settings files — this
skill is read-only with respect to every repo except `home/programs/claude.nix`
in this one, and only after explicit confirmation.
