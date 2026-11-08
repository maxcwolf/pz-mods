# 0005: Blueprints live in ~/Zomboid/Lua, outside saves

Date: 2026-11-07

## Context

Blueprints must survive into new games, so they cannot live in a save's
mod data. Lua can only write files under `~/Zomboid/Lua` and cannot list
or delete them.

## Decision

Each blueprint is `BaseBlueprints_<id>.txt`; `BaseBlueprints_index.txt`
lists them with their name, place, size and two flags: "apply in new games"
and "restore saved contents". The id is a slug of the name plus a time
stamp, and saving under an existing name replaces it after asking. Deleting
empties the file and removes it from the index. On a new game
(`OnNewGame`) every blueprint marked "apply in new games" is applied. The
window can also apply any blueprint to the current world at any time.

## How to reverse

Blueprint files are plain text and can be copied, shared or deleted by hand;
removing a line from the index hides a blueprint from the window.
