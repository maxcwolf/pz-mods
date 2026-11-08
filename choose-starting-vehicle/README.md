# Choose Starting Vehicle (Project Zomboid, Build 42)

Pick the vehicle that will be parked near your spawn point, right on the
character creation screen. A **Starting Vehicle** button next to Random opens a
window laid out like the in-game mechanics screen: the vehicle on the left as a
3D view you can turn and zoom (or the mechanics diagram), its parts in two
category lists, and the selected part's choices below. You choose:

- **The vehicle**: any vehicle installed, filtered by KI5 vehicles, the game's
  own vehicles or other mods' vehicles. Wrecks and burnt shells are left out.
- **Paint**: the vehicle's factory paints by name (the '89 Defender 110 has
  eleven, from Arizona Tan to Tamar Blue). Game vehicles also get a color
  choice, because most vanilla cars are tinted rather than skinned.
- **Parts**: click a part in a list or on the diagram. KI5 add-ons (bumpers,
  bullbars, snorkels, window armor, roof racks, spare tires, mudflaps...) can be
  set to any item the slot accepts or to None. Tires, brakes, suspension, gas
  tank, muffler and radio offer their grades. Matching parts (four tires, left
  and right window armor) change together unless you untick "Same for every".
  Leave a part on "Game's choice" to let the game roll it as usual. The 3D view
  shows the chosen paint and parts.
- **Cargo**: select the trunk or glove box part to pack it from a searchable
  list of every item, with quantities.
- **Trailer**: on the Trailer tab, any trailer or camper (KI5 Trailers!, KI5
  Campers!, vanilla trailers), with its own paint, parts and cargo, hitched
  behind the vehicle.
- **Saved vehicles**: save the build under a name, load or delete it later,
  like saved characters. Your last build is remembered between games.

When the new game starts, the mod looks for room near you, roads and parking
lots first, and parks the vehicle there. The condition, fuel, battery and key
location are sandbox options. By default the vehicle is like new, with a full
tank, a charged battery and the key in your pocket.

Works with spawn-location mods such as Spawn Selector [B42 Stable] and Spawn
Anywhere [B42]. If the character is moved far away after the game starts, the
vehicle (with trailer, cargo and key) is parked again near the new spot once
they stop and the area loads. This stops once you get in the car, after 3
moves, or after 10 minutes.

Single player only for now.

## How it works with KI5 vehicles

The mod needs no per-vehicle setup. For each vehicle you pick, it has the game
build a scratch copy that never enters the world and reads the final part list
from it, templates and all. The diagram uses the mechanics overlay art each KI5
vehicle registers, and the 3D view uses the vehicle's own models. KI5's shared library
(damnlib) normally rolls random add-ons the first time a KI5 vehicle loads. The
mod installs your choices right after spawning, marks every slot as already
decided so damnlib never re-rolls it, and checks again a few seconds later.

## Sandbox options (page "Choose Starting Vehicle")

| Option | Default |
| --- | --- |
| Spawn the chosen vehicle | on |
| Part condition, percent | 100 (no rust) |
| Fuel, percent of tank | 100 |
| Battery charge, percent | 100 |
| Key in your pocket (off: glove box) | on |
| Parking search radius (tiles) | 30 |
| Allow a trailer | on |
| Allow cargo | on |

## Install

```bash
scripts/install.sh
```

That symlinks `mod/ChooseStartingVehicle` into `~/Zomboid/mods/`. Enable
"Choose Starting Vehicle" in the Mods menu and start a new character. Edits to
the Lua files take effect after restarting the game. Builds are saved in
`~/Zomboid/Lua/ChooseStartingVehicle_builds.txt`.

## Tests

```bash
luajit test/run.lua
```

The pure modules are unit-tested. The spawn code and the whole window (pick a
vehicle, choose parts, paint, cargo, trailer, save and load) run against small
fakes of the game objects and UI widgets. `test/ki5-scripts_test.lua` also parses the real KI5 and
vanilla vehicle scripts installed on this Mac and checks the results (the '89
Defender's bumpers, armor, tires, paints, and that every KI5 vehicle resolves).
It is skipped on machines without them.

## Layout

```
mod/ChooseStartingVehicle/42/
  mod.info, media/sandbox-options.txt
  media/scripts/vehicles/CSV_PreviewVehicle.txt  the never-spawned vehicle the 3D view draws
  media/lua/shared/ChooseStartingVehicle/   pure, unit-tested logic (no game globals)
    script-text.lua    parses PZ script text into blocks and properties (paints)
    vehicle-parts.lua  reads parts from a scratch vehicle, paints from script text
    part-models.lua    which part model goes with which item, for the 3D view
    preview-plan.lua   which part models the 3D view shows for the choices
    preview-slot.lua   rebuilding the preview vehicle: models to hide, override text
    body-model.lua     the body model copy in the chosen paint
    preview-watch.lua  the 3D view's frame watchdog and zoom fit
    overlay.lua        the mechanics diagram from ISCarMechanicsOverlay's tables
    follow.lua         when a spawn mod moved the player and the car should follow
    catalog.lua        vehicles to list, paint names, part slots, mechanics columns
    build.lua          the build model and the saved-builds text format
    placement.lua      finding room for the vehicle and trailer near the spawn
    plan.lua           build + sandbox settings -> spawn steps, color presets
    settings.lua       sandbox options with defaults
    items.lua          the cargo editor's item list and search
  media/lua/client/ChooseStartingVehicle/   game-facing code
    runtime.lua        reads vehicle scripts from the ScriptManager into catalog entries
    state.lua          current build, saved builds, the spawn-on-next-game flag
    apply.lua          spawns, installs parts, condition, fuel, keys, cargo, hitch
    spawn.lua          OnNewGame hook, waits for the area, follows teleports
    hooks.lua          the button on the character creation screen
    VehicleWindow.lua  the Starting Vehicle window (mechanics layout)
    PartList.lua       its two category part lists
    VehiclePreview.lua the 3D view
    MechanicsDiagram.lua the top-down mechanics diagram
    CargoDialog.lua    the cargo editor
test/harness/          fakes of the game and UI, and the offline script resolver
docs/decisions/        why it works the way it does (ADRs)
todo.md                what still needs checking in game
known-issues.md        problems found and not fixed
```
