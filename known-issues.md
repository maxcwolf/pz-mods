# Known issues

- First in-game run (2026-10-25) surfaced two bugs, both fixed: the game's
  Lua has no `next()`, and probing Java methods inside pcall still logs errors.
  Second run: attachments worked in game; the preview failed because
  `IsoSurvivor` has no `getHumanVisual` (fixed by rebuilding the preview
  character from the desc), and bags could not be chosen on the screen (fixed
  by the new Bags section). The Bags section, the bag dialog and the preview
  have not been run in the game yet.
- Bags chosen in the Bags section are worn through the desc like clothing.
  Whether the game puts them on the spawned player exactly like vanilla
  clothing is still to be confirmed in a real spawn.
- The gear preview switches the avatar from desc rendering to a live
  `IsoSurvivor`; if that throws, the mod logs once and falls back to the
  vanilla preview for the rest of the session.
- Third run: the preview equipped hand items on the preview character, which
  fires the game's equip events; the vanilla fishing handler then failed on a
  character that has no world, and because the vanilla screen re-renders the
  preview on every mouse move the error repeated until the game stalled. The
  preview no longer equips hand items and rebuilds the character only when
  the look, clothing or gear actually changed.
- Hand items are not shown on the preview (see above); they are still given
  at spawn.
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
