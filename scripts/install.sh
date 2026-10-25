#!/usr/bin/env bash
# Symlinks the mod into the local Project Zomboid mods folder so edits in this
# repo show up in the game after a restart. Run from anywhere.
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
target="${ZOMBOID_HOME:-$HOME/Zomboid}/mods/ChooseStartingGear"
mkdir -p "$(dirname "$target")"
if [ -L "$target" ] || [ -e "$target" ]; then
  rm -rf "$target"
fi
ln -s "$repo/mod/ChooseStartingGear" "$target"
echo "Linked $target -> $repo/mod/ChooseStartingGear"
echo "Enable 'Choose Starting Gear' under Mods in the game, then start a new character."
