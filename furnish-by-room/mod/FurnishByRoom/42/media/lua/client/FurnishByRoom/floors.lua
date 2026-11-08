--- Floor painting: swap a square's floor tile, find the squares of the room
--- under the mouse for a one-click fill, and put old floors back on undo.
local Footprint = require("FurnishByRoom/footprint")

local Floors = {}

--- Returns the floor sprite name on a square, or nil.
function Floors.current(square)
    local floor = square and square:getFloor()
    local sprite = floor and floor:getSprite()
    return sprite and sprite:getName() or nil
end

--- Paints one square and returns its old floor sprite name, or false when
--- it had no floor (one is added).
function Floors.paint(square, spriteName)
    local floor = square:getFloor()
    if floor then
        local old = Floors.current(square)
        floor:setSprite(getSprite(spriteName))
        floor:clearAttachedAnimSprite()
        return old or false
    end
    square:addFloor(spriteName)
    return false
end

--- Puts back the floor a paint replaced, or removes one it added.
function Floors.unpaint(square, old)
    local floor = square:getFloor()
    if old then
        if floor then
            floor:setSprite(getSprite(old))
        else
            square:addFloor(old)
        end
    elseif floor then
        square:RemoveTileObject(floor)
    end
end

--- Returns true when the square can take a floor paint.
function Floors.paintable(square)
    return square ~= nil and not square:has(IsoFlagType.water)
end

--- Returns the squares of the room under the square on its level, or just
--- the square when it is outdoors.
function Floors.roomSquares(square)
    local room = square:getRoom()
    if not room then
        return { square }
    end
    local list = room:getSquares()
    local out = {}
    for i = 0, list:size() - 1 do
        local sq = list:get(i)
        if sq:getZ() == square:getZ() and Floors.paintable(sq) then
            out[#out + 1] = sq
        end
    end
    if #out == 0 then
        out[1] = square
    end
    return out
end

--- Returns the loaded squares of a dragged rectangle, or nil when it is
--- too big.
function Floors.rectSquares(x1, y1, x2, y2, z)
    local cells = Footprint.rect(x1, y1, x2, y2)
    if not cells then
        return nil
    end
    local out = {}
    for _, cell in ipairs(cells) do
        local sq = getCell():getGridSquare(cell.x, cell.y, z)
        if Floors.paintable(sq) then
            out[#out + 1] = sq
        end
    end
    return out
end

--- Paints the squares and returns undo records for the ones that changed.
function Floors.paintAll(squares, spriteName)
    local tiles = {}
    for _, sq in ipairs(squares) do
        if Floors.current(sq) ~= spriteName then
            local old = Floors.paint(sq, spriteName)
            tiles[#tiles + 1] = { x = sq:getX(), y = sq:getY(), z = sq:getZ(), old = old, new = spriteName }
        end
    end
    return tiles
end

return Floors
