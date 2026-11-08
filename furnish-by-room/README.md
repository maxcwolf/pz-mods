# Furnish by Room

A Project Zomboid Build 42 cheat mod (single player) for decorating. Pick a
room type, then place its furniture and floors for free.

| Room | What it offers |
| --- | --- |
| Kitchen | Fridges, ovens, microwaves, dishwashers, counters, sinks, wall cabinets, tables, tile floors |
| Bedroom | Beds, dressers, wardrobes, nightstands, desks, TVs, lamps, rugs, carpet and wood floors |
| Living room | Couches, armchairs, TVs, radios, coffee tables, bookshelves, lamps, plants, paintings, pianos, carpet and wood floors |
| Dining room | Dining tables, chairs, benches, china cabinets, chandeliers, wood and tile floors |
| Bar | Bar stools, bar counters, back-bar cabinets, bar fridges, pool table, jukebox, arcade, dartboard, neon signs, wood and bar floors |
| Garage | Workbenches, tool cabinets, metal shelves, lockers, crates, barrels, washers and dryers, freezers, concrete floors |

The lists come from the game's own tiles, so furniture from tile mods
shows up too when it matches (see
[docs/decisions/0001](docs/decisions/0001-room-catalog-from-the-games-own-tiles.md)).

## Using it

- **Open:** press **F7**, or right-click a room and choose *Furnish this
  kitchen...*. It opens on the room you're standing in.
- **Place:** click an item. A see-through preview follows the mouse:
  normal means it fits, red means it doesn't. Click to place, **R** to
  rotate, keep clicking to place more. **Right-click** or **Esc** when done.
- **Floors:** click a floor, then click inside a room to floor the whole
  room, or press and drag to paint a rectangle.
- **Remove:** the *Remove* button, then click any piece of furniture (beds
  and couches go as one piece).
- **Undo:** **Ctrl+Z** or the *Undo* button, for the last 50 changes.

Placed furniture is made by the game's own furniture code, so it should be
the real working object (a fridge that cools, a bed to sleep in), and its
containers start empty.

## Two layouts

- **Catalog window** (default): room tabs, category filters, search and a
  grid of pictures. It shrinks to a small chip while you place.
- **Bottom strip:** eight items at a time along the bottom of the screen,
  with room buttons and a category button that steps through groups. It
  stays up while you place.

Switch with the button in either layout (*Bottom strip* / *Catalog*) or
under **Options > Mods > Furnish by Room**, which also has the open key and
*Ignore placement rules* (place on any square with a floor, even where the
game would say no).

## Development

```bash
luajit test/run.lua
```

```bash
python3 -I scripts/dump-tiles.py
```

```bash
scripts/install.sh
```

The first runs the tests. The second writes the real tile list to a
gitignored test fixture so the catalog tests check the rules against the
game (run it again after a game update). The third links the mod into
`~/Zomboid/mods`. Design decisions are in [docs/decisions](docs/decisions);
in-game checks are in [todo.md](todo.md); limits are in
[known-issues.md](known-issues.md).
