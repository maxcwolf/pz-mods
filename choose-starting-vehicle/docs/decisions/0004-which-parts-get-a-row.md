# 0004: Which parts get a row, and when "None" is offered

Date: 2026-11-06

## Context

A vehicle has 40 to 70 parts. Most have exactly one possible item (doors,
seats, windows, the battery), so a row for each would bury the add-ons Max
cares about.

## Decision

`Catalog.buildSlots` shows a part when it has a real item to choose and is not
`nodisplay`, and:

- it is an add-on (any part that is not structural): its items plus None, even
  when there is only one item (window armor, snorkel, mudflaps);
- or it is structural with two or more items (tires, brakes, suspension, gas
  tank, muffler, radio): its items, no None.

Structural means a door, window or wheel part, a container whose id ends in
Trunk, Bed, GloveBox or Console (KI5's trunk storage such as `DEF89Trunk`),
or a vanilla part id stem
(Engine, Battery, GasTank, Brake, Suspension, Tire, Door, Window, Windshield,
Seat, Headlight, GloveBox, TruckBed, Trunk, and similar). Parts whose id
minus position words (Front, Rear, Back, Middle, Left, Right) and item list
match are merged into one row labeled with the words their names share.

Since ADR 0008 every displayed part has a row in the mechanics-style lists;
these rules now decide which rows offer a choice (a "slot") and whether None is
one of them. A merged slot's parts can still be set one by one by unticking
"Same for every ...".

## How to reverse

Edit `STRUCTURAL_STEMS` or `POSITION_WORDS` in `catalog.lua`, or change the
`#options >= 2 or allowNone` test in `buildSlots`, and update
`catalog_test.lua` and `ki5-scripts_test.lua`.
