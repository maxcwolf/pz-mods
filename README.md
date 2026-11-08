# Project Zomboid mods by jabroni

Build 42 mods for [Project Zomboid](https://projectzomboid.com/). Each folder
is one mod with its own README, tests and install script.

| Mod | What it does | Needs |
| --- | --- | --- |
| [Choose Starting Gear](choose-starting-gear) | Pick belt, holster, back and bag contents, firearm attachments and what you hold on the character creation screen | — |
| [Choose Starting Vehicle](choose-starting-vehicle) | Pick, paint, outfit and pack the vehicle waiting at your spawn, and save vehicles by name | — |
| [Base Blueprints](base-blueprints) | Claim a building, see every tile you change, save it as a blueprint and apply it in a new game | — |
| [Furnish by Room](furnish-by-room) | Decorating cheat: place a room type's furniture and floors for free | — |
| [Vehicle Storage Capacity](vehicle-storage-capacity) | Sandbox percentages for trunk, seat, glove box and trailer capacity on any vehicle | — |
| [Face Covering Protection](face-covering-protection) | Cloth face coverings and filtered gas masks cut corpse sickness by at least 50% | — |
| [Clock Alarm Shortcut](clock-alarm-shortcut) | Right-click the HUD clock's alarm bell to open Set Alarm Time | — |
| [Horse Mod: Mounted Shooting and Hitching](horse-shoot-and-hitch) | Fire guns from the saddle and tie horses to fences, poles and trees | Horse mod |
| [A-Life Reputation Editor](alife-rep-editor) | Undo NPC kills and set or forgive your Project A-Life reputation | Project A-Life |

## Layout

Every mod folder follows the same shape:

```
<mod>/
  mod/<ModId>/42/       the mod as the game loads it (mod.info, media/)
  test/run.lua          LuaJIT test suite
  scripts/install.sh    symlinks the mod into ~/Zomboid/mods for local play
  docs/decisions/       design records (most mods)
  todo.md, known-issues.md
```

## Steam Workshop

None of these are on the Workshop yet. See
[docs/steam-workshop-plan.md](docs/steam-workshop-plan.md).

## Development

```bash
brew install luajit
cd <mod> && luajit test/run.lua
<mod>/scripts/install.sh
```
