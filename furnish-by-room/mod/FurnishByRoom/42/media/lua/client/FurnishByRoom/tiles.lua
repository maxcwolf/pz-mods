--- Reads every loaded tile sheet (vanilla and modded) into plain records
--- the catalog can sort: name, container type, facing, floor or not, and
--- whether the tile anchors a multi-tile piece.
local Tiles = {}

Tiles.MAX_INDEX = 1023
Tiles.MISS_RUN = 128

--- Returns the names of the loaded tile sheets, without file extensions.
function Tiles.sheetNames()
    local out, seen = {}, {}
    local world = getWorld()
    local list = world and world:getTileImageNames()
    if not list then
        return out
    end
    for i = 0, list:size() - 1 do
        local name = string.match(tostring(list:get(i)), "^([^%.]+)")
        if name and not seen[name] then
            seen[name] = true
            out[#out + 1] = name
        end
    end
    table.sort(out)
    return out
end

--- Returns a property's value, or nil when the tile lacks it.
local function prop(props, key)
    if props:has(key) then
        return props:get(key)
    end
    return nil
end

--- Returns a record for one sprite, or nil when it is neither furniture
--- the game can move nor a floor.
function Tiles.record(sheet, index, sprite)
    local props = sprite and sprite:getProperties()
    if not props then
        return nil
    end
    local moveable = props:has("IsMoveAble")
    local floor = props:has(IsoFlagType.solidfloor)
    if not moveable and not floor then
        return nil
    end
    local anchor = true
    local grid = sprite:getSpriteGrid()
    if grid then
        anchor = grid:getAnchorSprite() == sprite
    end
    return {
        sprite = sprite:getName(),
        sheet = sheet,
        index = index,
        group = prop(props, "GroupName"),
        custom = prop(props, "CustomName"),
        container = prop(props, "container"),
        facing = prop(props, "Facing"),
        moveable = moveable,
        floor = floor,
        anchor = anchor,
    }
end

--- Reads one sheet, stopping after a long run of missing tile numbers.
function Tiles.scanSheet(sheet, out)
    local misses = 0
    for index = 0, Tiles.MAX_INDEX do
        local sprite = getSprite(sheet .. "_" .. index)
        if sprite then
            misses = 0
            local record = Tiles.record(sheet, index, sprite)
            if record then
                out[#out + 1] = record
            end
        else
            misses = misses + 1
            if misses >= Tiles.MISS_RUN then
                return
            end
        end
    end
end

--- Reads every sheet and returns the records.
function Tiles.scan()
    local out = {}
    for _, sheet in ipairs(Tiles.sheetNames()) do
        Tiles.scanSheet(sheet, out)
    end
    return out
end

return Tiles
