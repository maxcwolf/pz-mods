# Known issues

- The game caps every vehicle container at 1000. Percentages that would go
  past it stop at 1000; nothing in Lua can lift that limit.
- An occupied seat is resized only after it is free again, because the game
  reports a quarter of an occupied seat's capacity and the real value cannot
  be read from Lua (Java field access was removed in 42.15).
- A vehicle loaded far from the player is resized by the once-a-minute
  sweep, so for up to a game minute (about 2.5 real seconds at default
  speed) it can show the vanilla capacity. The loot window refresh covers
  vehicles within 6 tiles, so this should not be visible in practice.
- Burnt or wrecked vehicle scripts with no engine count as trailers. They
  normally have little or no storage.
- An uninstalled part item (a trunk lid in your inventory) keeps its own
  unscaled capacity stat; it is scaled again once installed. This is on
  purpose, so the value never compounds.
