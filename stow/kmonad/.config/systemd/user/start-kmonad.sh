#!/bin/sh
set -ex

# Find the path to kmonad
KMONAD_PATH=$(which kmonad)

# Check if kmonad was found
if [ -z "$KMONAD_PATH" ]; then
  echo "Error: kmonad not found in PATH" >&2
  exit 1
fi

# Start kmonad with the specified configuration
exec "$KMONAD_PATH" ~/.config/thinkpad.kbd
