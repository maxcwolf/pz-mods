# To do

- [ ] First in-game run: enable the mod, load a world, and confirm
  `~/Zomboid/console.txt` has `[ClockAlarmShortcut] bell overlay installed`
  with no stack trace. Everything so far is checked against the 42.21 game
  bytecode and stubbed tests, not a running game.
- [ ] Wear a digital watch, right-click the bell, and check the Set Alarm Time
  dialog opens, OK saves the time, and the bell lights up when the alarm is on.
- [ ] Check left-clicking the bell still toggles the alarm (the overlay must
  pass the click through to the clock).
- [ ] Check both clock sizes (Options > Display > clock size) to confirm the
  hit area lines up with the bell. If it is off, compare against
  `BellLayout.SPACING`, which was read from `Clock.assignSmallOffsets` and
  `assignLargeOffsets`.
- [ ] Check that right-clicking the bell no longer opens the world context
  menu behind the dialog.
- [ ] Other UI elements also marked back-most could sit under or over the
  overlay in an order the mod does not control; if one covers the top right
  corner and eats right-clicks, the shortcut will not fire.
- [ ] Split screen is untested. The clock is shared and the mod picks the first
  local player with a digital alarm, which matches what the clock displays.
