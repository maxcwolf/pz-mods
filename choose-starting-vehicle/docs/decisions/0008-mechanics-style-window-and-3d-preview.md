# 0008: A mechanics-style window with a 3D preview

The composed 3D build view below is superseded by ADR 0009 (a shipped
preview vehicle drawn by the scene itself). The window layout and the
watchdog still stand.

Date: 2026-11-06

## Context

Max asked for the window to look like the in-game mechanics window and to
show the actual vehicle while choosing. The mechanics window (`ISVehicleMechanics`)
needs a real vehicle in the world and a character, so it can't be reused at
character creation. It draws a top-down diagram from `ISCarMechanicsOverlay`,
which vanilla fills and every KI5 vehicle extends through
`DAMN.MechOverlay:addParts` in client Lua. That Lua loads at the main menu, so
the diagram art is available.

The game's 3D scene (`UI3DScene`, used by the debug attachment editor) can show
a vehicle script. Its `SceneVehicle` draws the body in the first paint and every
model of every part at once, with no command to hide one, so a KI5 bumper slot
would show all of its bumpers stacked. The same scene can:

- create plain models (`createModel`);
- pin a model to a vehicle part (`setObjectParentToVehiclePart`, as the
  attachment editor does);
- texture a model through a `SpriteModel` (`setModelSpriteModel`). The texture
  path is the same `media/textures/<name>.png` form a skin's texture uses.

KI5 keeps its item-to-model tables in server Lua, which isn't loaded at the menu.
Its scripts list one model per item in item order. Checked against those tables
for every installed KI5 vehicle, that order is right for 97% of slots.

## Decision

`VehicleWindow.lua` mirrors the mechanics layout:

- On the left (40% of the window), the vehicle: a 3D view
  (`VehiclePreview.lua`), zoomed to fit each vehicle's length, or the mechanics
  diagram (`MechanicsDiagram.lua`).
- At the top right, the vehicle chooser, name, kind and paint.
- Below that, two part lists by category, with doors, bodywork and lights on
  the right as in vanilla (`PartList.lua`).
- Under the lists, the selected part's detail: what to install, "same for
  every tire", and the cargo editor for the trunk, glove box or trailer
  storage.
- Vehicle and Trailer tabs switch what is being edited.

Every displayed part gets a row. Parts with nothing to choose say so.

By default the 3D view hides the scene's vehicle and uses it only as a frame:

- the body is its own model, painted with the chosen skin;
- each part shows only the model for its chosen item (`part-models.lua`,
  `preview-plan.lua`). The game's choice shows the first item.

"Show every part model" switches to the plain scene vehicle. So does any
scene command failing, which is logged once.

Two guards were added after the first in-game run (2026-11-06), where the build
view threw on the render thread every frame and hid the rest of the window:

- The scene only builds a vehicle's model data (`SceneVehicle.modelInfo`)
  the first time it draws that vehicle, and it loads models in the background.
  While one isn't ready, drawing throws (`skinTransforms` or `boneMap` is null);
  that stops by itself after a few frames. Models pinned to a vehicle that was
  never drawn crash `VehicleRenderData.initVehicleModel` every frame. So each
  new vehicle is drawn plain until 10 frames in a row draw cleanly
  (`preview-watch.lua`), then the build view replaces it.
- A Java error while the scene draws aborts every UI element after it, and Lua
  can't catch it. A marker element drawn right after the scene tells
  `preview-watch.lua` whether each frame got through. After 90 failed frames in a
  row (about 1.5 seconds) the preview drops to the plain vehicle. Shorter bursts
  while new part models load are ridden out. A second in-game run showed that a
  single failed frame was too strict.
  Part models are only created when their model script exists, and only
  pinned once the scene reports the object exists.

A third in-game run (2026-11-07) showed the body black and inside out. The
scene draws a plain model (`ModelDrawer`) by binding one texture as
`Texture` and nothing else. Vehicle shaders (vanilla `vehicle`, damnlib
`damn_vehicle_shader`) sample `Texture0`, a mask and a paint color, which only
the scene's vehicle drawing (`VehicleDrawer`) sets; with the paint color left at
zero the body comes out black. The scene's vehicle drawing also scales the body
by the vehicle script's model scale and mirrors it on X unless the model script
sets `invertX`; a plain model gets neither. So `body-model.lua` and
`CSV_VehiclePreview:makeBody`:

- register, once per vehicle per session, a copy of the body's model script
  (`CSV_PreviewBody_<vehicle>`, in the original's module) with the same mesh,
  `static` flag and scale (read from the script text the game keeps), the
  plain `basicEffect` shader and the skin texture. Lua builds it with
  `ModelScript.new()`, `setModule`, `InitLoadPP`, `Load` and
  `ScriptManager:addModelScript`. Nothing in the game uses these names.
- set the body object's scale to the vehicle's model scale, negative on X
  unless `invertX`, and its rotation to the model's rotate.

The cost: the plain shader has no paint tint, rust, damage or reflections (see
known-issues.md).

## How to reverse

To drop the body copy, have `makeBody` create the model from
`script:getModel():getFile()` again and remove `body-model.lua`; the body will
draw black. To drop the composed view, have `CSV_VehiclePreview:show` always call
`setObjectVisible("vehicle", true)` and skip `makeBody` and `syncParts`. To
drop the 3D view entirely, remove `VehiclePreview.lua` and its two buttons; the
diagram works on its own. The old one-row-per-slot window is in git history
once this is committed.
