# To do

Nothing here has run in game yet. Everything is checked with `luajit test/run.lua`
(76 tests), most of them against Project A-Life 1.4.6's real Lua.

## First in-game run

- [ ] Enable the mod after Project A-Life, load a save, and check
  `~/Zomboid/console.txt` for `[ALifeRepEditor] loaded; 4 of 4 A-Life hooks installed.`
  and no stack traces. Fewer than 4 means an A-Life function was renamed.
- [ ] The **Rep: <level>** button shows just below the watch clock (top right), names your level and
  opens/closes the window; dragging moves it and the spot survives a restart
  (`~/Zomboid/Lua/ALifeRepEditor_hud.txt`).
- [ ] Right-click the world: **Reputation editor** is there.
- [ ] The window pauses the game, and closing resumes at the old speed
  (try at 1x and at fast forward). Check the "Paused" overlay doesn't cover it.
- [ ] Translations load (labels show words, not `UI_ALifeRepEditor_...` keys).
  The file is `Translate/EN/UI.json`, matching the working ChooseStartingGear mod.

## The accidental kill

- [ ] Shoot a zombie next to a neutral NPC so the NPC dies. The kill appears
  under Recent kills with the right name, faction and -40.
- [ ] Undo it: score back, the faction no longer Hostile, the squad mates stop
  treating you as an enemy once their current fight state ends. A-Life's own
  reputation popup and HUD should show the new level (we call `Reputation.sync`).
- [ ] Save, reload, and confirm the kill list and undo still work (stored in
  global mod data `ALifeRepEditor.v1`).

## Known limits

- Undo doesn't stop an NPC who is already mid-fight with you that second;
  A-Life's short combat memory (`Relations.aggression`, 10 seconds) runs out
  on its own. We do clear the longer `hostileToPlayerKeys` flag.
- A revenge contract already sworn is called off by A-Life itself on its next
  tick, because `Revenge.owed` sees the faction is no longer hostile. That only
  works for factions that aren't hostile to you by default.
- Multiplayer permission reads `player:getAccessLevel()`. B42 moved to roles;
  check an admin and a plain player on a test server.
- Jumping to a level doesn't count toward A-Life's "highest level reached"
  icons (`RepTrack.reach`); that's on purpose for a cheat, but say so if you'd
  rather it did.
- No poster/icon for the Workshop yet.
