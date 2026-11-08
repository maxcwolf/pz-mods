# 0002: Install the chosen parts after spawning and mark damnlib's defaults

Date: 2026-11-06

## Context

KI5 vehicles roll their add-ons in `DAMN.Parts:processDefaults` when each part
initializes. A slot is rolled when it is empty and the vehicle's mod data has
no `defaultPartSet_<partId>` flag; the roll installs through a client command
that single player handles on the spot. So the roll has already happened by
the time `addVehicleDebug` returns.

## Decision

`CSV_Apply.spawn` lets the vehicle spawn normally, then installs or removes
each chosen part the way vanilla's install code does (`setInventoryItem` plus
the part's install or uninstall `complete` hook, so KI5's models update). It
then sets `defaultPartSet_<id>` for every part, so a "None" choice stays
empty after a reload. damnlib's roll already happened inside
`addVehicleDebug` (`addToWorld` runs `createParts` then `initParts`), so the
flags stick. As a safety net, `spawn.lua` checks the parts again 180 ticks
later and, only if something changed, installs the build again and redoes
condition, fuel and battery. Slots left on "Game's choice" keep
whatever the game rolled.

## How to reverse

To let damnlib re-roll on load, remove `CSV_Apply.markDamnDefaults` from
`CSV_Apply.parts`. To skip the second pass, drop the `after(REAPPLY_TICKS)`
call in `CSV_Spawn.run`.
