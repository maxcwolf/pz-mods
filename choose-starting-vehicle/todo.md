# To do

Nothing here has run in game yet. Everything is checked against the 42.21
jar's bytecode, vanilla Lua, damnlib 42.20, the installed KI5 scripts and
stubbed tests (`luajit test/run.lua`).

## Seen in game (2026-11-06)

- Parts show and spawning works: a '89 Defender 130 build spawned with
  "0 part choices failed", and the re-apply pass ran.
- Spawn Selector: the car followed the teleport once (12425,3724 to
  12304,6937).
- The 3D build view crashed the scene every frame and hid the rest of the
  window until the diagram was chosen. Fixed with a warm-up and a watchdog
  (ADR 0008).
- Second run: the window stayed visible, but the view fell back to "every part
  model" (the roof rack showed with None chosen). The watchdog gave up on the
  first failed frame, while models were still loading. It now waits for clean
  frames and tolerates short bursts. Also: zoom was too tight and the window too
  narrow. The window is now wider and opaque, and the zoom fits each vehicle;
  the zoom fit is a guess calibrated from one screenshot (`PIXELS_AT_12` in
  `preview-watch.lua`).

## Seen in game (2026-11-07)

- Third run: the build view started (no fallback, 25 short model-loading
  errors), but after a split second the body drew black and inside out (the
  Trooper and Defender 130 showed their interiors through black walls). Cause:
  the body was drawn as a plain scene model with the vehicle's own shader, and
  the scene only feeds a vehicle shader its paint color and mask when it draws a
  whole vehicle, so the paint came out as zero (black). It was also not mirrored
  and not scaled by the vehicle's model scale, as the scene does for a vehicle
  body. A plain-shader copy fixed the color (fourth run, painted green) but the
  doors, hood and tailgate were missing: they are bone-rigged parts of the body
  mesh, which a plain scene model can't draw. Max: the plain view ("Show every
  part model") looks great. So the build view now rebuilds a shipped,
  never-spawned vehicle (`CSV_PreviewVehicle`) from the chosen one with only the
  chosen models, and the scene draws it like the plain view (ADR 0009).
- Fifth run (preview slot): "MUCH BETTER"; Roofrack None removes the roof
  rack. The Trooper Offroad Pack's front spare tire drew huge: its unchosen
  second model pointed at the missing file, and the scene reads each model
  entry's script scale (0.098) from that entry's own file. Fixed: such entries
  now take the shown model's file as well (ADR 0009).
- Spawning after Spawn Selector (2026-11-07): the log shows the Defender 130
  spawned at 10609,15110, then followed the move to 12305,6934 ("0 part choices
  failed"). Max couldn't find it. His saved position later was 12274,6965,
  about 30 tiles southwest of the car, and the save's vehicles.db can't confirm
  the car while the game runs. Not yet known whether it was there.

## First in-game run

- [ ] Enable the mod and open character creation. Confirm
  `~/Zomboid/console.txt` has no stack trace mentioning ChooseStartingVehicle.
- [ ] The "Starting Vehicle" button sits left of Random and doesn't overlap
  it at your resolution. After you pick a vehicle it reads "Vehicle: <name>".
- [ ] The sandbox page "Choose Starting Vehicle" shows eight options with
  labels and tooltips.

## The window

- [ ] The vehicle list fills, with KI5 vehicles tagged [KI5] and the Show
  filter working. Note how long it takes to open the first time and to switch
  vehicles (each new vehicle builds a scratch copy once).
- [ ] **Parts now show** (the empty-parts bug): picking the '89 Defender 110
  lists its parts by category, and Front Bumper, Snorkel, window armor, Roofrack,
  Tires, Brakes, Suspension, Gas Tank, Muffler and Radio offer choices. If a
  vehicle shows no parts, console.txt has "could not read the parts of ...".
- [ ] The layout fits at your resolution: nothing overlaps; the two lists
  scroll; the detail area's Install combo opens over the window.
- [ ] Untick "Same for every Tire" and give one tire a different grade; the
  rows show it.
- [ ] Diagram: the KI5 overlay art appears and lines up; parts tint green when
  chosen, amber on game's choice, blinking red on None; clicking a part selects
  it. A vehicle without overlay art says so.
- [ ] 3D view sixth run: the Trooper Offroad Pack's front spare tire is
  normal size for both tire choices; a bull bar on any KI5 car is normal size
  with no copy beside it.
- [ ] 3D view fifth run (preview slot, ADR 0009), Trooper then Defender 130:
  the build view looks like the plain view (doors, hood, paint, reflections)
  but with Roofrack None the roof rack is gone and a chosen bull bar replaces the
  bumper, with no ghost copy beside it. Changing Paint repaints the whole body,
  doors included. Switching vehicles leaves no parts from the previous one.
  console.txt has no "3D preview: showing every part model for" line for KI5
  vehicles; if it does, send it. Also check the debug vehicle list doesn't
  break, and that no `CSV_PreviewVehicle` ever shows up in the world.
- [ ] Find the starting car after a Spawn Selector move: the console line
  "moved the starting vehicle from ... to X,Y" gives where it went; check it
  is next to where you arrived. If it isn't, note where you arrived.
- [ ] 3D view fourth run (Trooper, then Defender 130): after the split second
  of the plain view, the body stays painted (green for the Trooper's first
  paint), solid, the right size and the right way round. The spare tire and
  other one-sided parts sit on the same side as in the plain view: if they swap
  sides, the mirror in `BodyModel.objectScale` is backwards. If the body is
  black or missing, console.txt says "3D preview: no body model for ..." or a
  shader error; send that. Changing Paint repaints it. Roofrack None still
  removes it, and the whole vehicle still fits on open.
- [ ] 3D view third run: no orange "Showing every part model" note; setting
  the Trooper's Roofrack to None removes it from the 3D view; the whole vehicle
  fits in the view on open. If the note appears, console.txt says "the scene kept
  failing to draw ..." with the Java errors before it. (2026-11-07: no note;
  the body drew black, fixed above.)
- [ ] 3D view after the crash fix: the whole window stays visible with the 3D
  view on; console.txt has no "IndexOutOfBoundsException" from
  `UI3DScene$VehicleRenderData.initVehicleModel`. If it says "the scene failed
  to draw the build", the watchdog dropped to the plain view; send that log.
- [ ] 3D view: the vehicle shows, drag turns it, the wheel zooms, Reset view
  works. Check that the body sits on the frame (not offset, upside down or
  doubled in size) and is painted in the chosen paint; changing paint repaints it.
  Check that only the chosen bumper or bull bar shows and that None removes it.
  If parts float away from the body, or the body is the wrong size, the body
  offset or scale in `CSV_VehiclePreview:makeBody` is off. It copies what the
  scene's own vehicle drawing does (42.21 bytecode): translation =
  `getModelOffset()`, rotation = the model's rotate, scale = the vehicle's model
  scale mirrored on X, and the model script's own scale in the copy. If the build view looks wrong or
  console.txt has "3D preview: ... failed", note it; "Show every part model"
  shows the game's plain view.
- [ ] A vanilla car (Chevalier Nyala) shows a Color combo, the plain 3D view
  (its paints come from templates), and the vanilla diagram.
- [ ] Trunk, glove box and trailer storage parts show "Cargo: N items" with
  Edit...; the cargo editor opens, searches, adds, and the counts update.
- [ ] Trailer tab: pick a trailer, choose its parts and cargo, pick No
  trailer, switch back to Vehicle.
- [ ] Save a build as "Test", restart the game, load it and confirm every
  choice comes back. Delete it.
- [ ] The sandbox labels for condition, fuel and battery now show (the "(%)"
  that broke the translator is gone).

## Spawning

- [ ] New game with a KI5 build (bullbar, no snorkel, armor on, Military
  tires): the vehicle is parked a few tiles away on a road if there is one, and
  console.txt has a "[ChooseStartingVehicle] spawned ..." line with
  "0 part choices failed".
- [ ] The mechanics screen shows exactly the chosen parts, the models match
  (bullbar visible, snorkel gone), condition 100, full tank, charged battery.
- [ ] Save, quit, reload: the add-ons are unchanged (damnlib didn't re-roll),
  especially the slots set to None.
- [ ] Key: in your inventory by default; with the sandbox option off, in the
  glove box. The key starts the vehicle.
- [ ] Trunk and glove box hold the chosen items. On a KI5 car the trunk
  items should land in the KI5 trunk storage (DEF89Trunk), not the roof rack;
  if not, adjust `Plan.pickTrunk`.
- [ ] Paint matches the chosen skin; on a vanilla car the tint matches the
  color.
- [ ] With a trailer (KI5 cargo small, a KI5 camper, vanilla Trailer): it
  spawns behind, turned the same way as the car, hitched (the tow menu offers
  Detach), and doesn't jump or flip when the constraint grabs it. If console
  says "the hitches did not line up", `canAttachTrailer` rejected the spot:
  check whether `getWorldPos` returns world tile coordinates as assumed in
  `CSV_Apply.trailerTile`, and whether the half-tile rounding is too coarse
  (ADR 0005).
- [ ] Split-screen co-op character creation has no Starting Vehicle button
  (on purpose; its Play button bypasses the hook).
- [ ] Spawning inside a building in a dense town still finds a spot. With
  no room, the console says "no free spot" and nothing breaks.
- [ ] The car isn't placed across a fence or a wall edge (`CSV_Apply.isClear`
  rejects tiles with collideN/collideW).

## Later

- [ ] Multiplayer: the server would need to spawn from the client's build
  (sendClientCommand + server-side apply).
- [ ] Spawn Selector [B42 Stable] (3772052709) and Spawn Anywhere [B42]
  (3392491434): before-load spawn, in-game Spawn Here after browsing the map,
  indoor or upstairs spots, a spot near water or the map edge. Check the old
  car is gone (also after walking back), the trailer is hitched at the new spot,
  and only one key is in your pocket (ADR 0007).
- [ ] Consider a FollowTeleport sandbox option (on by default) to turn the
  follow-the-player behavior off.
- [ ] Show the chosen trailer behind the car in the 3D view.
- [ ] Mark the starting car on the world map (a map symbol) so it is easy to
  find after a spawn-mod move.
