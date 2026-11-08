# A-Life Reputation Editor

A Project Zomboid Build 42 add-on for
[Project A-Life](https://steamcommunity.com/sharedfiles/filedetails/?id=3803984183)
(mod id `ProjectALifeNPCs`, v1.4.6). Mod id: `ALifeRepEditor`.

Fix or set your A-Life reputation from one small window, for example when an NPC
steps into the tile of the zombie you were shooting.

## Opening it

- Click the small **Rep: <your level>** button just below the watch clock in
  the top-right corner. Drag it anywhere; right-click it to hide it.
- Or right-click the world and choose **Reputation editor**. When the button is
  hidden, the same menu has **Show reputation button**.

The game pauses while the window is open (single player) and goes back to the
speed it was at when you close it. If you had already paused, it stays paused.

## What's in the window

- **Your level and score**, with a bar across all eleven A-Life levels from
  The Villain (-1000) to The Legend (+1000).
- **Adjust**: -100, -25, -5, +5, +25, +100.
- **Set level**: jump straight to any level (the middle of its score band).
- **Recent kills**: the last six NPCs you killed, each with what A-Life thought
  of it ("meant you no harm. Reputation -40") and an **Undo** button. Undo takes
  back the score change, the faction turning hostile (back to before your first
  hit in that fight), the grudges that NPC's squad and faction picked up, the
  humans-killed count, the "story" NPCs tell about you, and the pending revenge
  tally. Reputation you earned after the kill is kept.
- **Factions**: every A-Life faction's attitude toward you and why, with
  **Forgive** (back to its usual attitude and clear its NPCs' grudges) and
  **Make hostile**. **Forgive everyone** does all of them.

Kills are recorded from the moment the mod is enabled; older kills can still be
fixed with Adjust, Set level and Forgive.

## Multiplayer

Only admins and moderators can use it, unless the server turns on the sandbox
option **Everyone can edit reputation** (A-Life Reputation Editor page). The game
does not pause in multiplayer.

## Development

- `scripts/install.sh` symlinks the mod into `~/Zomboid/mods`.
- `luajit test/run.lua` runs the tests. The editor, hook and UI tests load
  Project A-Life's own reputation, opinion and registry code from the Steam
  workshop folder (override with `ALIFE_LUA=/path/to/ProjectALifeNPCs/42.20/media/lua`),
  so they fail if an A-Life update changes what the editor relies on.
- Pure logic lives in `media/lua/shared/ALifeRepEditor/`, the A-Life glue in
  `server/`, the window, button and menu in `client/`.
- Decisions are in `docs/decisions/`; open checks in `todo.md`.
