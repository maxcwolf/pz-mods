# 0003: A bottom-bar button opens the picker in its own window

Date: 2026-11-06

## Context

Max chose to build the vehicle on the character creation screen. Choose
Starting Gear already adds its panel under the clothing rows
(`arrangeClothingUI`), and a vehicle has many rows (a KI5 Defender has about
fifteen part slots plus paint, cargo and a trailer section).

## Decision

`hooks.lua` adds a "Starting Vehicle" button left of Random in the bottom
bar. It opens `CSV_VehicleWindow`, a large window laid out like the mechanics
window (ADR 0008). The
button shows the chosen vehicle's name. Saved vehicles live in this mod's own
file, separate from vanilla's saved character builds, so a vehicle can be
reused with any character.

## How to reverse

To tie vehicles to character builds instead, hook
`CharacterCreationMain.saveBuildStep2`, `loadOutfit` and `deleteBuildStep2` as
Choose Starting Gear does, and call `CSV_State.saveAs`, `loadNamed` and
`deleteNamed` with the build name.
