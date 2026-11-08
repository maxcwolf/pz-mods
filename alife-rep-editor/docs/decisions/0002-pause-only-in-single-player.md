# 0002: Pause with game speed 0, single player only

Date: 2026-11-06

## Context

Max wants the menu to pause the game when it opens. Vanilla's world map pauses
with `setGameSpeed(0)` and the pause key restores `setGameSpeed(1)` plus the
saved multiplier. Multiplayer can't pause.

## Decision

On open, if the game is running and this isn't a multiplayer client, remember
the speed and multiplier and set speed 0. On close, restore them only if the
speed is still 0, so a player who unpaused or changed speed meanwhile keeps
their choice, and a game that was already paused stays paused.

## How to reverse

Remove the `pauseGame()` call in `ARE_RepEditorWindow.open` and the
`resumeGame()` call in `close`.
