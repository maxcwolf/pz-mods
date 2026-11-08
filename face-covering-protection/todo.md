# To do

- [ ] First in-game run: enable the mod, load a world, and confirm
  `~/Zomboid/console.txt` has the `[FaceCoveringProtection] tracking N face
  coverings` line with no stack trace. Everything so far is verified against
  the game's bytecode, the real item scripts and stubbed tests, not a running
  game.
- [ ] Confirm the "Face Covering Protection" page and its option show up in the
  sandbox settings with the translated label and tooltip.
- [ ] In game, wear a gas mask, remove its filter, and check the mask type
  drops back within a game minute (and rises again when a filter goes in).
- [ ] Multiplayer is untested. Two players wearing the same mask type, one with
  a filter and one without, share one value: the type drops to its own value
  for both.
- [ ] Head sacks made of garbage bag, tarp and hide count as cloth coverings
  because they match the head sack name. Decide whether to limit that to the
  burlap and cotton ones.
