--- Pure rules for shooting from the saddle: when the rider may aim, which way
--- the shot goes and how much the horse's gait costs in hit chance. No Project
--- Zomboid globals are used here so the module can be unit-tested outside the game.
local MountedAim = {}

MountedAim.STAND = "stand"
MountedAim.WALK = "walk"
MountedAim.TROT = "trot"
MountedAim.GALLOP = "gallop"

--- Default hit chance penalties in percentage points, very forgiving below a gallop.
MountedAim.DEFAULT_PENALTIES = { stand = 0, walk = 2, trot = 5, gallop = 20 }

--- Default half-width of the arc the rider can shoot into, in degrees (180 is all round).
MountedAim.DEFAULT_ARC = 180

--- Picks the horse's gait from its animation flags.
function MountedAim.gaitFrom(flags)
    if flags.gallop then return MountedAim.GALLOP end
    if flags.trot then return MountedAim.TROT end
    if flags.moving then return MountedAim.WALK end
    return MountedAim.STAND
end

--- Returns the hit chance penalty for a gait, falling back to the defaults.
function MountedAim.penaltyFor(gait, penalties)
    local value = penalties and penalties[gait]
    if value == nil then value = MountedAim.DEFAULT_PENALTIES[gait] end
    return value or 0
end

--- Lowers a weapon's hit chance by a penalty without going below zero.
function MountedAim.reducedHitChance(base, penalty)
    local reduced = (base or 0) - (penalty or 0)
    if reduced < 0 then return 0 end
    return reduced
end

--- Tells whether the rider's aiming and attacking locks should be lifted this tick.
function MountedAim.shouldUnlock(state)
    if not state.enabled then return false end
    if not state.mounted then return false end
    if not state.firearm then return false end
    if state.jumping or state.mounting or state.dismounting then return false end
    return true
end

--- Wraps an angle in radians into the range (-pi, pi].
function MountedAim.wrap(angle)
    local twoPi = 2 * math.pi
    angle = angle % twoPi
    if angle > math.pi then angle = angle - twoPi end
    return angle
end

--- Returns the angle in radians from one world point to another.
function MountedAim.angleTo(fromX, fromY, toX, toY)
    return math.atan2(toY - fromY, toX - fromX)
end

--- Keeps an aim angle within `arcDegrees` either side of the horse's heading.
function MountedAim.clampToArc(heading, aim, arcDegrees)
    local arc = math.rad(arcDegrees or MountedAim.DEFAULT_ARC)
    local offset = MountedAim.wrap(aim - heading)
    if offset > arc then offset = arc end
    if offset < -arc then offset = -arc end
    return MountedAim.wrap(heading + offset)
end

--- Turns an angle in radians into a unit direction vector.
function MountedAim.direction(angle)
    return math.cos(angle), math.sin(angle)
end

return MountedAim
