# Known issues

- Some installed KI5 vehicles reference templates that no file the game
  loads defines: `BR89SpareTiresPD` ('89 Bronco Ranger), `F1502SpareTires`,
  `F1502Roofrack`, `F3502Roofrack` ('93 Ford F-Series), `SUB87Gunrack` ('87
  Suburban OP; the template exists only in the mod's old B41 `media` folder),
  `KI5CRStabilizerB16` (Flying Cloud and Bambi campers) and
  `DAMN79camaroGhost`. The game skips them too, so those vehicles just have no
  row for those parts. `ki5-scripts_test.lua` lists them as known.
- Vanilla cars' paints come through `template!` blocks this mod doesn't read
  for skin names, so they show as "Paint 1", "Paint 2"... For the same reason
  the 3D view can't paint their body and shows the game's plain vehicle view.
- Vanilla cars show the plain 3D view (every part model, first paint): their
  paints and paint mask come from `template!` blocks this mod doesn't read, and
  the build view needs both (ADR 0009).
- The game's full vehicle script list (debug "Set Script" menu, other mods
  that list every vehicle) includes `CSV_PreviewVehicle`, the never-spawned
  vehicle the 3D view draws (ADR 0009).
- The 3D view guesses which part model goes with which item from the order
  of the script's models (right for 97% of installed KI5 slots; KI5's real table
  is in server Lua, which isn't loaded at the menu). Some '69 Charger, '73
  Falcon and '82 Jeep J10 tires and bumpers show a sibling's model. The spawned
  vehicle itself is right.
- "Game's choice" shows the slot's first item in the 3D view; in game damnlib
  may roll a different one or leave it empty.
- The window predicts which container gets the trunk items from the empty
  vehicle's capacities; KI5 storage that only appears with an add-on may
  change that at spawn.
- The trailer is placed on the nearest whole tile, so the hitches can start up
  to half a tile apart. If `canAttachTrailer` then says no, the trailer is
  left unhitched behind the car and you hitch it with the tow menu (ADR 0005).
- No button on the split-screen co-op character creation screen.
- Single player only: in multiplayer nothing spawns.
- Following a teleport isn't saved: quitting and loading before the spawn mod
  moves you leaves the car at the original spawn.
- A teleport of 40 tiles or less, or one where the player keeps moving for the
  whole 10-minute window, isn't followed.
- Items put in the old car before a teleport are lost when it's respawned.
- If the new area doesn't load within 30 seconds, the car stays at the
  original spawn.
