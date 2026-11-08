# 0003: Rebuild objects with the game's own constructors

Date: 2026-11-07

## Context

The game's map loader (`CellLoader.DoTileObjectCreation`) picks the right
Java class for a tile, but it is not exposed to Lua. The furniture placement
code (`ISMoveableSpriteProps:placeMoveableInternal`) is, and the debug tile
brush (`ISBrushToolTileCursor`) uses it to place any tile from a sprite name
with a dummy plank item. It turns plain walls into `IsoThumpable`s, though,
which zombies can break, unlike map walls.

## Decision

Records keep the object's class (read from its Java `toString`, falling back
to `instanceof`). `build.lua` calls the matching constructor with the same
arguments the placement code uses: `IsoDoor` (its string constructor accepts
an open or closed sprite), `IsoWindow`, `IsoWindowFrame`, `IsoCurtain`,
`IsoLightSwitch`, `IsoThumpable` (with its saved settings: door, frame,
corner, floor, stairs, blocking, passable, hoppable, thumpable,
barricadable, dismantable, paintable, health), `IsoMannequin`, the
appliance classes (`IsoStove`, `IsoFireplace`, `IsoRadio`...), and plain
`IsoObject` for map walls and furniture. Then paint, wall decorations,
height on tables, mod data and containers are restored, the game's entity
components are created (`GameEntityFactory.CreateIsoEntityFromCellLoading`)
and `OnObjectAdded` fires so systems like rain barrels pick the object up.
Classes Lua cannot reach (for example `IsoMultiMedia`) go through the tile
brush. Tiles from a mod that is not installed are skipped and logged.

## How to reverse

`Factory.kind` decides the route per class; mapping a class to "brush"
sends it through the game's placement code instead.
