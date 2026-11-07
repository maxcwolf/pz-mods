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
- Fourth run (2026-11-03): the preview was disabled at once because
  `IsoSurvivor` has no visual at all (`getVisual` throws "subclasses must
  implement this"), so it can never be rendered as a live character. The
  preview now creates one hidden `IsoPlayer` from a throwaway desc (the
  player constructor empties the desc it is given) and syncs look, worn items
  and attachments onto it. Its constructor fires `OnCreateLivingCharacter`
  and registers nothing globally; still unverified in the game.
- Same run: at spawn, modded clothing and one bag chosen on the screen were
  not on the player (slings, sheaths, a modded fanny pack), so their gear was
  skipped. The spawn code now puts on anything the desc wore that the player
  is missing, logs both lists, and retries skipped gear two seconds later.
  Root cause of the missing clothing is still unknown.
- Fifth run (2026-11-05, log read 2026-11-06): no stack traces. Modded
  clothing was still skipped at spawn because `MainScreen.instance.desc` is
  already nil when `OnNewGame` fires, so the "put on what the desc wore" step
  never ran. Pressing Play now snapshots the worn item types and spawn uses
  that list. Unverified in the game.
- Vanilla's saved builds (the "Save build" presets) lost clothing when the
  mod's modded locations were in play: `readSavedOutfitFile` splits each line
  on every colon and modded body locations such as `alicesweaponsling:slingback`
  contain one, so everything from that item on was dropped. The mod now
  replaces that reader with one that splits at the first colon. Builds saved
  before the fix are intact on disk and load correctly once the mod is on.
- Sixth run (2026-11-06): the bag buttons were invisible but clickable. The
  panel called `instantiate()` after `addChild`, which had already created
  the Java object, so each button got a second, unattached object that drew
  nowhere. The Clear button and the divider line had the same fault. Fixed by
  building widgets in vanilla's order; a test now checks every panel widget.
- Firearm attachments are chosen per firearm type, so every copy of a firearm
  gets the same parts. Parts are not drawn on the character preview, and
  their weight is not counted in the bag weight shown on the panel.
- Which parts fit comes from each part's `MountOn` list (empty means any
  firearm). A part whose own Lua `canAttach` callback refuses the gun is
  still listed, then skipped at spawn with a console line.
- Loaded ammo uses `setCurrentAmmoCount`, `setContainsClip` and
  `setRoundChambered`; whether every modded firearm honors those flags (some
  mods track magazines differently) is unverified.
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
