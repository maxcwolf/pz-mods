--- Where each tile of a piece of furniture goes, and the squares a floor
--- paint covers (a dragged rectangle, capped in size).
local Footprint = {}

Footprint.MAX_PAINT = 400

--- Returns the parts of a grid placed with the hovered tile at grid
--- position (posX, posY): one { x, y, z, sprite } per filled cell.
--- spriteAt(gx, gy) returns the sprite name in that cell or nil.
function Footprint.parts(x, y, z, posX, posY, width, height, spriteAt)
    local originX, originY = x - (posX or 0), y - (posY or 0)
    local out = {}
    for gx = 0, (width or 1) - 1 do
        for gy = 0, (height or 1) - 1 do
            local sprite = spriteAt(gx, gy)
            if sprite then
                out[#out + 1] = { x = originX + gx, y = originY + gy, z = z, sprite = sprite }
            end
        end
    end
    return out
end

--- Returns a single-tile footprint.
function Footprint.single(x, y, z, sprite)
    return { { x = x, y = y, z = z, sprite = sprite } }
end

--- Returns the squares between two corners as { x, y } pairs, or nil when
--- the rectangle is bigger than the cap.
function Footprint.rect(x1, y1, x2, y2, cap)
    local minX, maxX = math.min(x1, x2), math.max(x1, x2)
    local minY, maxY = math.min(y1, y2), math.max(y1, y2)
    if (maxX - minX + 1) * (maxY - minY + 1) > (cap or Footprint.MAX_PAINT) then
        return nil
    end
    local out = {}
    for x = minX, maxX do
        for y = minY, maxY do
            out[#out + 1] = { x = x, y = y }
        end
    end
    return out
end

return Footprint
