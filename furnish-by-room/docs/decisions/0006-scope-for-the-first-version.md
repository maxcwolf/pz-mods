# 0006: Scope of the first version

Date: 2026-11-07

## Context

The design canvas asked four questions Max had not answered when he asked
for the build: stocked containers (see 0004), extra rooms (bathroom,
office, kids' room, patio), multiplayer, and wall coverings.

## Decision

The first version has the six rooms Max named, floors but no wallpaper or
paint, and is single player only (in multiplayer it logs a line and does
nothing), like his other mods. The undo list holds the last 50 changes and
lives only until the game closes.

## How to reverse

A new room is a new id in `Rooms.ORDER` with a label key in `UI.json`,
plus rules in `classify.lua` that name it. Multiplayer would need the
placement to run on the server (`sendClientCommand`) and is a larger job.
