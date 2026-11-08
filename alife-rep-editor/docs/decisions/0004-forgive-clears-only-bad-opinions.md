# 0004: Forgive clears only below-baseline opinions

Date: 2026-11-06

## Context

Each A-Life NPC keeps an opinion of you (-100 to 100) next to its faction's
attitude. Forgiving a faction should end grudges, not erase the goodwill from
helping its people.

## Decision

Forgive resets the faction's recorded attitude to its usual one, removes only
the opinion rows that sit below what that NPC would think of you with no
memories (A-Life's own `NpcOpinion.baseline`), and clears the
`hostileToPlayerKeys` flag on the faction's NPCs.

## How to reverse

In `Editor.clearGrudges`, drop the baseline comparison to wipe every opinion row.
