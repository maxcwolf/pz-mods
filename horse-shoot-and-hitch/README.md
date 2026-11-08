# Horse Mod: Mounted Shooting and Hitching

A Project Zomboid Build 42 add-on for the [Horse mod](https://steamcommunity.com/sharedfiles/filedetails/?id=3661336777)
(mod id `Horse`, v1.1.2). Mod id: `HorseShootAndHitch`.

## What it does

**Shooting from the saddle.** Equip a gun while mounted (equipping is now
allowed in the saddle), hold the aim button and click to fire. The shot goes
toward the mouse, anywhere around you by default. Accuracy drops with the
horse's gait:

| Gait     | Hit chance penalty (points) |
| -------- | --------------------------- |
| Standing | 0                           |
| Walk     | 2                           |
| Trot     | 5                           |
| Gallop   | 20                          |

Melee weapons, spears included, still can't attack from the saddle (see
`todo.md`).

**Tying up.** Right-click a fence, pole, railing, lamp post, sign post or tree:

- While riding next to it: **Dismount and tie to …**
- On foot, with a loose horse within 4 tiles of it: **Tie <horse> to …**

A horse wearing reins is tied with them for free; otherwise you need a Rope,
which you get back when you untie. A tied horse stays within 2 tiles of the post.
To untie, use vanilla's **Detach animal from …** on the horse, or just mount
it. Mounting unties it automatically.

## Sandbox options

Under **Horse Shooting and Hitching**: shooting on/off, the three penalties,
the shooting arc (degrees either side of the horse's heading; 180 means all
round, 90 the front half) and the tied horse range in tiles.

## Development

- Tests: `luajit test/run.lua` (pure modules plus stubbed game glue).
- Install for testing: `scripts/install.sh` symlinks `mod/HorseShootAndHitch`
  into `~/Zomboid/mods`.
- Check `~/Zomboid/console.txt` for lines tagged `[HorseShootAndHitch]` and for
  stack traces.
- Decisions live in `docs/decisions`; open issues in `todo.md`.

## How it works

- `shared/.../mounted-aim.lua`, `tether.lua`, `settings.lua`: pure rules, unit tested.
- `client/.../mounted-shooting.lua`: wraps three `IsoPlayer` methods the
  Horse mod calls on riders every tick (`setBannedAttacking`,
  `setIgnoreAimingInput`, `setTargetAndCurrentDirection`). This lifts the locks
  for a local rider holding a firearm and points the rider's forward direction,
  which the game fires along, at the mouse.
- `shared/.../tether-world.lua`: stores the tie in the horse's mod data, sets
  vanilla's attached tree (rope drawing, wander anchor, Detach option), re-links
  it after a reload and walks the horse back inside the radius. It runs on the
  server (or in single player) as a Horse mod `HorseManager` system.
- `shared/.../tie-horse-action.lua`, `client/.../tie-menu.lua`: the timed action
  and the right-click menu.
