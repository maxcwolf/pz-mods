--- Reverses one history action: takes placed furniture away, puts removed
--- furniture back, restores painted floors. Squares that are no longer
--- loaded are skipped.
local Place = require("FurnishByRoom/place")
local Floors = require("FurnishByRoom/floors")

local Undo = {}

--- Reverses the action and returns how many tiles changed.
function Undo.apply(action, player)
    local changed = 0
    if action.kind == "place" then
        for _, part in ipairs(action.parts) do
            if Place.removePart(part) then
                changed = changed + 1
            end
        end
    elseif action.kind == "remove" then
        changed = #Place.place(player, action.parts)
    elseif action.kind == "floor" then
        for _, tile in ipairs(action.tiles) do
            local square = getCell():getGridSquare(tile.x, tile.y, tile.z)
            if square then
                Floors.unpaint(square, tile.old)
                changed = changed + 1
            end
        end
    end
    return changed
end

return Undo
