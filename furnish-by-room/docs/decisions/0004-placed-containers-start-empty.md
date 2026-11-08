# 0004: Furniture the mod places comes empty

Date: 2026-11-07

## Context

The design canvas asked Max whether placed fridges and dressers should be
stocked. He did not answer before asking for the build, so this is the
default chosen to start with. Free furniture is already a cheat; free loot
in every placed cabinet would make it a much bigger one.

## Decision

Every container on a placed object is marked explored, so the game never
rolls loot into it. It starts empty.

## How to reverse

In `Place.emptyContainers`, call `ItemPickerJava.fillContainer(container,
player)` instead of only `setExplored(true)`, or add a tick box under
Options > Mods that chooses between the two.
