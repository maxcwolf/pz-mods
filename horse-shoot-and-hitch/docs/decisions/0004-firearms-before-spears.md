# 0004: Ship firearms first, spears later

Date: 2026-11-06

## Context

Neither the Horse mod nor vanilla has a mounted melee animation, so a spear
thrust from the saddle would play the standing animation and clip into the
horse. Max chose to ship firearms and tying first.

## Decision

Only aimed firearms (`HandWeapon:isAimedFirearm()`) lift the attack lock.
Melee stays banned while mounted, as in the Horse mod. Firearms may have the
same clipping problem in the aim and shoot poses; that is the first thing to
check in game (`todo.md`).

## How to reverse

To add spears: allow spear-type weapons in `MountedAim.shouldUnlock` and add a
`HorseRiding`-conditioned melee animation node set for the rider.
