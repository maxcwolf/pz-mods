--- The box of squares a claimed base covers: a building's footprint plus a
--- margin of yard, from its lowest level up to the roof level.
local Keys = require("BaseBlueprints/keys")

local Area = {}

--- Yard margins offered when claiming. The game puts a building's east and
--- south outer walls on the squares just outside its rooms, so 1 is the least
--- that still holds every wall.
Area.HOUSE_MARGIN = 1
Area.YARD_MARGIN = 6
Area.MAX_SQUARES = 60000

--- Builds an area from building bounds { x, y, w, h, minLevel, maxLevel }.
--- The roof sits one level above the top floor, so it is included.
function Area.fromBuilding(def, margin)
    margin = math.max(1, math.floor(margin or Area.HOUSE_MARGIN))
    return {
        x1 = def.x - margin,
        y1 = def.y - margin,
        x2 = def.x + def.w - 1 + margin,
        y2 = def.y + def.h - 1 + margin,
        z1 = def.minLevel or 0,
        z2 = (def.maxLevel or 0) + 1,
    }
end

--- Returns the number of squares in an area.
function Area.count(area)
    return (area.x2 - area.x1 + 1) * (area.y2 - area.y1 + 1) * (area.z2 - area.z1 + 1)
end

--- Returns true when a square is inside an area.
function Area.contains(area, x, y, z)
    return x >= area.x1 and x <= area.x2 and y >= area.y1 and y <= area.y2 and z >= area.z1 and z <= area.z2
end

--- Returns every square key in an area, by level, row and column.
function Area.keys(area)
    local keys = {}
    for z = area.z1, area.z2 do
        for y = area.y1, area.y2 do
            for x = area.x1, area.x2 do
                keys[#keys + 1] = Keys.square(x, y, z)
            end
        end
    end
    return keys
end

--- Returns the middle square of an area's footprint.
function Area.center(area)
    return math.floor((area.x1 + area.x2) / 2), math.floor((area.y1 + area.y2) / 2)
end

--- Returns true when an area has sane bounds and is not huge.
function Area.isValid(area)
    if type(area) ~= "table" then
        return false
    end
    for _, field in ipairs({ "x1", "y1", "x2", "y2", "z1", "z2" }) do
        if type(area[field]) ~= "number" then
            return false
        end
    end
    if area.x2 < area.x1 or area.y2 < area.y1 or area.z2 < area.z1 then
        return false
    end
    return Area.count(area) <= Area.MAX_SQUARES
end

return Area
