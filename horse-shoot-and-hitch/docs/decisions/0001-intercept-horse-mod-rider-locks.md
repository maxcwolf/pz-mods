# 0001: Intercept the Horse mod's rider locks instead of fighting them

Date: 2026-11-06

## Context

Every tick the Horse mod (v1.1.2) calls, from Lua, `setBannedAttacking(true)`
(`client/HorseMod/player/MountedAttack.lua`), `setIgnoreAimingInput(true)` and
`setTargetAndCurrentDirection(horse heading)` (`shared/HorseMod/Mounts.lua`,
`MountedDirection.lua`) on every rider. Ranged attacks fire along the
character's forward direction (`CombatManager` reads `getForwardDirection`).
These are local functions we can't reach, and running our own handler later
in the frame races theirs.

## Decision

Wrap those three methods in `__classmetatables[IsoPlayer.class].__index`, the
technique several of Max's installed B42 mods use. For a local rider holding an
aimed firearm (not jumping, mounting or dismounting) we keep aim input on,
unban attacking only while aiming (so a plain click doesn't shove), and right
after their facing pin we set the forward direction toward the mouse and the
animation player's target direction for torso twist. Java-side calls are
unaffected; only the Horse mod's Lua calls are intercepted. Equipping weapons
in the saddle is allowed through the Horse mod's own `RidingAPI.addValidTimedAction`.

## How to reverse

Delete `client/HorseShootAndHitch/mounted-shooting.lua` (or set the
"Shooting from the saddle" sandbox option off). The wrappers pass every call
through unchanged when the rider isn't an armed, mounted local player.
