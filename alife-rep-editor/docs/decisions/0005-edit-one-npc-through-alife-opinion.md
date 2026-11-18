# 0005: Edit one NPC through A-Life's own opinion record

Date: 2026-11-17

## Context

Players want to change how one NPC feels about them, not only their overall
score or a whole faction. A-Life already keeps that per NPC: an opinion row in
`memory.opinion[playerKey]` (`v` from -100 to 100, `at`, `why`, `w`), plus
per-player flags `hostileToPlayerKeys` and `carefulPlayerKeys`.

## Decision

- The People tab edits those existing fields rather than adding our own layer.
  Writes go through `NpcOpinion.write` and `NpcOpinion.store`, so A-Life's
  eight-players-per-NPC limit and its drift back toward the baseline still apply.
- A set opinion is not pinned. It drifts back a few points a day like any other,
  because pinning would mean fighting A-Life on every tick.
- A change writes a short in-world reason ("They've warmed to you." or "They've
  soured on you.") with weight 0, so the next real event's reason replaces it.
- Calm down clears only this player's `hostileToPlayerKeys` and
  `carefulPlayerKeys` entries. It doesn't touch `hostileOverride`, which A-Life's
  admin tools own and which applies to every player.
- The list shows only living NPCs with an opinion row for you, capped at 200,
  plus whoever you right-clicked. Every listed person's stance is computed, so
  picking a row needs no round trip.

## How to reverse

- To pin opinions: keep `{ uid, value }` in the editor's ModData and re-apply it
  from an `EveryOneMinute` handler.
- To leave A-Life's reason alone: in `People.setValue`, stop setting `why` and `w`.
- To list every living NPC: in `People.list`, drop the opinion-row check.
