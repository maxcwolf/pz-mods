# 0005: A floor click fills the whole room; a drag paints a rectangle

Date: 2026-11-07

## Context

Flooring a room one tile at a time is the slow part of decorating. The game
knows which squares belong to each room (`IsoRoom:getSquares()`).

## Decision

Picking a floor card starts the floor cursor. Hovering previews the whole
room under the mouse on that level; a click paints it. Pressing and
dragging paints a rectangle instead (at most 400 tiles). Outdoors, a click
paints one square. Painting swaps the floor tile's sprite (as the game does
for moveable floor tiles) and clears its overlays; squares with no floor
get one. Undo puts the old sprite back or removes the added floor.

## How to reverse

Make `FloorCursor:targets` return only the hovered square when not
dragging, in `cursors.lua`.
