# 0001: Scale each part's live capacity, not the scripts

Date: 2026-11-07

## Context

Read from the 42.21 jar:

- A vehicle part's capacity lives in its `ItemContainer.capacity`, which is
  saved with the vehicle. `VehiclePart.doInventoryItemStats` recomputes it
  when a part item is installed or removed: from the item's max capacity
  (condition-scaled when the script's container sets
  `conditionAffectsCapacity`), or from the vehicle script's container
  `capacity` when nothing is installed. Condition changes do not recompute
  it, except vanilla's `TrailerTrunk` (`max(80, condition)`).
- An item's `maxCapacity` is copied from its script when the item is made
  and saved per item. Vanilla `createPartInventoryItem` also overwrites a
  freshly spawned part item's max capacity with the part's capacity when it
  is above 0 (this is how KI5 `damnCraft.Trunk` lids get 120 and so on).
- `VehicleScript$Container.capacity` and the script item's `capacity` are
  Java fields with no getters, and Java field access from Lua was removed in
  42.15, so script values cannot be read or edited.
- `ItemContainer.getCapacity` returns a quarter for an occupied seat and
  caps vehicle containers at 1000.

Editing item scripts with `DoParam` would only reach items made later, never
seat or glove box script capacities, and would compound on every Lua reload
because the original could not be remembered outside Lua.

## Decision

Leave scripts and items alone. For each storage part, take the capacity the
game computed and set `part:setContainerCapacity(base * percent / 100)`,
rounded, at least 1 and at most 1000. The part's mod data remembers the
base, the applied value and the installed item's id. When the part still
shows the applied value with the same item, the remembered base is reused,
so repeat passes and percent changes never compound. Any other value means
the game recomputed, and it becomes the new base.

Two cases are left alone: occupied seats (the shown value is quartered) and
parts whose installable item is missing, because vanilla copies that empty
slot's capacity into the next spawned part item and scaling it would then
compound.

## How to reverse

Set every percent to 100: each part with a record is restored to its
remembered base and the record is cleared. Removing the mod keeps whatever
capacity was last set until the game recomputes a part; set 100 and load
the save once first to restore every loaded vehicle.
