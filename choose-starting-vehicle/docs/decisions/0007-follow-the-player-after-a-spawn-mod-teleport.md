# 0007: Follow the player after a spawn mod moves them

Date: 2026-11-06

## Context

Spawn-location mods change where a new character starts. Spawn Selector
[B42 Stable] (Workshop 3772052709) replaces the fixed spawn list with a full
world map; "Spawn Here" moves the character to the picked spot and switches on
room lights if it is indoors. Spawn Anywhere [B42] (3392491434) picks a random
building. Neither is installed here and their code could not be read, so
nothing may depend on their internals. Such a mod can work two ways:

- it sets the spawn point before the world loads, so the player is already at
  the chosen spot when OnNewGame fires; or
- it moves the character after the game has started, possibly many seconds
  or a few minutes in, while its map is open.

We spawn 30 ticks after OnNewGame, so in the second case the car is left at
the original spawn point, hundreds or thousands of tiles away.

## Decision

The first spawn waits until the player's square and eight probe tiles on a
ring at the search radius (capped at 40 tiles, inside the roughly 104-tile
area the game keeps loaded around the player) exist in the cell, or 30
seconds pass. That covers the first case and a teleport that happens before
our spawn.

After a successful spawn, `spawn.lua` samples the player every tick and feeds
the pure state machine in `shared/ChooseStartingVehicle/follow.lua`, which
returns "wait", "respawn" or "stop":

- A teleport is a jump of more than 40 tiles between two consecutive ticks.
  Walking or running can't do that, and jumps while the player sits in any
  vehicle are ignored so a frame hitch while driving doesn't count.
- After a jump the player has to stay within 2 tiles (on the same floor) for
  2000 ms of real time (`getTimestampMs`), so a mod that moves the character
  again a moment later, or drops them a floor, is followed to where they
  actually end up. If they end up within 40 tiles of the car, nothing happens.
- Then it waits until the new area is loaded (the same probe), up to
  30 seconds, and respawns: the same plan is spawned near the player first,
  and only if that works is the old car and trailer removed with
  `BaseVehicle:permanentlyRemove()` (it ejects passengers, breaks the tow
  constraint, and removes the vehicle from the world, its chunk and
  VehiclesDB2), along with the key we put in the player's inventory (found
  with `containsRecursive`, so a key moved into a bag is found too; a key the
  player dropped is left alone). The re-apply pass is scheduled for the new
  spawn, and the old spawn is marked so its pending re-apply does nothing.
  If the spawn fails or the area never loads, the old car stays and the
  console says so.
- Watching stops when the player gets into the car or trailer, dies, when
  the car moved more than 3 tiles from where we parked it (someone drove or
  towed it), after 3 follows, or after 10 minutes of active time. Gaps
  between ticks count as at most 1 second each, so a game paused while a map
  is open doesn't use up the window.

The watch is not saved; quitting and loading the game ends it.

## How to reverse

Make `CSV_Spawn.run` call `CSV_Apply.spawn` directly and drop the
`CSV_Spawn.watch` call, or set `maxFollows = 0` in `Follow.DEFAULTS` to keep
the load wait and never follow. Delete `follow.lua`, `test/follow_test.lua`
and `test/spawn_test.lua` to remove it completely.
