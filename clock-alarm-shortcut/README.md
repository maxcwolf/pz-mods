# Clock Alarm Shortcut

A Project Zomboid (Build 42.20+) mod. Right-click the alarm bell on the watch
display in the top right corner of the screen to open the **Set Alarm Time**
dialog, without digging the watch out of your inventory.

## What it does

- **Right-click the bell** (the small bell to the right of the time, dim when
  the alarm is off): opens the vanilla Set Alarm Time dialog for your watch or
  alarm clock.
- **Left-click** works as in vanilla: it turns the alarm on or off, or stops
  it ringing.

The dialog is the same one the inventory's "Set Alarm" option opens, so it
behaves the same way: it closes when you walk off, and OK saves the time and
whether the alarm is on.

The alarm it sets is the first digital one found the same way the clock
finds what to show: a watch you wear first, then an alarm clock you hold.
Analog watches have no alarm to set, so right-clicks on their clock do
nothing. Right-clicking the bell twice brings the open dialog forward instead
of opening a second one.

## How it works

The HUD clock is drawn by the game's Java code and ignores right-clicks. The
mod adds an invisible UI element sized and placed exactly over the bell. It
works out the bell's position from the clock's own textures and spacing, for
both the small and large clock size options, and follows the clock every
frame. It passes left-clicks through and sits at the back of the UI, so
windows dragged over the clock still get their own clicks.

## Install

```bash
scripts/install.sh
```

This symlinks the mod into `~/Zomboid/mods`. Enable "Clock Alarm Shortcut" in
the game's mod list. It is client-side only and can be added to an existing
save.

## Tests

```bash
luajit test/run.lua
```

`bell-layout.lua` holds the pure layout math. `alarm-finder.lua` and
`bell-overlay.lua` are the game glue and are tested against stubbed players,
items, textures and the clock.
