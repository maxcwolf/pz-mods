# 0005: How the trailer is placed and hitched

Date: 2026-11-06

## Context

No vanilla code spawns a vehicle with a trailer already attached; the tow menu
only joins two vehicles that are already close. Cars carry a rear `trailer`
attachment (negative z) and a front `trailerfront` one. KI5 and vanilla
trailers name their tongue `trailer` (positive z); the KI5 livestock trailer
also has `trailerfront`. Vanilla's tow menu tries `trailer` with `trailer`
first, then `trailer` with `trailerfront`.

## Decision

`placement.lua` treats the car and trailer as two rectangles on one axis. The
trailer's center sits `carHitch - trailerHitch` behind the car's center (the
attachments' z plus the model offset, the same sum
`BaseVehicle:getAttachmentLocalPos` uses), rounded to a whole tile away from
the car. The search tries N, E, S and W at every tile nearest-first, road and
parking tiles before plain ground. Footprints get a full tile of padding
because `addVehicleDebug` turns each vehicle by a random amount of up to about
11 degrees.

The trailer's tile is then taken from the car's real pose
(`car:getWorldPos(0, 0, offset)`), and the trailer is turned to the car's
angles with `setAngles`. If `canAttachTrailer(trailer, "trailer", hitch)`
agrees, `addPointConstraint(player, trailer, "trailer", hitch)` hitches them,
where hitch is the trailer's "trailer" attachment, else "trailerfront". If
not, the trailer stays parked behind, unhitched, and the console says so.

## How to reverse

Change `CSV_Apply.trailerHitchId` to prefer `trailerfront`, or drop the
`addPointConstraint` call to always leave the trailer unhitched.
