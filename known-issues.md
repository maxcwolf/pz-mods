# Known issues

- Not yet verified in the game itself. The shared logic is unit-tested and all
  Lua passes a syntax check, but the UI and spawn code have only been checked
  against the vanilla 42.20.4 Lua and class method names, not run.
- Multiplayer: starting gear is applied from `OnCreatePlayer` on a client when
  the character has zero hours survived. Untested; item sync on a server may
  need `sendAddItemToContainer`-style calls.
- Hand items are limited to weapons. Holding a bag or a flashlight at spawn is
  not offered.
- The catalog instances every item once per game session, which takes a few
  seconds on a big mod list. The panel shows progress while it runs.
- Items are never checked against profession or trait restrictions, and bag
  weight over capacity is shown in red but not blocked.
