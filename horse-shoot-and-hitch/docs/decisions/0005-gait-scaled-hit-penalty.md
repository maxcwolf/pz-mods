# 0005: Hit chance penalty scaled by gait, very forgiving below a gallop

Date: 2026-11-06

## Context

Vanilla's own moving penalty is 5 points (`CombatConfigKey.MOVING_TO_HIT_PENALTY`),
but a rider never counts as moving to the engine. Max asked for a speed-scaled
penalty that is very forgiving at a walk or trot.

## Decision

Defaults: standing 0, walk 2, trot 5, gallop 20 percentage points, each a
sandbox option. It's applied by lowering the weapon's hit chance in
`OnWeaponSwing` and restoring it on `OnPlayerAttackFinished`, after 3 seconds
as a fallback, and before every save, so the item never keeps the lowered
value.

## How to reverse

Set all three sandbox penalties to 0, or delete the `OnWeaponSwing` handler in
`mounted-shooting.lua`.
