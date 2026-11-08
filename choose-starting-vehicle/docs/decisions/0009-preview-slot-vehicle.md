# 0009: Draw the build through a shipped preview vehicle

Date: 2026-11-07

## Context

ADR 0008's build view hid the scene's vehicle and drew the body and each
chosen part as separate scene models. Three in-game runs on 2026-11-06 and
2026-11-07 showed that it can't match the game's own drawing:

- The scene paints a vehicle shader (`Texture0`, paint mask, paint color,
  damage) only in `VehicleDrawer`, when it draws a whole vehicle. A plain scene
  model (`ModelDrawer`) binds one texture, so a body drawn that way came out
  black. A plain-shader copy fixed the color but lost the vehicle shader.
- KI5 doors, hood and tailgate are bone-rigged parts of the body mesh
  (`static = FALSE`, `boneWeight = door_fl_bone 1.0`). `ModelDrawer` only builds
  bone matrices for sprite-model animations, so these drew nothing and the cab
  stood open.

Max: "It looks great when you press 'Show every part model'", which is the
scene drawing a real vehicle script.

What the scene can do, from the 42.21 bytecode:

- It draws a vehicle script looked up by name (`setVehicleScript` →
  `ScriptManager.getVehicle`). Each call resets its cached model data.
- It builds that data once, from every part model whose `file` loads; a
  model whose file doesn't load is skipped.
- For every model entry of a part it draws the part's first loaded model at
  that entry's offset, rotation and scale (`VehicleRenderData.initPartModel`
  uses `getModelInfoForPart(partId)`). That is why the plain view shows only
  each slot's first bumper. The model script's scale and `invertX` come from
  the entry's own `file`, not from the model being drawn.
- The body texture is the script's first skin, or the body model's own
  texture when the script has no skins.

What Lua can do:

- No public method registers a new vehicle script. `getClassFieldVal` and
  the other reflection helpers throw outside debug mode.
- On a vehicle script it already has, it can call `copyPartsFrom(other,
  "*")`, `copyWheelsFrom(other, "*")` (both replace parts and wheels by id with
  copies whose model lists are new) and `Load(name, text)`. Load merges `part`
  and `model` blocks into existing ones by id and only sets the keys given.
- It can register model scripts (`ModelScript.new`, `setModule`,
  `InitLoadPP`, `Load`, `ScriptManager:addModelScript`).
- Nothing in normal play spawns a vehicle script by enumeration: zones list
  scripts by name, and only the debug "Set Script" menu lists them all.

## Decision

The mod ships `media/scripts/vehicles/CSV_PreviewVehicle.txt`, a vehicle with a
vanilla placeholder body and no skins. It is in no zone and the picker leaves it
out. For each preview (`VehiclePreview.lua`, `preview-slot.lua`,
`body-model.lua`) the mod rebuilds it:

1. It copies the chosen vehicle's final parts and wheels with `copyPartsFrom`
   and `copyWheelsFrom`. These are already scaled, so `Loaded()` is never run
   again.
2. It registers, once per vehicle and paint, a copy of the body's model
   script with the chosen skin as its texture and everything else kept: the
   vehicle shader, mesh, scale, attachments and bone weights.
3. It loads an override:
   - the body model (the copy, plus the original's scale, offset and rotate);
   - the vehicle's `texture*` keys (mask, rust, lights, damage);
   - every unchosen model of a part the build manages, and every model of a
     part left over from an earlier vehicle, pointed at a missing file. A hidden
     entry in a part that still shows a model instead takes that model's file,
     offset, rotation, scale and attachments, so its repeat draw is identical
     and lands exactly on it. (The fifth in-game run pointed those entries at
     the missing file too; the scene then read no model-script scale for them,
     and the Trooper Offroad Pack's front spare tire drew about ten times too
     big.)
4. It calls `setVehicleScript` on the slot, but only when the vehicle, paint or
   choices changed.

The scene then draws the slot like any vehicle. The plain view (Show every part
model) draws the chosen vehicle itself. The preview falls back to the plain view
when the slot can't be built: no paint or `textureMask` in the script text
(vanilla cars, whose paints come from templates), or a script error. It also
falls back when the scene fails 90 frames in a row (ADR 0008's watchdog).

## Consequences

- The game's lists of all vehicle scripts include one extra vehicle,
  `Base.CSV_PreviewVehicle`, holding whatever was last previewed. It never
  spawns unless someone picks it from the debug menu.
- The game keeps the body copies (`CSV_PreviewBody_<vehicle>_<paint>`) until
  it restarts.
- A part with several wanted models draws its first model at each one's
  place, the same as the plain view.

## How to reverse

Delete the scripts file, `preview-slot.lua`, `body-model.lua` and the slot
filter in `runtime.lua`, and have `CSV_VehiclePreview:applyBuild` always call
`showPlain`. The view then shows every part model as the game draws it.
ADR 0008's composed view is in git history once this is committed.
