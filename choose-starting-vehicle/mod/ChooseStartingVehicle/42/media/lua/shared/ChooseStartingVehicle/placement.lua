--- Finds a free patch of ground near the spawn point that fits the vehicle and,
--- when one is chosen, its trailer lined up behind it. Pure: the world is read
--- through `isClear(x, y)` and `isPreferred(x, y)` callbacks.
local Placement = {}

Placement.DIRECTIONS = { "N", "E", "S", "W" }
Placement.FORWARD = { N = { 0, -1 }, E = { 1, 0 }, S = { 0, 1 }, W = { -1, 0 } }

--- Returns the number of whole tiles a body of `size` tiles covers, plus padding.
function Placement.tilesFor(size, padding)
    return math.max(1, math.ceil((tonumber(size) or 1) + (padding or 0)))
end

--- Lists the tiles of a rectangle `width` x `length` tiles centered on (cx, cy)
--- with its length along the facing direction.
function Placement.footprint(cx, cy, dir, width, length)
    local spanX, spanY = width, length
    if dir == "E" or dir == "W" then
        spanX, spanY = length, width
    end
    local x0 = cx - math.floor(spanX / 2)
    local y0 = cy - math.floor(spanY / 2)
    local tiles = {}
    for y = y0, y0 + spanY - 1 do
        for x = x0, x0 + spanX - 1 do
            tiles[#tiles + 1] = { x, y }
        end
    end
    return tiles
end

--- Returns the tile a body sits on when it is `offset` tiles along the facing
--- direction from the anchor; negative offsets are behind. Rounds away from the
--- anchor so a trailer lands a little far rather than inside the car.
function Placement.offsetTile(x, y, dir, offset)
    local f = Placement.FORWARD[dir]
    local steps = offset < 0 and -math.ceil(-offset - 1e-6) or math.ceil(offset - 1e-6)
    return x + f[1] * steps, y + f[2] * steps
end

--- Returns the centers of every body for an anchor tile and direction.
function Placement.bodyCenters(x, y, dir, bodies)
    local centers = {}
    for i, body in ipairs(bodies) do
        local bx, by = Placement.offsetTile(x, y, dir, body.offset or 0)
        centers[i] = { x = bx, y = by }
    end
    return centers
end

--- True when every tile under every body is clear.
function Placement.fits(x, y, dir, bodies, isClear)
    for i, center in ipairs(Placement.bodyCenters(x, y, dir, bodies)) do
        local body = bodies[i]
        for _, tile in ipairs(Placement.footprint(center.x, center.y, dir, body.width, body.length)) do
            if not isClear(tile[1], tile[2]) then
                return false
            end
        end
    end
    return true
end

--- Lists candidate anchor tiles nearest-first between two Chebyshev radii.
function Placement.candidates(ox, oy, minRadius, maxRadius)
    local list = {}
    for r = minRadius, maxRadius do
        local ring = {}
        for dy = -r, r do
            for dx = -r, r do
                if math.max(math.abs(dx), math.abs(dy)) == r then
                    ring[#ring + 1] = { x = ox + dx, y = oy + dy, d = dx * dx + dy * dy }
                end
            end
        end
        table.sort(ring, function(a, b)
            if a.d ~= b.d then
                return a.d < b.d
            end
            if a.y ~= b.y then
                return a.y < b.y
            end
            return a.x < b.x
        end)
        for _, c in ipairs(ring) do
            list[#list + 1] = c
        end
    end
    return list
end

--- Wraps a predicate so each tile is asked about once.
function Placement.memoize(fn)
    local cache = {}
    return function(x, y)
        local key = tostring(x) .. "," .. tostring(y)
        local value = cache[key]
        if value == nil then
            value = fn(x, y) and true or false
            cache[key] = value
        end
        return value
    end
end

--- Finds an anchor tile and direction for `bodies` (each {offset, width,
--- length} in tiles; the first is the vehicle at offset 0). Tries tiles where
--- `isPreferred` holds for every body center first (roads, parking lots), then
--- any clear ground. Returns {x, y, dir, centers} or nil.
function Placement.findSpot(opts)
    local isClear = Placement.memoize(opts.isClear)
    local isPreferred = opts.isPreferred and Placement.memoize(opts.isPreferred) or nil
    local list = Placement.candidates(opts.originX, opts.originY, opts.minRadius or 3, opts.maxRadius or 25)
    local passes = isPreferred and { true, false } or { false }
    for _, preferred in ipairs(passes) do
        for _, c in ipairs(list) do
            for _, dir in ipairs(opts.directions or Placement.DIRECTIONS) do
                local centers = Placement.bodyCenters(c.x, c.y, dir, opts.bodies)
                local ok = true
                if preferred then
                    for _, center in ipairs(centers) do
                        if not isPreferred(center.x, center.y) then
                            ok = false
                            break
                        end
                    end
                end
                if ok and Placement.fits(c.x, c.y, dir, opts.bodies, isClear) then
                    return { x = c.x, y = c.y, dir = dir, centers = centers }
                end
            end
        end
    end
    return nil
end

--- Returns how far behind the vehicle's center the trailer's center sits so the
--- hitches meet: `carHitch` is the z of the car's "trailer" attachment and
--- `trailerHitch` the z of the trailer's "trailerfront" one (forward is +z).
function Placement.trailerOffset(carHitch, trailerHitch)
    return carHitch - trailerHitch
end

return Placement
