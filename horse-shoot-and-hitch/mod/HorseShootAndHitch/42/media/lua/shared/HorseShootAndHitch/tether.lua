--- Pure rules for tying a horse to a fence, pole or tree: which objects count,
--- what the tie costs and how to keep the horse within a few tiles of the post.
--- No Project Zomboid globals are used here so the module can be unit-tested.
local Tether = {}

Tether.DEFAULT_RADIUS = 2

--- What the horse was tied with; decides whether untying hands back a rope.
Tether.REINS = "reins"
Tether.ROPE = "rope"

--- Sprite name prefixes for posts, poles and railings that are not hoppable fences.
Tether.POLE_PREFIXES = {
    "fencing_",
    "fixtures_railings_",
    "features_railings_",
    "lighting_outdoor_",
    "street_roadsigns_",
    "electricity_pylon",
    "location_farm_accessories_",
}

--- Tells whether a sprite name starts with one of the pole prefixes.
function Tether.isPoleSprite(spriteName)
    if not spriteName then return false end
    for _, prefix in ipairs(Tether.POLE_PREFIXES) do
        if string.sub(spriteName, 1, #prefix) == prefix then return true end
    end
    return false
end

--- Decides whether an object, described by plain facts about it, can hold a tied horse.
--- `info` has: tree, hoppable, tallHoppable, canAttachAnimal (booleans) and spriteName.
function Tether.isTiePoint(info)
    if not info then return false end
    if info.tree or info.canAttachAnimal then return true end
    if info.hoppable or info.tallHoppable then return true end
    return Tether.isPoleSprite(info.spriteName)
end

--- Picks what the tie uses: reins if the horse wears them, otherwise a rope, otherwise nothing.
function Tether.tieCost(hasReins, hasRope)
    if hasReins then return Tether.REINS end
    if hasRope then return Tether.ROPE end
    return nil
end

--- Builds the record stored in the horse's mod data for a tie at a post.
function Tether.record(x, y, z, spriteName, cost)
    return { x = x, y = y, z = z, sprite = spriteName, cost = cost }
end

--- Tells whether a stored record is complete enough to use.
function Tether.isValidRecord(record)
    return type(record) == "table"
        and type(record.x) == "number"
        and type(record.y) == "number"
        and type(record.z) == "number"
end

--- Distance from a point to the centre of the post's tile.
function Tether.distanceToPost(x, y, record)
    local dx = x - (record.x + 0.5)
    local dy = y - (record.y + 0.5)
    return math.sqrt(dx * dx + dy * dy)
end

--- Tells whether a horse at (x, y) has strayed past the tether radius.
function Tether.isOutOfReach(x, y, record, radius)
    return Tether.distanceToPost(x, y, record) > (radius or Tether.DEFAULT_RADIUS) + 0.5
end

--- Tells whether a horse is so far off (a load glitch or a teleport) that it should be put back.
function Tether.isLost(x, y, record, radius)
    return Tether.distanceToPost(x, y, record) > (radius or Tether.DEFAULT_RADIUS) + 8
end

--- Picks the tile to walk a straying horse back to: one step inside the radius on its side of the post.
function Tether.returnTile(x, y, record, radius)
    local cx, cy = record.x + 0.5, record.y + 0.5
    local dx, dy = x - cx, y - cy
    local length = math.sqrt(dx * dx + dy * dy)
    local reach = math.max((radius or Tether.DEFAULT_RADIUS) - 1, 1)
    if length < 0.001 then return record.x + 1, record.y end
    local tx = math.floor(cx + dx / length * reach)
    local ty = math.floor(cy + dy / length * reach)
    if tx == record.x and ty == record.y then tx = tx + 1 end
    return tx, ty
end

return Tether
