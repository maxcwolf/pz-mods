# Choose Starting Gear (Project Zomboid, Build 42)

Pick your starting gear on the normal character creation screen, right under
the clothing choices:

- **Bags**: one chooser per body location that any wearable container uses
  (Back, fanny packs, and whatever satchel or rig locations your mods add).
- **Hands**: what you hold in your primary and secondary hand.
- **Attached items**: one item per hotbar attachment slot your clothing
  provides. The Back slot is always there; a belt adds Belt Left and Belt
  Right, a holster adds its slot, and modded clothing such as a weapon sling
  adds whatever slots the mod registers. Only items that fit a slot are listed.
- **Bag contents**: for every bag you wear (backpack, satchel, fanny packs, or
  anything a mod lets you wear), an "Edit contents..." button opens a dialog
  where you filter the whole item list by category and name, add any quantity,
  and adjust or remove stacks, with a running weight against the bag's capacity.
- **Preview**: attached items show on the rotating character preview.
- **Firearm attachments**: for every firearm you chose (in a hand, a slot or a
  bag), one dropdown per attachment type that has parts fitting it: scope,
  barrel (light, laser, choke), sling, recoil pad, plus any part types mods
  add. The parts go on every copy of that firearm, fitted the same way the
  vanilla upgrade action fits them.
- **Loaded ammo**: a tick box (on by default) makes every firearm and magazine
  you chose start fully loaded, including a round in the chamber.
- **Saved builds**: the gear is saved, loaded and deleted together with the
  vanilla "Save build" presets, so a named build brings its gear back with it.

The mod reads the same tables the in-game hotbar uses, so it works with other
mods' slots and items without any per-mod configuration. Your last selection
is remembered between games.

The mod also fixes a vanilla bug in the saved-builds file: the game split each
saved line on every colon, so a build wearing modded clothing whose body
location is namespaced (for example `alicesweaponsling:slingback` from Alice's
Weapon Sling) lost everything after that item when loaded. With the mod on,
builds load in full.

## Install

```bash
scripts/install.sh
```

That symlinks `mod/ChooseStartingGear` into `~/Zomboid/mods/`. Enable
"Choose Starting Gear" in the Mods menu and start a new character. Edits to
the Lua files take effect after restarting the game.

## Layout

```
mod/ChooseStartingGear/42/
  mod.info
  media/lua/shared/ChooseStartingGear/   pure, unit-tested logic (no game globals)
    slot-logic.lua   which slots exist and what fits them (mirrors ISHotbar)
    catalog.lua      item list building, search, de-duplication
    selection.lua    the chosen gear, its options and its text serialization
    plan.lua         selection + spawn-time facts -> operations and skips
    builds.lua       vanilla saved-builds parsing and the per-build gear file
  media/lua/client/ChooseStartingGear/   game-facing code
    runtime.lua      reads SurvivorDesc / IsoPlayer / script items into tables
    state.lua        current selection, incremental item catalog, save/load, per-build gear
    apply.lua        fills bags, attaches to hotbar slots, equips hands, loads ammo
    spawn.lua        OnNewGame / OnCreatePlayer hooks
    GearPanel.lua    the UI section added to the character creation screen
    BagContentsDialog.lua  the bag contents window (category + search + quantity)
    preview.lua      renders chosen gear on the character preview
    hooks.lua        patches CharacterCreationMain and CharacterCreationAvatar
  media/lua/shared/Translate/EN/UI.json
test/                luajit unit tests for the shared modules
```

## Tests

```bash
luajit test/run.lua
```

Install LuaJIT with `brew install luajit`.

## How it works

1. When the clothing screen lays itself out, the mod appends a panel below the
   clothing rows. It reads the worn items off the `SurvivorDesc` being edited,
   asks `ISHotbarAttachDefinition` which attachment slots those items provide
   (exactly like `ISHotbar:refresh`), and lists the worn containers.
2. Script items do not expose their attachment type, so the mod instances every
   non-hidden item once, a few hundred per frame, to build a catalog. The panel
   shows a progress line until that finishes.
3. The vanilla preview renders the `SurvivorDesc`, which only knows clothing.
   When gear is chosen the mod renders a hidden `IsoPlayer` instead, kept in
   sync with the desc's look and worn items plus the chosen attachments.
4. Pressing Play saves the selection to `~/Zomboid/Lua/ChooseStartingGear_last.txt`,
   remembers what the character wore on the screen (the screen's desc is gone
   by the time the player exists) and arms the spawn hook. On `OnNewGame` the
   plan is built against the real player: anything worn on the screen that the
   game did not put on the player is put on first, items are added, bags are
   filled, firearms and magazines are loaded when the tick box is on, and
   hotbar attachments are made through the player's `ISHotbar` so the icons
   and models match normal play. Anything that no longer fits is skipped and
   logged to the console with a reason, then retried once two seconds later.
5. Gear saved with a vanilla build lives in
   `~/Zomboid/Lua/ChooseStartingGear_builds.txt`, one `build<TAB>name` header
   per build followed by that build's selection lines.
