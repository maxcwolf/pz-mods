# To do

## Check in game (single player)

Run 1 (2026-11-07): sandbox page and the "active:" line worked, but every
sweep and loot-window refresh threw "tried to call nil" because
`IsoCell.getVehicles()` is a `java.util.Set` (no `get(i)`). Fixed by walking it
with `iterator()`; the fake game now models it as a Set. Typing a percent
also logged "less than min=10" per keystroke; the minimum is now 1.

- [ ] No `[VehicleStorageCapacity]` stack traces in console.txt.
- [ ] The Defender 130 at 300 logs `Base.89defender130: DEF89Trunk130 130 -> 390`
      (its trunk is a flat 130 with no condition penalty) and the loot window
      shows 390, or 507 with the Organized trait.

- [ ] The sandbox page "Vehicle Storage Capacity" shows four options with
      labels and tooltips when creating a game.
- [ ] Console shows `[VehicleStorageCapacity] active: trunks ..., seats ...`
      at game start and `resized N containers on M vehicles` as cars load.
- [ ] A vanilla car's trunk, glove box and seats show the scaled capacity in
      the loot window as soon as you walk up (no one-minute wait).
- [ ] A KI5 vehicle (for example the '93 F-Series or '86 CUCV) scales its
      trunk, side storage and roof rack; KI5 camper cabinets use the trailer
      percent and camper beds the seat percent.
- [ ] Uninstall and reinstall a trunk lid in the mechanics screen: capacity
      returns to the scaled value, not double-scaled.
- [ ] Sit in a seat: it still shows a quarter while occupied (vanilla rule),
      and the full scaled value once you get out.
- [ ] Save, quit and reload: capacities stay scaled once.
- [ ] Items can actually be stored past the vanilla limit (transfers are not
      refused).
- [ ] Changing a percent mid-save (sandbox editor or a fresh load with a
      different value) rescales from the original, and 100 restores it.

## Multiplayer (not tested)

- [ ] Confirm the dedicated server's `getCell():getVehicles()` lists loaded
      vehicles; if not, the server never resizes and may refuse transfers
      past the vanilla limit. A fallback would be resizing on
      `OnClientCommand` vehicle actions.
- [ ] Confirm the client and server agree on capacity after a part install.
