#!/usr/bin/env bash
# Symlinks the mod into the local Project Zomboid mods folder so edits in this
# repo show up in the game after a restart. Run from anywhere.
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
target="${ZOMBOID_HOME:-$HOME/Zomboid}/mods/BaseBlueprints"
mkdir -p "$(dirname "$target")"
if [ -L "$target" ]; then
  rm "$target"
elif [ -e "$target" ]; then
  echo "$target exists and is not a symlink; move it away first." >&2
  exit 1
fi
ln -s "$repo/mod/BaseBlueprints" "$target"
echo "Linked $target -> $repo/mod/BaseBlueprints"
echo "Enable 'Base Blueprints' under Mods in the game."
