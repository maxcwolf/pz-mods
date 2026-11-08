# 0003: Place furniture with the game's own furniture code and rules

Date: 2026-11-07

## Context

A placed fridge has to be a working fridge, a stove a stove, a TV a TV,
and a bed has to cover both its tiles. The game's debug tile brush already
places any tile through `ISMoveableSpriteProps:placeMoveableInternal`,
which picks the right object class from the tile's properties.

## Decision

Placing runs `placeMoveableInternal` for every tile of the piece (the grid
from `sprite:getSpriteGrid()`), with a plank as the stand-in item the way
the brush does. The cursor is a subclass of the game's build cursor
(`ISBuildingObject`), so clicking, the ghost preview, right-click to stop
and the Rotate Building key (R) work as in vanilla; no walking, no tools,
no timed action.

Whether a piece fits uses the game's own moving-furniture rule
(`canPlaceMoveableInternal`, plus its wall-between-parts check for
multi-tile pieces), so counters, wall cabinets and table-top items behave
as when moving furniture by hand. That rule also asks for the piece's
place tool and skill (a hammer and carpentry for counters, cabinets and
wardrobes; an Electrician tool for ovens) unless the game's movables cheat
is on. Max found every storage piece stuck red in game (2026-11-07), so
`Place.fits` turns `ISMoveableDefinitions.cheat` on just for the check and
puts it back afterwards: the square is checked, the player is not. An
"Ignore placement rules" tick box
(off by default) drops that rule and only needs a floor, no car and not
the same piece already there.

## How to reverse

To always ignore the rules, make `Controller.anywhere()` return true. To
place through the game's full pick-up/place flow instead, give the player
a `Moveables.<sprite>` item and hand off to `ISMoveableCursor`.
