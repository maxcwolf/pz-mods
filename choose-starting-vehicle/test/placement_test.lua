local Placement = require("ChooseStartingVehicle/placement")

--- Returns an isClear predicate over a set of blocked "x,y" keys.
local function world(blocked)
    return function(x, y)
        return not blocked[x .. "," .. y]
    end
end

test("footprint covers width x length along the facing direction", function()
    eq(#Placement.footprint(0, 0, "N", 2, 5), 10, "count")
    local tiles = Placement.footprint(10, 10, "E", 2, 5)
    local minX, maxX = 99, -99
    for _, t in ipairs(tiles) do
        minX = math.min(minX, t[1])
        maxX = math.max(maxX, t[1])
    end
    eq(maxX - minX + 1, 5, "length runs along x when facing east")
end)

test("tilesFor rounds up with padding", function()
    eq(Placement.tilesFor(1.73, 0.6), 3, "width")
    eq(Placement.tilesFor(4.36, 0.6), 5, "length")
    eq(Placement.tilesFor(nil), 1, "nil")
end)

test("offsetTile rounds away from the anchor", function()
    local x, y = Placement.offsetTile(0, 0, "N", -4.2)
    eq(x, 0, "x")
    eq(y, 5, "behind a north-facing car is +y")
    x, y = Placement.offsetTile(0, 0, "E", -4.0)
    eq(x, -4, "exact stays")
end)

test("findSpot returns the nearest clear spot at or beyond the minimum radius", function()
    local spot = Placement.findSpot({ originX = 0, originY = 0, bodies = { { offset = 0, width = 1, length = 1 } }, minRadius = 3, maxRadius = 5, isClear = world({}) })
    ok(spot, "found")
    eq(math.max(math.abs(spot.x), math.abs(spot.y)), 3, "ring 3")
end)

test("findSpot skips blocked tiles and gives up past the radius", function()
    local blocked = {}
    for x = -10, 10 do
        for y = -10, 10 do
            blocked[x .. "," .. y] = true
        end
    end
    blocked["4,0"] = nil
    local body = { { offset = 0, width = 1, length = 1 } }
    local spot = Placement.findSpot({ originX = 0, originY = 0, bodies = body, minRadius = 3, maxRadius = 6, isClear = world(blocked) })
    eq(spot.x, 4, "only clear tile x")
    eq(spot.y, 0, "only clear tile y")
    blocked["4,0"] = true
    eq(Placement.findSpot({ originX = 0, originY = 0, bodies = body, minRadius = 3, maxRadius = 6, isClear = world(blocked) }), nil, "none")
end)

test("findSpot prefers road tiles over nearer open ground", function()
    local spot = Placement.findSpot({
        originX = 0, originY = 0, minRadius = 3, maxRadius = 10,
        bodies = { { offset = 0, width = 1, length = 1 } },
        isClear = world({}),
        isPreferred = function(x, y) return x == 8 end,
    })
    eq(spot.x, 8, "road column")
end)

test("findSpot needs room for the trailer too and turns to fit", function()
    -- a corridor running east-west at y = 5: only an E/W train fits
    local function isClear(x, y)
        return y == 5
    end
    local bodies = { { offset = 0, width = 1, length = 3 }, { offset = -4, width = 1, length = 3 } }
    local spot = Placement.findSpot({ originX = 0, originY = 0, minRadius = 3, maxRadius = 8, bodies = bodies, isClear = isClear })
    ok(spot, "found")
    ok(spot.dir == "E" or spot.dir == "W", "turned along the corridor")
    eq(spot.centers[2].y, 5, "trailer on the corridor")
    eq(math.abs(spot.centers[2].x - spot.centers[1].x), 4, "trailer four tiles behind")
end)

test("trailerOffset puts the trailer behind the car hitch", function()
    eq(Placement.trailerOffset(-2.5, 2.0), -4.5, "behind")
end)

test("memoize asks once per tile", function()
    local calls = 0
    local f = Placement.memoize(function() calls = calls + 1 return false end)
    f(1, 2)
    f(1, 2)
    eq(calls, 1, "cached false")
end)
