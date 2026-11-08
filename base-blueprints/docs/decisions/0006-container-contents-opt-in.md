# 0006: Container contents are left behind unless chosen twice

Date: 2026-11-07

## Context

Max (2026-11-07): furniture contents "could have the option to carry over or
not, but they should not by default." Carrying contents into a new game is a
large head start.

## Decision

Two opt-ins, both off by default: "Include container contents" when saving
(item types and counts per container), and "Restore saved contents" on the
saved blueprint, which applying and auto-applying use. Without both, new
containers the blueprint builds are empty (explored, so the game does not
roll loot into a crate the player built). Containers that already match in
the new world (the vanilla fridge that was never moved) keep the loot the
game gave them.

## How to reverse

Fill new containers with the game's loot roll
(`ItemPickerJava.fillContainer`) in `Build.fillContainers` instead of
leaving them empty.
