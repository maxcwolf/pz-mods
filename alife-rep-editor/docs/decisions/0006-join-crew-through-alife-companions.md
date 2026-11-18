# 0006: Join my crew goes through A-Life's own companion recruit

Date: 2026-11-17

## Context

Players want to bring anyone on the People tab into their crew without the
conversation and reputation checks. A-Life already has crews: an NPC with
`memory.companion = { owner = playerKey, ... }` follows and fights for that
player, and `Companions.recruit(player, uid, opts)` and `Companions.dismiss`
set and clear it.

## Decision

- Join my crew calls `Companions.recruit` with `{ open = true }`, the same flag
  A-Life's visitor "Stay and join me" option uses. It skips the companion
  candidate and reputation (hire gate) checks but keeps everything else: the
  five-per-player limit, someone else's companion stays theirs, the body must be
  loaded, the 2.5x health boost, and clearing the owner's grudge.
- If the NPC is loaded but beyond A-Life's recruit reach (4 tiles), we first
  call A-Life's `Companions.bringNear`, the move its admin spawn uses, then
  recruit. We don't write our own teleport.
- After joining, a safehouse visitor is detached with `VisitorJoin.detach` and a
  captive released with `Captives.release(uid, "joined")`, as A-Life's own Join
  options do.
- Leave my crew calls `Companions.dismiss`, which keeps the companion's state in
  `companionKept` so a later rejoin restores it.
- Crew members are listed on the People tab even without an opinion row.

## How to reverse

- To keep A-Life's reputation and candidate checks: in `People.joinCrew`, call
  `recruit(player, uid)` without `{ open = true }`.
- To stop pulling people over: in `People.joinCrew`, drop the `bringNear` call;
  people out of reach are then refused as too far away.
- To remove the feature: delete `personJoinCrew` and `personLeaveCrew` in
  `hooks.lua` and the crew button in `PeopleView.lua`.
