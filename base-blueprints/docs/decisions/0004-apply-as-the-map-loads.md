# 0004: Apply squares as their map loads, tracked in the save

Date: 2026-11-07

## Context

Only the map around the player exists in memory. A blueprint applied at the
start of a new game may be for a building across the map.

## Decision

Applying a blueprint queues all its squares in the save's mod data, grouped
by map column. Columns that are loaded now are applied at once. Others are
applied one tick after `LoadGridsquare` reports a square in them, with a
once-a-game-minute sweep as a fallback. Each square is crossed off when
applied, so it never applies twice, and per-blueprint totals (removed,
added, skipped) are logged when it finishes. A square the blueprint fills
where the map has none (a new upper floor) is created with
`createNewGridSquare`, as the game's build code does.

## How to reverse

Remove the `LoadGridsquare`/`OnTick`/`EveryOneMinute` hooks in `main.lua`;
`Runtime.processLoaded` alone then applies only what is loaded.
