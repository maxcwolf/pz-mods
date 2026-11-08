# Face Covering Protection

A Project Zomboid (Build 42.20+) mod. Cloth face coverings, and gas masks and
respirators with a filter fitted, cut the sickness you get from nearby corpses
and zombies by at least 50%.

## What it does

The game gives each clothing item a `CorpseSicknessDefense` percentage. Your
protection is the highest value among the items you wear, and the sickness rate
is multiplied by `1 - defense / 100`. The count behind that rate includes both
dead bodies and zombies standing nearby. Vanilla bandanas, shemaghs, dust masks
and surgical masks have 25.

This mod raises the value to the sandbox minimum (default 50) on two kinds of
face covering.

**Cloth coverings**, always:

- any item that already has some corpse sickness defense, vanilla or modded
  (bandana masks, shemaghs, dust and surgical masks)
- cloth worn in a face slot (`Mask`, `MaskEyes`, `MaskFull`, `FullHat`): items
  with a cotton or denim fabric type, or named balaclava, bandana, shemagh,
  scarf, gaiter or head sack

**Filter masks** (items tagged gas mask, respirator or improvised gas mask),
while a filter is fitted:

- with a charged filter they keep their full vanilla protection (100, or 85
  for the improvised one)
- with a spent filter they give the minimum instead of vanilla's 25
- with no filter at all they keep their own vanilla value

Items that already protect more keep their own value.

Left alone: hard masks with openings (hockey, Halloween, bone, welding), the
old separate "no filter" mask items, full helmets, neck scarves, bandanas worn
on the head, face paint, and modded items in custom slots that are not on the
face (for example gas mask pouches).

## How the filter check works

The game stores the defense on the item type, but whether a mask has a filter
is stored on each individual item. So every game minute, and whenever worn
clothing changes, the mod looks at what the players are wearing: a filter mask
type that someone is wearing with no filter drops back to its own value, and
goes back up once a filter is fitted or the mask comes off.

## Sandbox option

Sandbox settings, page "Face Covering Protection": **Minimum protection (%)**,
0 to 100, default 50. Set it to 0 to leave every item at its original value.

## Install

```bash
scripts/install.sh
```

This symlinks the mod into `~/Zomboid/mods`. Enable "Face Covering Protection"
in the game's mod list. It can be added to an existing save. In multiplayer the
server and every client need it.

## Tests

```bash
luajit test/run.lua
```

`face-covering.lua` holds the pure rules and is tested directly. `patch.lua`
is the game glue and is tested against stubbed script items and players.
