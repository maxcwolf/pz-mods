--- Rebuilds map objects from records with the game's own constructors, the
--- same ones its furniture placement uses (ISMoveableSpriteProps). Classes
--- Lua cannot reach go through the game's place-any-tile code instead.
local Factory = require("BaseBlueprints/factory")

local Build = {}

--- Puts paint, wall decorations, height offset and mod data back on an object.
function Build.decorate(obj, record)
    if record.overlay then
        local c = record.overlayColor
        if c then
            obj:setOverlaySprite(record.overlay, c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1)
        else
            obj:setOverlaySprite(record.overlay)
        end
    end
    if record.attached then
        for _, name in ipairs(record.attached) do
            local sprite = getSprite(name)
            if sprite then
                obj:AttachExistingAnim(sprite, 0, 0, false, 0, false, 0)
            end
        end
    end
    if record.yOffset then
        obj:setRenderYOffset(record.yOffset)
    end
    if record.modData then
        local data = obj:getModData()
        for k, v in pairs(record.modData) do
            data[k] = v
        end
    end
end

--- Restores an IsoThumpable's saved settings.
local function restoreThumpable(obj, record)
    local t = record.thump
    if t then
        for _, entry in ipairs(Factory.THUMPABLE_FLAGS) do
            if t[entry[1]] ~= nil then
                obj[entry[3]](obj, t[entry[1]] == true)
            end
        end
        for _, entry in ipairs(Factory.THUMPABLE_NUMBERS) do
            if type(t[entry[1]]) == "number" then
                obj[entry[3]](obj, t[entry[1]])
            end
        end
    end
    if record.name then
        obj:setName(record.name)
    end
end

--- Gives a new object its containers: empty, or with the saved contents
--- when the record carries them. Unknown item types are skipped.
function Build.fillContainers(obj, record)
    obj:createContainersFromSpriteProperties()
    local count = obj:getContainerCount()
    for i = 0, count - 1 do
        local cont = obj:getContainerByIndex(i)
        if cont then
            cont:setExplored(true)
            local saved = record.containers and record.containers[i + 1]
            if saved and saved.items then
                for _, item in ipairs(saved.items) do
                    if getScriptManager():FindItem(item.t) then
                        cont:AddItems(item.t, item.n or 1)
                    end
                end
            end
        end
    end
end

--- Places an object through the game's debug tile brush, which handles any
--- tile the way moving furniture does. Returns the object or nil.
function Build.brush(square, record)
    local props = ISMoveableSpriteProps.new(getSprite(record.sprite))
    props.rawWeight = 10
    local obj = props:placeMoveableInternal(getPlayer(), square, instanceItem("Base.Plank"), record.sprite)
    if obj then
        Build.decorate(obj, record)
    end
    return obj
end

--- Makes the object for a record without adding it to the square. Returns
--- obj, placedByGame (true when the brush already added it), or nil and a
--- reason. Floors are handled by apply.lua, not here.
function Build.create(cell, square, record)
    local sprite = getSprite(record.sprite)
    if not sprite then
        return nil, false, "unknown tile " .. tostring(record.sprite)
    end
    local kind = Factory.kind(record)
    local north = record.north == true
    local obj
    if kind == "door" then
        obj = IsoDoor.new(cell, square, record.sprite, north)
    elseif kind == "window" then
        obj = IsoWindow.new(cell, square, sprite, north)
        obj:setIsLocked(false)
    elseif kind == "frame" then
        obj = IsoWindowFrame.new(cell, square, sprite, north)
    elseif kind == "curtain" then
        obj = IsoCurtain.new(cell, square, record.sprite, north)
    elseif kind == "light" then
        obj = IsoLightSwitch.new(cell, square, sprite, square:getRoomID())
        obj:addLightSourceFromSprite()
    elseif kind == "thumpable" then
        obj = IsoThumpable.new(cell, square, record.sprite, north, {})
        restoreThumpable(obj, record)
    elseif kind == "mannequin" then
        obj = IsoMannequin.new(cell, square, sprite)
        obj:setSquare(square)
    elseif kind == "appliance" and _G[record.cls] then
        obj = _G[record.cls].new(cell, square, sprite)
        obj:setMovedThumpable(true)
    elseif kind == "plain" then
        obj = IsoObject.new(cell, square, record.sprite)
    else
        local placed = Build.brush(square, record)
        if not placed then
            return nil, false, "the game would not place " .. record.sprite
        end
        return placed, true
    end
    Build.decorate(obj, record)
    Build.fillContainers(obj, record)
    GameEntityFactory.CreateIsoEntityFromCellLoading(obj)
    return obj, false
end

return Build
