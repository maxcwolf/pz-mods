# 0001: Read part options from the game's stored script text

Date: 2026-11-06

Superseded by 0006: the game keeps no text for templates at runtime, so this
found no template parts in game.

## Context

The picker runs on the character creation screen, before any world exists, so
no `BaseVehicle` can be created to ask its parts for their item lists. The
script-side `VehicleScript$Part.itemType` list is a public Java field, and Lua
cannot read fields (the reflection helpers `getClassFieldVal` only work in
debug mode). KI5's own part configs (`DAMN.Parts:processConfigV2`) live in
server Lua, which only loads with the world, and their tables are captured in
closures anyway.

The 42.21 jar shows `ScriptBucket.CreateFromTokenPP` calling
`BaseScriptObject.addLoadedScriptBody(modId, token)` for every script object,
unconditionally, and `getLoadedScriptBodies()` is public on an exposed class.

## Decision

`runtime.lua` reads each vehicle's and template's stored text and parses it
with a small pure parser (`script-text.lua`). `vehicle-parts.lua` replays the
game's rules: templates and part blocks in source order, `Name/part/Id` copies
one part, other `Name/kind/Id` copies are not parts, `Prefix*` part blocks
change parts already defined, and specific items get the mechanic type
appended. The paired mod id tells vanilla and modded vehicles apart; a body
that mentions damnlib (`DAMN`) marks a KI5 vehicle.

A fidelity test parses the real installed KI5 and vanilla scripts.

## How to reverse

If a later build exposes the item list (for example a `getItemType()` on the
script part), replace `CSV_Runtime.entry`'s parsing with that call and keep
`catalog.lua`, which only needs `{id, itemTypes, specificItem, category, ...}`
records.
