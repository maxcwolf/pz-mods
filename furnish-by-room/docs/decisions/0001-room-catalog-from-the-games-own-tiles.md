# 0001: The room catalog is built from the game's own tiles

Date: 2026-11-07

## Context

Max wants to place furniture "by room type": kitchen appliances, counters
and tile floors in the kitchen; bedding, end tables and dressers in the
bedroom; TVs, couches, chairs, bookshelves and wood floors in the living
room; bar stools, bar items and bar cabinets in the bar; dining furniture;
garage and storage items. The game has no such grouping. Its tiles only
carry a sheet name (`appliances_refrigeration_01`), a GroupName and
CustomName ("White" + "Fridge") and sometimes a container type.

## Decision

The first time the mod opens it reads every loaded tile sheet (vanilla and
modded) and sorts moveable tiles and floors into the six rooms with a rule
table in `classify.lua`: sheet pattern, words in the name, container type,
floor flag. A tile can belong to several rooms (a fridge is in the kitchen,
the bar and the garage). Each piece of furniture is one card: its four
facings fold together and the other tiles of beds and couches are hidden
behind the anchor tile.

`scripts/dump-tiles.py` dumps the real tile list into a gitignored test
fixture, so the tests check the rules against the actual game (every room
has what Max listed, no duplicate cards).

## How to reverse

Replace the rule table with a hand-written list of sprite names per room in
`classify.lua`, and have `Catalog.build` read that list instead of
`Tiles.scan()`. Modded tiles would then no longer show up on their own.
