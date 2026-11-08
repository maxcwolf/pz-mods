# 0006: Read parts from a scratch vehicle the engine builds

Date: 2026-11-06

Supersedes 0001.

## Context

In game the parts list was empty for every vehicle. ADR 0001 read each
template's stored script text, but only vehicle scripts keep theirs:
`ScriptBucket$Template.CreateFromTokenPP` never calls `addLoadedScriptBody`,
so `VehicleTemplate:getLoadedScriptBodies()` is empty at runtime. Templates
hold every KI5 add-on and vanilla's tires, brakes and suspension, so nothing
was left to choose. The offline tests read the template files from disk, which
is why they passed.

`BaseVehicle`'s constructor doesn't touch the cell it's given. So
`BaseVehicle.new(nil)`, `setScriptName(name)` and `setScript()` build a
vehicle that is never added to the world. Its `VehiclePart`s have public
getters for everything the picker needs: `getItemType()` (the final list, with
the mechanic type already appended to specific items), `getCategory()`,
`getWheelIndex()`, `getDoor()`, `getWindow()`, `isContainer()`,
`getContainerCapacity()`, and `getScriptPart()` with each model's id and file.

## Decision

`CSV_Runtime.probe` builds that scratch vehicle once per vehicle (cached) and
reads it with `VehicleParts.fromVehicle`, inside a pcall. If the engine refuses,
the console says so and the vehicle shows no parts. Paints still come from the
vehicle script's own stored text, which the game does keep.

The text resolver moved to `test/harness/script-resolver.lua`. The fidelity
tests still use it to check the catalog rules against the real KI5 and
vanilla files. `runtime_test.lua` reproduces the bug: its fake templates have
no text, and it failed on the old code.

## How to reverse

Put `vehicle-parts.lua`'s old `resolve` back (it is in the harness file) only
if a later build stores template text. Otherwise keep the scratch vehicle;
`catalog.lua` still takes plain `{order, byId}` records either way.
