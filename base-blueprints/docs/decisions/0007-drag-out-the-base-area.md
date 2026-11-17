# 0007: Drag out the base area

Date: 2026-11-17

## Context

Max asked to drag the area his base covers and what gets saved, instead of
only claiming a whole building plus a fixed margin. Bases are often part of
a building, a building plus a particular stretch of yard, or no building at
all.

## Decision

*Drag out your base area* (right-click menu, or *Drag area* in the window,
which hides while dragging) puts up a drag cursor built like the game's own
rectangle tool (`ISBuildingRoomsEditor_ToolAddRect`): an `ISBuildingObject`
subclass set with `getCell():setDrag`, which highlights the square under the
mouse, then the rectangle from the pressed square to the mouse, and claims it
on release. Right-click or Esc cancels, as for any build cursor. The class is
made on first use because `ISBuildingObject` is in server Lua, which loads
after client Lua.

The footprint is what was dragged (at most 12,000 tiles; the highlight turns
red past that). Levels are chosen automatically: from the lowest to the
highest level of any building the rectangle touches, always including the
player's level, plus one level above for roofs and anything built up there.

Dragging again while a base is claimed redraws it: squares in both the old
and new areas keep their first recording, so changes already made stay
highlighted and are still saved; squares new to the area are recorded as
they are at that moment. The claim no longer needs a building; the building
claim options now go through the same `Runtime.claimArea`.

The saved blueprint covers only the claim, so the dragged area is also the
limit of what is saved.

## How to reverse

Remove the drag options from `menu.lua` and the window's *Drag area*
button; claiming a building still works the same way.
