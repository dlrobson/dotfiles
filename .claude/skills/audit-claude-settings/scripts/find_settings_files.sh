#!/usr/bin/env bash
# Recursively find project-level Claude Code config files under a base directory.
# Excludes .git, node_modules, and nix store paths to avoid noise from vendored
# or build-generated content.
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <base_dir>" >&2
  exit 1
fi

base_dir="$1"

find "$base_dir" \
  \( -path "*/.git" -o -path "*/node_modules" -o -path "/nix/store/*" \) -prune -o \
  \( -path "*/.claude/settings.local.json" -o -path "*/.claude/settings.json" \) -type f -print
