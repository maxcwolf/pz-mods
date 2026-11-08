local Follow = require("ChooseStartingVehicle/follow")

--- Returns a player sample at (x, y) at time t, with extra fields merged in.
local function at(x, y, t, extra)
    local s = { x = x, y = y, z = 0, t = t }
    for k, v in pairs(extra or {}) do
        s[k] = v
    end
    return s
end

--- Feeds samples standing still at (x, y) from t0 to t1 every 100 ms; returns the last action.
local function stand(state, x, y, t0, t1, extra)
    local action
    for t = t0, t1, 100 do
        action = Follow.step(state, at(x, y, t, extra))
    end
    return action
end

--- Teleports a fresh watch from the car at (10, 10) to (500, 500) and lets it settle and load.
local function followed()
    local s = Follow.new(nil, 10, 10)
    Follow.step(s, at(12, 12, 0))
    Follow.step(s, at(500, 500, 100))
    stand(s, 500, 500, 200, 2200)
    return s, Follow.step(s, at(500, 500, 2300, { loaded = true }))
end

test("follow: options fill in defaults and keep overrides", function()
    local o = Follow.options({ jumpTiles = 10 })
    eq(o.jumpTiles, 10, "override")
    eq(o.settleMs, 2000, "default")
end)

test("follow: distance and movedFrom measure tiles and floors", function()
    eq(Follow.distance(0, 0, 3, 4), 5, "3-4-5")
    eq(Follow.movedFrom({ x = 0, y = 0, z = 0 }, { x = 1, y = 1, z = 0 }, 2), false, "close")
    eq(Follow.movedFrom({ x = 0, y = 0, z = 0 }, { x = 3, y = 0, z = 0 }, 2), true, "far")
    eq(Follow.movedFrom({ x = 0, y = 0, z = 0 }, { x = 0, y = 0, z = 1 }, 2), true, "other floor")
end)

test("follow: activeGap caps long gaps and ignores the first sample", function()
    eq(Follow.activeGap(nil, 500, 1000), 0, "first sample")
    eq(Follow.activeGap(100, 116, 1000), 16, "normal tick")
    eq(Follow.activeGap(0, 120000, 1000), 1000, "paused for two minutes counts one second")
    eq(Follow.activeGap(500, 100, 1000), 0, "clock went backwards")
end)

test("follow: walking and running never count as a teleport", function()
    local s = Follow.new(nil, 10, 10)
    local x = 12
    for t = 0, 60000, 16 do
        x = x + 0.2
        eq(Follow.step(s, at(x, 12, t)), "wait", "step at " .. t)
    end
    eq(s.phase, "watching", "still watching")
end)

test("follow: a jump settles for two seconds, then waits for loading and respawns", function()
    local s = Follow.new(nil, 10, 10)
    Follow.step(s, at(12, 12, 0))
    eq(Follow.step(s, at(800, 300, 100)), "wait", "jump")
    eq(s.phase, "settling", "settling after the jump")
    eq(stand(s, 800, 300, 200, 2000), "wait", "not settled before 2 s")
    eq(Follow.isLoading(s), false, "not loading yet")
    eq(Follow.step(s, at(800, 300, 2100)), "wait", "settled")
    ok(Follow.isLoading(s), "now loading")
    eq(Follow.step(s, at(800, 300, 2200, { loaded = false })), "wait", "area not loaded")
    eq(Follow.step(s, at(800, 300, 2300, { loaded = true })), "respawn", "respawn when loaded")
    eq(Follow.step(s, at(800, 300, 2400)), "wait", "waits for done while spawning")
end)

test("follow: small moves while settling restart the settle timer", function()
    local s = Follow.new(nil, 10, 10)
    Follow.step(s, at(12, 12, 0))
    Follow.step(s, at(500, 500, 100))
    stand(s, 500, 500, 200, 1500)
    Follow.step(s, at(505, 500, 1600))
    stand(s, 505, 500, 1700, 3500)
    eq(s.phase, "settling", "timer restarted at 1600")
    stand(s, 505, 500, 3600, 3700)
    eq(s.phase, "loading", "settled 2 s after the last move")
end)

test("follow: a second jump while settling just moves the settle spot", function()
    local s = Follow.new(nil, 10, 10)
    Follow.step(s, at(12, 12, 0))
    Follow.step(s, at(500, 500, 100))
    Follow.step(s, at(2000, 900, 1000))
    eq(s.settle.x, 2000, "settle spot moved")
    stand(s, 2000, 900, 1100, 3100)
    ok(Follow.isLoading(s), "settled at the second spot")
end)

test("follow: settling back near the car means no respawn", function()
    local s = Follow.new(nil, 10, 10)
    Follow.step(s, at(12, 12, 0))
    Follow.step(s, at(500, 500, 100))
    Follow.step(s, at(15, 15, 200))
    stand(s, 15, 15, 300, 2400)
    eq(s.phase, "watching", "back to watching")
end)

test("follow: jumps while in any vehicle are ignored", function()
    local s = Follow.new(nil, 10, 10)
    Follow.step(s, at(12, 12, 0, { inVehicle = true }))
    Follow.step(s, at(100, 12, 1000, { inVehicle = true }))
    eq(s.phase, "watching", "driving after a hitch is not a teleport")
end)

test("follow: stops when the player gets in the car, dies or the car moved", function()
    local s = Follow.new(nil, 10, 10)
    eq(Follow.step(s, at(12, 12, 0, { inOurVehicle = true })), "stop", "in our car")
    eq(s.reason, "in-vehicle", "reason")
    eq(Follow.step(s, at(12, 12, 100)), "stop", "stays stopped")
    s = Follow.new(nil, 10, 10)
    eq(Follow.step(s, at(12, 12, 0, { dead = true })), "stop", "dead")
    s = Follow.new(nil, 10, 10)
    eq(Follow.step(s, at(12, 12, 0, { carX = 11, carY = 11 })), "wait", "car settled a tile")
    eq(Follow.step(s, at(12, 12, 100, { carX = 30, carY = 10 })), "stop", "car moved")
    eq(s.reason, "car-moved", "reason")
end)

test("follow: the watch window counts active time only", function()
    local s = Follow.new({ windowMs = 5000 }, 10, 10)
    eq(stand(s, 12, 12, 0, 4000), "wait", "inside the window")
    eq(Follow.step(s, at(12, 12, 60000)), "wait", "a long pause counts one second")
    eq(stand(s, 12, 12, 60100, 61000), "stop", "window used up")
    eq(s.reason, "window", "reason")
end)

test("follow: gives up when the new area never loads", function()
    local s = Follow.new(nil, 10, 10)
    Follow.step(s, at(12, 12, 0))
    Follow.step(s, at(500, 500, 100))
    stand(s, 500, 500, 200, 2200)
    ok(Follow.isLoading(s), "loading")
    eq(Follow.step(s, at(500, 500, 30000)), "wait", "still within the timeout")
    eq(Follow.step(s, at(500, 500, 32300)), "stop", "timed out")
    eq(s.reason, "load-timeout", "reason")
end)

test("follow: done moves the car anchor and stops after maxFollows", function()
    local s, action = followed()
    eq(action, "respawn", "first follow")
    eq(Follow.done(s, true, 505, 503), "wait", "watching again")
    eq(s.car.x, 505, "anchor moved")
    eq(s.phase, "watching", "phase")
    Follow.step(s, at(500, 500, 2400))
    eq(s.last.t, 2400, "fresh first sample after done")
    s.follows = s.opts.maxFollows - 1
    s.phase = "spawning"
    eq(Follow.done(s, true, 1, 1), "stop", "last follow")
    eq(s.reason, "max-follows", "reason")
end)

test("follow: a failed respawn stops the watch", function()
    local s = followed()
    eq(Follow.done(s, false), "stop", "stopped")
    eq(s.reason, "spawn-failed", "reason")
end)

test("follow: probePoints is the center plus a capped ring", function()
    local p = Follow.probePoints(100, 200, 30, 40)
    eq(#p, 9, "nine points")
    eq(p[1][1], 100, "center x")
    eq(p[2][1], 70, "ring corner x")
    eq(p[2][2], 170, "ring corner y")
    local capped = Follow.probePoints(0, 0, 80, 40)
    eq(capped[9][1], 40, "capped at 40")
    eq(#Follow.probePoints(5, 5, 0, 40), 1, "radius 0 is just the center")
end)

test("follow: allLoaded needs every point and timedOut compares ms", function()
    local pts = Follow.probePoints(0, 0, 10, 40)
    eq(Follow.allLoaded(pts, function() return true end), true, "all")
    eq(Follow.allLoaded(pts, function(x) return x < 10 end), false, "one missing")
    eq(Follow.timedOut(0, 1000, 1000), false, "at the limit")
    eq(Follow.timedOut(0, 1001, 1000), true, "past it")
end)

test("follow: maxFollows 0 never follows", function()
    local s = Follow.new({ maxFollows = 0 }, 10, 10)
    eq(Follow.step(s, at(12, 12, 0)), "stop", "stops at once")
    eq(s.reason, "max-follows", "reason")
end)
