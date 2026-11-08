# Known issues

- Everything below is untested in game; see todo.md.
- A window or curtain that is open or smashed when the blueprint is saved
  is recorded with that sprite. If the new world needs to build it (rather
  than keep its own), it may come out open or broken. Close windows before
  saving.
- Barricades, generators, trees, loose items on the floor and bodies are
  never saved or touched. A barricaded window comes back unbarricaded.
- A zombie breaking a door or window inside the claim counts as a change, and
  saving then removes that door in the new world. There is no way yet to
  untick single tiles before saving.
- Player-built doors (IsoThumpable doors) are rebuilt from their sprite and
  settings; their open sprite, padlock and key are not restored.
- Lua cannot delete files, so a deleted blueprint leaves an empty
  `BaseBlueprints_<id>.txt` in ~/Zomboid/Lua.
- A corrupt blueprint line is reported as a load failure; the parser runs in
  `pcall`, which the game may also print as a stack trace.
- Multiplayer is not supported; the mod does nothing when `isClient()`.
