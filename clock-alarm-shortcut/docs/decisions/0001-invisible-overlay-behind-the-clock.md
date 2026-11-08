# 0001: Catch right-clicks with an invisible overlay at the back of the UI

Date: 2026-11-07

## Context

The HUD clock is `zombie.ui.Clock`, a Java UI element with no Lua table. Its
`onMouseDown` toggles the alarm, and its right-click handler does nothing and
does not consume the click. Lua can't add a handler to it.

`UIManager` hit-tests UI elements from the top of its list down and stops at
the first one that consumes a click. A right-click nothing consumes fires
`OnRightMouseDown` and goes on to the world, where it can open the world
context menu.

## Decision

Add a Lua `ISUIElement` that draws nothing and is sized and placed over the
bell every frame. The bell's rectangle is computed from the clock's spacing
constants and the size of its textures. The overlay returns false for left
button and mouse move events so they reach the clock, and consumes right
button down and up only when the player has a digital alarm to set. It opens
the dialog on release.

The overlay calls `backMost()`, so it is hit-tested after every other element,
including the clock and any window dragged over it.

Rejected: listening to `Events.OnRightMouseDown` and testing the click against
the clock's bounds. It doesn't consume the click, so the world context menu
would still open on release.

## How to reverse

Delete `bell-overlay.lua` (or remove its `Events.OnGameStart.Add` line). To
make the overlay win over windows instead, drop the `overlay:backMost()` call
in `Overlay.install`.
