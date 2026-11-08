--- Decides when the starting vehicle should follow the player to a new spot,
--- for spawn-location mods (Spawn Selector and the like) that move the
--- character after the game has started. Pure: the client feeds it one sample
--- per tick ({x, y, z, t, inOurVehicle, inVehicle, dead, carX, carY, loaded})
--- and acts on the returned action: "wait", "respawn" or "stop".
local Follow = {}

Follow.DEFAULTS = {
    jumpTiles = 40,
    settleTiles = 2,
    settleMs = 2000,
    nearTiles = 40,
    carTolerance = 3,
    windowMs = 10 * 60 * 1000,
    maxGapMs = 1000,
    maxFollows = 3,
    loadTimeoutMs = 30000,
    probeCap = 40,
}

--- Returns the option table with every missing value taken from DEFAULTS.
function Follow.options(opts)
    local out = {}
    for key, value in pairs(Follow.DEFAULTS) do
        out[key] = value
    end
    for key, value in pairs(opts or {}) do
        out[key] = value
    end
    return out
end

--- Returns the straight-line distance in tiles between two points.
function Follow.distance(ax, ay, bx, by)
    local dx, dy = (bx or 0) - (ax or 0), (by or 0) - (ay or 0)
    return math.sqrt(dx * dx + dy * dy)
end

--- True when a sample is more than `tiles` away from a point or on another floor.
function Follow.movedFrom(point, sample, tiles)
    if math.floor(point.z or 0) ~= math.floor(sample.z or 0) then
        return true
    end
    return Follow.distance(point.x, point.y, sample.x, sample.y) > tiles
end

--- Returns the time in ms between two samples that counts toward the watch
--- window: gaps longer than `maxGapMs` (a paused or frozen game) count as that.
function Follow.activeGap(previousT, t, maxGapMs)
    if not previousT or not t or t < previousT then
        return 0
    end
    return math.min(t - previousT, maxGapMs)
end

--- Creates a watch for a car parked at (carX, carY); `opts` overrides DEFAULTS.
function Follow.new(opts, carX, carY)
    return {
        opts = Follow.options(opts),
        phase = "watching",
        car = { x = carX, y = carY },
        last = nil,
        settle = nil,
        loadSince = nil,
        activeMs = 0,
        follows = 0,
        reason = nil,
    }
end

--- Ends the watch for good with a reason for the console.
local function stop(state, reason)
    state.phase = "stopped"
    state.reason = reason
    return "stop"
end

--- True while the client should report whether the new area is loaded.
function Follow.isLoading(state)
    return state.phase == "loading"
end

--- Watching: a jump bigger than any walk in one tick starts the settle timer.
local function watching(state, sample, last)
    local o = state.opts
    if state.follows >= o.maxFollows then
        return stop(state, "max-follows")
    end
    if state.activeMs > o.windowMs then
        return stop(state, "window")
    end
    if last and not sample.inVehicle and Follow.movedFrom(last, sample, o.jumpTiles) then
        state.phase = "settling"
        state.settle = { x = sample.x, y = sample.y, z = sample.z, t = sample.t }
    end
    return "wait"
end

--- Settling: once the player stays put for settleMs, follow if they ended up
--- far from the car, else go back to watching.
local function settling(state, sample)
    local o = state.opts
    local s = state.settle
    if Follow.movedFrom(s, sample, o.settleTiles) then
        state.settle = { x = sample.x, y = sample.y, z = sample.z, t = sample.t }
        return "wait"
    end
    if sample.t - s.t < o.settleMs then
        return "wait"
    end
    state.settle = nil
    if Follow.distance(state.car.x, state.car.y, sample.x, sample.y) <= o.nearTiles then
        state.phase = "watching"
        return "wait"
    end
    state.phase = "loading"
    state.loadSince = sample.t
    return "wait"
end

--- Loading: respawn once the area around the player is loaded, or give up.
local function loading(state, sample)
    if sample.loaded then
        state.phase = "spawning"
        return "respawn"
    end
    if sample.t - state.loadSince > state.opts.loadTimeoutMs then
        return stop(state, "load-timeout")
    end
    return "wait"
end

--- Advances the watch by one sample and returns "wait", "respawn" or "stop".
function Follow.step(state, sample)
    if state.phase == "stopped" then
        return "stop"
    end
    if state.phase == "spawning" then
        return "wait"
    end
    if sample.dead then
        return stop(state, "dead")
    end
    if sample.inOurVehicle then
        return stop(state, "in-vehicle")
    end
    if sample.carX and Follow.distance(state.car.x, state.car.y, sample.carX, sample.carY) > state.opts.carTolerance then
        return stop(state, "car-moved")
    end
    local last = state.last
    state.activeMs = state.activeMs + Follow.activeGap(last and last.t, sample.t, state.opts.maxGapMs)
    state.last = { x = sample.x, y = sample.y, z = sample.z, t = sample.t }
    if state.phase == "watching" then
        return watching(state, sample, last)
    elseif state.phase == "settling" then
        return settling(state, sample)
    end
    return loading(state, sample)
end

--- Records the result of a respawn: on success the car is at (carX, carY) and
--- watching resumes until maxFollows; on failure the watch stops.
function Follow.done(state, ok, carX, carY)
    if not ok then
        return stop(state, "spawn-failed")
    end
    state.follows = state.follows + 1
    state.car = { x = carX, y = carY }
    state.last = nil
    state.loadSince = nil
    if state.follows >= state.opts.maxFollows then
        return stop(state, "max-follows")
    end
    state.phase = "watching"
    return "wait"
end

--- Lists the tiles to probe for "loaded": the center and eight points on a
--- square ring at `radius` tiles, capped at `cap` so the ring stays inside the
--- area the game keeps loaded around the player.
function Follow.probePoints(x, y, radius, cap)
    local r = math.max(0, math.min(math.floor(radius or 0), cap or radius or 0))
    local points = { { x, y } }
    if r == 0 then
        return points
    end
    for _, d in ipairs({ { -1, -1 }, { 0, -1 }, { 1, -1 }, { -1, 0 }, { 1, 0 }, { -1, 1 }, { 0, 1 }, { 1, 1 } }) do
        points[#points + 1] = { x + d[1] * r, y + d[2] * r }
    end
    return points
end

--- True when `isLoaded(x, y)` holds for every point.
function Follow.allLoaded(points, isLoaded)
    for _, p in ipairs(points) do
        if not isLoaded(p[1], p[2]) then
            return false
        end
    end
    return true
end

--- True when more than `limitMs` has passed since `since`.
function Follow.timedOut(since, now, limitMs)
    return now - since > limitMs
end

return Follow
