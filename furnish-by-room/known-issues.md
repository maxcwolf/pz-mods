# Known issues

- **Untested in game.** Everything below "Check in game" in
  [todo.md](todo.md) is still open. The tests run the mod against a fake
  game, so the calls into the real game are written from its Lua and Java
  signatures (42.21) but have not run there yet.
- **First open may hitch.** The catalog is built by reading every tile
  sheet the first time the mod opens. If `getSprite` makes empty sprites
  for missing tile numbers instead of returning nil, each sheet is read to
  tile 1023, which is slower.
- **Cards show one tile.** A bed or couch card shows only its first tile.
- **Same-named variants show once.** When one sheet has two different
  pieces with exactly the same name, only the first shows.
- **Floor overlays are not undone.** Painting clears a floor's blends and
  dirt; undo restores the floor tile but not those.
- **Undo does not bring contents back.** Removing a stocked fridge and
  undoing puts back an empty fridge. The undo list is lost when the game
  closes.
- **No TV stand tile.** The game has no "TV stand" piece; low tables are
  under Living room > Tables.
- **Narrow screens.** Below about 1100 px wide the strip's room buttons
  can overlap its right-hand buttons.
- **Single player only.** In multiplayer the mod does nothing.
