# 0001: Wrap four A-Life functions to make kills undoable

Date: 2026-11-06

## Context

A-Life's `Lifecycle` fans a player's NPC kill out to `RepTrack.onActorKilled`,
`Reputation.onPlayerKilledActor`, `PersonalRep.onActorKilled` and
`NpcOpinion.noteKill`, in that order, through module tables it looks up at call
time. Hits before the kill go through `Reputation.escalate` (which turns the
faction hostile on the first hit) and `NpcOpinion.note("hit")`. None of these
leave a record of what they changed.

## Decision

Wrap `RepTrack.onActorKilled` (snapshot before the kill), `PersonalRep.onActorKilled`
(capture the class and score change), `NpcOpinion.noteKill` (finish and record
the kill) and `Reputation.escalate` (snapshot the faction attitude and nearby
NPC opinions at the start of a fight). Undo restores those snapshots and
subtracts the score change, so later reputation is kept. Every wrapper calls the
original first or last and passes its return values through; editor errors are
caught so they can't break A-Life.

## How to reverse

Delete `server/ALifeRepEditor/hooks.lua`'s `Hooks.install()` call. The window's
adjust, set level and forgive buttons still work without it; only Recent kills
goes empty.
