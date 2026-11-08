# Base Blueprints

A Project Zomboid Build 42 mod (single player). Fix up a building the way
you like it once, then have it that way in every new game.

1. **Claim a base.** Right-click inside a building and choose
   *Base Blueprints > Claim this building as your base* (or *...and 6 tiles of
   yard*). The mod records how the building looks right now.
2. **Change it.** Place, move or remove furniture, lay floors, paint, build
   or knock down walls. With *Show changes* on, every changed tile is
   highlighted in gold and the claim's edge in faint blue, on the level
   you're standing on.
3. **Save a blueprint.** Open *Base Blueprints...* from the same menu, type a
   name and press *Save*. Only the changed tiles are saved, unless you tick
   *Save every tile* (for a building you changed before claiming it).
4. **Use it in a new game.** Tick *Apply in new games* on a saved blueprint
   and it is applied when a new game starts. Or select it in any game and
   press *Apply to this world*. Tiles far from you are applied when you get
   close.

Applying only changes what differs: furniture that already matches stays as
it is, with whatever loot the game put in it. Everything else on a saved
tile is replaced by what the blueprint says.

## Container contents

Left behind by default. To carry them, tick *Include container contents*
when saving, then *Restore saved contents* on the saved blueprint. Without
both, containers the blueprint builds start empty.

## Where blueprints are kept

In `~/Zomboid/Lua`: `BaseBlueprints_index.txt` lists them and each one is
`BaseBlueprints_<name>-<number>.txt`. They are plain text and work in every
save. The current claim, and tiles still waiting to be applied, are kept in
the save itself.

## Not carried

Trees, grass and other plants the game grows, loose items on the floor,
bodies, barricades and generators. See [known-issues.md](known-issues.md).

## Development

```bash
luajit test/run.lua
```

```bash
scripts/install.sh
```

The second command links the mod into `~/Zomboid/mods`. Design decisions
are in [docs/decisions](docs/decisions); open in-game checks are in
[todo.md](todo.md).
