# Vehicle Storage Capacity

A Project Zomboid Build 42 mod that adds a **Vehicle Storage Capacity** page
to the sandbox settings. Each kind of vehicle storage gets its own
percentage of the game's normal capacity:

| Option | Covers | Default |
| --- | --- | --- |
| Trunks and cargo | trunks, truck beds, van cargo areas, roof racks, side boxes, toolboxes, gun racks, under-seat cubbies | 100 |
| Seats | every seat, plus camper beds and stretchers | 100 |
| Glove boxes and consoles | glove boxes and center consoles | 100 |
| Trailers and campers | trailer beds, cargo boxes, camper cabinets and floors | 100 |

Each option runs from 1 to 1000. 100 is the game's own value, 200 doubles
it. The game never lets one vehicle container hold more than 1000, so very
high percentages on big cargo areas stop there. Fuel tanks, tires and other
fluid containers are not touched.

## Compatibility

There is no per-mod list. The mod reads the capacity the game itself works
out for each part of each loaded vehicle and scales it, so vanilla
vehicles, every KI5 vehicle (including KI5 trailers and campers), and other
vehicle mods work the same way. A trailer is any vehicle whose script name
contains "Trailer" or that has no engine.

Existing saves work too: vehicles already in the world are resized the next
time they load. Setting a category back to 100 restores the original
capacity.

Condition still matters the way it does in the base game: a damaged trunk
installed at 50 condition holds less, and that smaller value is what gets
scaled.

## How it works

See [docs/decisions](docs/decisions). In short: every in-game minute, when a
player gets into a vehicle, and right before the loot window lists nearby
containers, the mod checks each storage part. It remembers the game's value
and the value it set in the part's mod data, so it never scales twice, and it
notices when the game recomputes a part (a trunk installed or removed).

## Development

- `luajit test/run.lua` runs the tests. `test/harness/fake-game.lua` copies
  the engine behavior the mod depends on, and `test/real-scripts_test.lua`
  classifies every storage part in your installed game and Workshop scripts.
- `scripts/install.sh` symlinks the mod into `~/Zomboid/mods`.
- In game, grep `~/Zomboid/console.txt` for `[VehicleStorageCapacity]`.

Open checks are in [todo.md](todo.md); known problems in
[known-issues.md](known-issues.md).
