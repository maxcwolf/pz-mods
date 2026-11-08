# 0002: Catalog window by default, bottom strip as an option

Date: 2026-11-07

## Context

The design canvas (https://claude.ai/artifact/VgdkP2BF1Y6xus91H3DQ8T)
showed three options: A, a catalog window with room tabs, filters, search
and a picture grid that shrinks to a chip while placing; B, an
eight-item strip along the bottom of the screen; C, right-click menus only.
Max (2026-11-07): "build A as the default and also have the option to
switch to B."

## Decision

Both layouts are views over one controller (`controller.lua`), so they
share the browse state, the mouse modes and the undo list. The layout is a
combo box under Options > Mods (Furnish by Room > Layout), and each layout
has a button that switches to the other and saves the choice. Switching
while placing keeps placing. C survives as the right-click entry "Furnish
this kitchen...", which opens the chosen layout on the clicked room.

## How to reverse

To drop the strip, remove `ItemStrip.lua`, its `registerView` call in
`main.lua`, the Layout combo box in `options.lua` and the window's
"Bottom strip" button. To make the strip the default, mark its combo item
selected in `Options.setup` and swap `Layout.fromIndex`'s fallback.
