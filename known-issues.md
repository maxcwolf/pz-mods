# Known issues

- First in-game run (2026-10-25) surfaced two bugs, both fixed: the game's
  Lua has no `next()`, and probing Java methods inside pcall still logs errors.
  The bag dialog and the gear preview have not been run in the game yet.
- The gear preview switches the avatar from desc rendering to a live
  `IsoSurvivor`; if that throws, the mod logs once and falls back to the
  vanilla preview for the rest of the session.
- Multiplayer: starting gear is applied from `OnCreatePlayer` on a client when
  the character has zero hours survived. Untested; item sync on a server may
  need `sendAddItemToContainer`-style calls.
- Hand items are limited to weapons. Holding a bag or a flashlight at spawn is
  not offered.
- Never call a Java method just to see whether it exists: Project Zomboid
  prints a stack trace for every error even when pcall catches it.
- The catalog instances every item once per game session, which takes a few
  seconds on a big mod list. The panel shows progress while it runs.
- Items are never checked against profession or trait restrictions, and bag
  weight over capacity is shown in red but not blocked.
