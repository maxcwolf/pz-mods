# Project Zomboid mods by jabroni

Build 42 mods for [Project Zomboid](https://projectzomboid.com/). All of them
are single player only. Each folder is one mod with its own README, tests and
install script.

| Mod | What it does | Needs |
| --- | --- | --- |
| [jabroni's Starting Gear](choose-starting-gear) | Choose what's on your belt, holster and back, what's in your bags, your firearm attachments and what's in your hands, on the character creation screen | — |
| [jabroni's Starting Vehicle](choose-starting-vehicle) | Choose, paint, outfit and pack the vehicle waiting at your spawn, and save vehicles by name | — |
| [jabroni's Base Blueprints](base-blueprints) | Claim a building, see every tile you change, save the changes as a blueprint and apply it in a new game | — |
| [jabroni's Room Furnisher](furnish-by-room) | Decorating cheat: place a room type's furniture and floors for free | — |
| [jabroni's Vehicle Storage](vehicle-storage-capacity) | Sandbox percentages for trunk, seat, glove box and trailer capacity on any vehicle | — |
| [jabroni's Face Mask Protection](face-covering-protection) | Cloth face coverings and gas masks with a filter cut corpse sickness by at least 50% | — |
| [jabroni's Alarm Shortcut](clock-alarm-shortcut) | Right-click the alarm bell on the clock display to open Set Alarm Time | — |
| [jabroni's Horse Shooting & Hitching](horse-shoot-and-hitch) | Fire guns from the saddle and tie horses to fences, poles and trees | Horse Mod |
| [jabroni's A-Life Reputation Editor](alife-rep-editor) | Undo NPC kills and set or forgive your Project A-Life reputation | Project A-Life |

Folder names and mod IDs (`ChooseStartingGear`, ...) still use the old names.
Only the names players see changed.

## Layout

Every mod folder follows the same shape:

```
<mod>/
  mod/<ModId>/42/       the mod as the game loads it (mod.info, media/)
  workshop/             Steam Workshop files: workshop.txt, description.bbcode,
                        screenshot.png (taken in game), preview.png (generated)
  test/run.lua          LuaJIT test suite
  scripts/install.sh    symlinks the mod into ~/Zomboid/mods for local play
  docs/decisions/       design records (most mods)
  todo.md, known-issues.md
```

## Development

```bash
brew install luajit
cd <mod> && luajit test/run.lua
<mod>/scripts/install.sh
```

## Steam Workshop

None of these are on the Workshop yet. See
[docs/steam-workshop-plan.md](docs/steam-workshop-plan.md) for the plan and
[docs/decisions](docs/decisions) for the naming and thumbnail choices.

```bash
python3 tools/workshop/cli.py check              # what each mod still needs
python3 tools/workshop/cli.py preview <mod>      # workshop/screenshot.png -> preview.png + poster.png
python3 tools/workshop/cli.py stage <mod>        # copy into ~/Zomboid/Workshop for the uploader
python3 tools/workshop/cli.py collect-id <mod>   # after the first upload, save the Workshop id
python3 -m unittest discover -s tools/workshop/tests -p '*_test.py'
```

The tools need Python 3 with Pillow and macOS's Arial fonts.
