--- Puts furniture down and takes it away with the game's own furniture
--- code (ISMoveableSpriteProps), the same path the debug tile brush uses,
--- so a placed fridge, stove, lamp or TV is the real working object.
local Footprint = require("FurnishByRoom/footprint")

local Place = {}

--- Returns the parts a sprite covers when hovered over x, y, z: one for a
--- single tile, one per cell for a bed, couch or other multi-tile piece.
function Place.parts(spriteName, x, y, z)
    local sprite = getSprite(spriteName)
    local grid = sprite and sprite:getSpriteGrid()
    if not grid then
        return Footprint.single(x, y, z, spriteName)
    end
    return Footprint.parts(x, y, z, grid:getSpriteGridPosX(sprite), grid:getSpriteGridPosY(sprite),
        grid:getWidth(), grid:getHeight(), function(gx, gy)
            local cell = grid:getSprite(gx, gy)
            return cell and cell:getName() or nil
        end)
end

--- Returns the stand-in item the game's placement code reads from (a plank,
--- as the debug tile brush uses), made once.
function Place.item()
    if not Place.plank then
        Place.plank = instanceItem("Base.Plank")
    end
    return Place.plank
end

--- Returns the square a part sits on, or nil when it is not loaded.
function Place.square(part)
    return getCell():getGridSquare(part.x, part.y, part.z)
end

--- Returns the object on the square drawn with the sprite, or nil.
function Place.find(square, spriteName)
    local objects = square and square:getObjects()
    if not objects then
        return nil
    end
    for i = objects:size() - 1, 0, -1 do
        local obj = objects:get(i)
        local sprite = obj:getSprite()
        if sprite and sprite:getName() == spriteName then
            return obj
        end
    end
    return nil
end

--- Returns true when a wall or door frame would cut a multi-tile piece.
local function wallBetween(parts)
    if #parts < 2 then
        return false
    end
    local sprite = getSprite(parts[1].sprite)
    local grid = sprite and sprite:getSpriteGrid()
    if not grid then
        return false
    end
    local minX, minY = parts[1].x, parts[1].y
    for _, part in ipairs(parts) do
        minX, minY = math.min(minX, part.x), math.min(minY, part.y)
    end
    local props = ISMoveableSpriteProps.new(sprite)
    return props:isWallBetweenParts(grid, minX, minY, parts[1].z) == true
end

--- Runs the game's fit rule for one tile with its movables cheat on, so
--- the rule checks the square (walls, counters, stairs, what is already
--- there) but not the player's tools or skill: counters, cabinets and
--- wardrobes otherwise need a hammer and carpentry. The cheat flag is put
--- back even if the rule throws.
function Place.fits(props, player, square)
    local defs = ISMoveableDefinitions
    local was = defs and defs.cheat
    if defs then
        defs.cheat = true
    end
    local okay, result = pcall(props.canPlaceMoveableInternal, props, player, square, Place.item())
    if defs then
        defs.cheat = was
    end
    return okay and result == true
end

--- Returns true when every part can go down. With anywhere on, only a
--- missing floor, a car or the same piece already there blocks it.
function Place.canPlace(player, parts, anywhere)
    if #parts == 0 then
        return false
    end
    for _, part in ipairs(parts) do
        local square = Place.square(part)
        if not square or not square:getFloor() or square:isVehicleIntersecting() then
            return false
        end
        if Place.find(square, part.sprite) then
            return false
        end
        if not anywhere then
            local props = ISMoveableSpriteProps.new(part.sprite)
            if not Place.fits(props, player, square) then
                return false
            end
        end
    end
    if not anywhere and wallBetween(parts) then
        return false
    end
    return true
end

--- Marks a new object's containers as already searched, so the game never
--- rolls loot into furniture the player conjured. They start empty.
function Place.emptyContainers(obj)
    for i = 0, obj:getContainerCount() - 1 do
        local container = obj:getContainerByIndex(i)
        if container then
            container:setExplored(true)
        end
    end
end

--- Places every part and returns the ones that landed.
function Place.place(player, parts)
    local placed = {}
    for _, part in ipairs(parts) do
        local square = Place.square(part)
        if square then
            local props = ISMoveableSpriteProps.new(part.sprite)
            props.rawWeight = 10
            props:placeMoveableInternal(player, square, Place.item(), part.sprite)
            local obj = Place.find(square, part.sprite)
            if obj then
                Place.emptyContainers(obj)
                placed[#placed + 1] = part
            end
        end
    end
    return placed
end

--- Removes the object with the part's sprite. Returns true when one went.
function Place.removePart(part)
    local square = Place.square(part)
    local obj = Place.find(square, part.sprite)
    if not obj then
        return false
    end
    square:RemoveTileObject(obj)
    return true
end

--- Returns true when the object is a wall, door, window or floor, which the
--- Remove tool leaves alone.
function Place.isStructure(obj, square)
    if obj == square:getFloor() then
        return true
    end
    if instanceof(obj, "IsoWorldInventoryObject") or instanceof(obj, "IsoDoor")
        or instanceof(obj, "IsoWindow") or instanceof(obj, "IsoWindowFrame")
        or instanceof(obj, "IsoCurtain") or instanceof(obj, "IsoMovingObject") then
        return true
    end
    local props = obj:getProperties()
    if not props then
        return true
    end
    return props:has(IsoFlagType.WallN) or props:has(IsoFlagType.WallW) or props:has(IsoFlagType.WallNW)
        or props:has(IsoFlagType.WallSE) or props:has(IsoFlagType.doorN) or props:has(IsoFlagType.doorW)
        or props:has(IsoFlagType.solidfloor)
end

--- Returns the top piece of furniture on the square, or nil.
function Place.removable(square)
    local objects = square and square:getObjects()
    if not objects then
        return nil
    end
    for i = objects:size() - 1, 0, -1 do
        local obj = objects:get(i)
        if not Place.isStructure(obj, square) then
            local props = obj:getProperties()
            if props and props:has("IsMoveAble") then
                return obj
            end
        end
    end
    return nil
end

--- Returns every part of the piece the object belongs to that is still in
--- the world, so removing one end of a bed removes the whole bed.
function Place.objectParts(obj)
    local square = obj:getSquare()
    local sprite = obj:getSprite()
    local name = sprite:getName()
    local parts = Place.parts(name, square:getX(), square:getY(), square:getZ())
    local out = {}
    for _, part in ipairs(parts) do
        if Place.find(Place.square(part), part.sprite) then
            out[#out + 1] = part
        end
    end
    return out
end

return Place
