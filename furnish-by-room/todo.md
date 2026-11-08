# To do

## Check in game (single player)

Grep `~/Zomboid/console.txt` for `[FurnishByRoom]` and `STACK TRACE`.

### Opening

- [ ] F7 in a house's kitchen opens the catalog window on Kitchen and says
      "You're standing in a kitchen". The console prints
      `catalog: N tiles read in M ms`; note M (the first open scans every
      tile sheet; if it hitches badly, scan at game start instead).
- [ ] Every room tab shows a sensible count, and its cards show pictures.
      Note any card whose picture is blank or tiny.
- [ ] Right-click inside a bedroom: *Furnish this bedroom...* opens on
      Bedroom. Outside: *Furnish by Room...*.
- [ ] Options > Mods > Furnish by Room shows the key, Layout and Ignore
      placement rules, and changing the key works after closing Options.

### Placing (catalog window)

- [ ] Clicking a fridge hides the window and shows the chip; the preview
      follows the mouse, green-ish where it fits, red on a wall or counter.
- [ ] Click places a working fridge (power on: it cools); its container is
      empty. Keep clicking places more; the chip count goes up.
- [ ] With no hammer or screwdriver in the inventory, a counter, a wall
      cabinet (Floating counter), a wardrobe, a side table and an oven all
      preview green on open floor and place. (Fixed after the first
      in-game run, where every storage piece stayed red.) The game's own
      admin movables cheat stays off afterwards.
- [ ] R rotates through the facings. Wall cabinets (Floating counters),
      wall lamps and paintings only fit against a wall.
- [ ] A double bed and a couch preview and place both tiles; the player
      can sleep in the bed.
- [ ] A TV and a stove placed this way work (TV turns on, stove cooks).
- [ ] Esc ends placing without opening the game menu, and the window comes
      back. Right-click ends it too.
- [ ] Clicking furniture in the world while placing does not pick it up.

### Floors, remove, undo

- [ ] Picking White Tiles and hovering a kitchen previews the whole room;
      click paints it. Press and drag paints a rectangle.
- [ ] Upstairs, painting a room paints only that level.
- [ ] Remove, then click one end of a bed: the whole bed goes.
- [ ] Ctrl+Z undoes placing, painting and removing in reverse order, and
      does nothing while the mod is closed.

### Bottom strip

- [ ] The window's *Bottom strip* button swaps to the strip, and it is
      still the strip after restarting the game.
- [ ] Room buttons, the category button, the arrows and the mouse wheel
      work; clicking a card while placing switches pieces.
- [ ] The strip fits on the screen at your resolution and does not cover
      the hotbar.
- [ ] Esc ends placing first, then closes the strip.

## Ideas

- More rooms (bathroom, office, kids' room, patio) and wallpaper or paint
  once Max decides (docs/decisions/0006).
- Show multi-tile pieces whole on their cards.
- A "recently placed" row.
