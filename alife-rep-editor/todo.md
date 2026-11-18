# To do

First in-game run (2026-11-08): the hooks install, but the window stuck on
"Loading" and every button threw a Kahlua `tonumber` ClassCastException. Fixed
(see below); recheck in game. Everything is checked with `luajit test/run.lua`
(125 tests), most of them against Project A-Life's real Lua (1.5.2 as of
2026-11-17).

## First in-game run

- [ ] The window loads your level, kills and factions instead of "Loading",
  and **+5** changes the score with no `opinionBaseline` stack trace in
  console.txt. (Fixed: `tonumber(f())` got a stray second value from a Kahlua
  tail-call chain and read it as a number base. `test/kahlua_test.lua` now
  bans that pattern.)
- [ ] Enable the mod after Project A-Life, load a save, and check
  `~/Zomboid/console.txt` for `[ALifeRepEditor] loaded; 6 of 6 A-Life hooks installed.`
  and no stack traces. Fewer than 6 means an A-Life function was renamed.
  (4 of 4 was confirmed before the Crew tab added two `ProfileHydrator` hooks.)
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

## People tab (added 2026-11-17)

- [ ] The tabs switch cleanly, with nothing from the other tab left on screen.
- [ ] Typing in the search box filters the list and doesn't trigger game hotkeys.
- [ ] Right-click an NPC: **Edit relationship with <name>** opens on them, also
  for someone you've never met.
- [ ] Set someone to "Likes you" and talk to them: A-Life's own opinion line
  matches, and its reason reads "They've warmed to you."
- [ ] Make hostile, then Calm down, on a neutral NPC nearby: they draw on you and
  then stop (allow for A-Life's 10-second combat memory).
- [ ] **Join my crew** on someone a few steps away: they follow you and show in
  A-Life's Companions sheet. **Leave my crew** releases them.
- [ ] Join my crew on someone 20-50 tiles away on the same floor: they appear
  beside you (A-Life's own `Companions.bringNear`). Check they don't get stuck
  or snap back.
- [ ] Join my crew on a member of a hostile faction (Blacktop-style): they stop
  treating you as hostile and fight for you.
- [ ] Join my crew on a safehouse visitor and on a captive: the visit or
  captivity ends cleanly, as with A-Life's own Join options.
- [ ] With 100+ NPCs met, opening the People tab and each click stay quick (every
  listed NPC's stance is worked out on each refresh).

## Crew tab (added 2026-11-17)

- [ ] **Skills and gear** on the People tab opens the Crew tab on that person;
  the member buttons switch between crew members.
- [ ] Raise first aid to 2 and check A-Life's Companions sheet shows it and they
  offer to bandage you when you're hurt.
- [ ] Set Accuracy to 10 and Strength to 10: they visibly hit harder and miss
  less. Walk far enough away that they unload, come back, and check the values
  held (`ProfileHydrator.plan` hook).
- [ ] Item search finds weapons, clothing and ordinary items with the right kind
  label (reads `getItemType():toString()` like vanilla's item spawner; if every
  result says "Item", the type name changed).
- [ ] Give a shotgun: they hold it and fire it, with 60 spare rounds; +30 ammo
  adds to the spare count. Try it on an NPC whose profile has no guns.
- [ ] Give a hat or jacket: they put it on at once, replacing what was in that
  spot, and still wear it after unloading and loading, and after a season
  change.
- [ ] Give 10 bandages, unload and reload them: the bandages are still there
  (A-Life keeps up to 24 marked items). Remove takes the whole stack.
- [ ] Take off a worn piece; Remove a weapon they're holding (they switch to
  another or bare hands).

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
- A set NPC opinion drifts back toward their usual feeling a few points a day,
  like any A-Life opinion (ADR 0005).
- The People list holds at most 200 people (most recently changed first).
- Join my crew only works for NPCs whose body is loaded near you; A-Life's
  `bringNear` moves them on the same floor only, so someone upstairs is refused
  as too far away.
- With NPC opinions turned off in A-Life's sandbox, the People tab is empty, so
  Join my crew isn't reachable either.
- Crew fighting stats and outfits stay with the NPC after they leave your crew
  (they're keyed by NPC in `ALifeRepEditor.v1.crew`); `Crew.forget(uid)` clears
  one, but there's no button for it.
- Items handed over aren't added to A-Life's death drops, the same as items
  given through A-Life's own Gear tab.
- A-Life keeps at most 8 weapons and 24 other handed-over items when a body
  unloads; anything past that is lost on the next reload.
