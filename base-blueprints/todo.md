# To do

## Check in game (single player)

Grep ~/Zomboid/console.txt for `[BaseBlueprints]` and `STACK TRACE`.

- [ ] Right-click inside a house: "Base Blueprints" has both claim options;
      on a lawn with no building only "Open Base Blueprints...".
- [ ] Claiming shows a halo note and the console prints `claimed x,y WxH`;
      the claim edge shows in faint blue on your level.
- [ ] Opening and closing a door, smashing a window and switching a lamp on
      do not turn their tiles gold.
- [ ] Moving a couch, removing a fridge, laying carpet, painting a wall,
      knocking out a wall and building a wooden wall each turn the right tiles
      gold within about two seconds; walking upstairs shows that level's tiles.
- [ ] Save as "Test": the console prints `saved test-...: N squares` and
      ~/Zomboid/Lua has BaseBlueprints_index.txt and the blueprint file.
- [ ] Start a new game with "Apply in new games" ticked: the building matches,
      kept furniture still has loot, built containers are empty.
- [ ] The same with a blueprint saved with contents and "Restore saved
      contents" ticked: the crates have their items.
- [ ] Apply from the window in a game where the building is far away: the
      message says some tiles apply later, and they do when you get there
      (console `finished ...`).
- [ ] Rebuilt walls block movement and sight; rebuilt doors open and close;
      rebuilt windows open, can be climbed through and can be barricaded.
- [ ] Rebuilt plain map walls cannot be broken by zombies; player-built
      wooden walls can.
- [ ] Rebuilt fridges, stoves and lamps work with power; rain barrels collect
      water; workbenches (B42 entities) still work.
- [ ] Multi-tile furniture (beds, couches) can be picked up after being
      rebuilt.
- [ ] Upper floors the player built on an empty level appear in the new game.
- [ ] Performance: no stutter while "Show changes" is on in a yard claim.

## Requested 2026-11-07

- Apply at game start or from an in-game menu at any time (done; check in
  game above).
- Container contents optional, off by default (done; check in game above).

## Ideas

- Untick single tiles in the highlight before saving.
- Claim an area by dragging a rectangle, for bases outside buildings.
- Pick blueprints on the character creation screen as well.
- Carry barricades and generators.
