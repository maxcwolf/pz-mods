# 0001: Record the building when it is claimed, compare to find changes

Date: 2026-11-07

## Context

The mod has to know which tiles the player changed. Lua cannot read the
map's original state from the game's map files, and the game has no single
event for every kind of change: furniture placement fires `OnObjectAdded`,
but swapping a floor (`setSprite`), painting a wall (`setOverlaySprite`) or
a sledgehammer each take different paths.

## Decision

Claiming a building records a short text per square (the "signature") of
every object on it: class, sprite, facing, floor flag, paint overlay and
attached decorations. Finding changes reads the squares again and compares.
A square whose sorted signatures differ has changed. The claim covers the
building's footprint plus a margin (1 tile for the house only, 6 with yard),
from its lowest level to the roof level above the top floor; the game puts
east and south outer walls on the squares just outside the rooms, so the
margin is never below 1.

Doors, windows, curtains, lamps, stoves and other objects whose sprite
changes with use are compared by sprite sheet, so opening a door or
switching a lamp on is not a change. Trees, erosion sprites (grass, vines,
leaves, wall cracks), grass the game can remove, loose items, bodies, fire,
broken glass, barricades and generators are ignored everywhere.

Only signatures are kept in the save's mod data, so a claim stays small.

## How to reverse

Replace `Runtime.findChanges` with an event-driven tracker
(`OnObjectAdded`, `OnObjectAboutToBeRemoved`, `OnTileRemoved`) that marks
squares dirty; the blueprint format does not depend on how changes are
found.
