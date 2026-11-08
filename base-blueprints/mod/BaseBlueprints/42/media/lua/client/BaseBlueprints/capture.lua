--- Reads map squares into plain object records: class, sprite, facing,
--- paint, wall decorations, IsoThumpable settings, mod data and (only when
--- asked) container contents. Trees, grass, loose items and the like are
--- left out (see shared/BaseBlueprints/classify.lua).
local Classify = require("BaseBlueprints/classify")
local Signature = require("BaseBlueprints/signature")
local Keys = require("BaseBlueprints/keys")
local Factory = require("BaseBlueprints/factory")
local Codec = require("BaseBlueprints/codec")

local Capture = {}

Capture.MAX_MOD_DATA = 4000

local NORTH_CLASSES = {
    IsoDoor = true, IsoWindow = true, IsoWindowFrame = true, IsoCurtain = true, IsoThumpable = true,
}

--- Returns the simple class name of a map object.
function Capture.classOf(obj)
    local cls = Classify.fromToString(tostring(obj))
    if cls then
        return cls
    end
    for _, name in ipairs(Classify.KNOWN) do
        if instanceof(obj, name) then
            return name
        end
    end
    return "IsoObject"
end

--- Returns a sprite's name, or nil.
local function nameOf(sprite)
    if not sprite then
        return nil
    end
    local name = sprite:getName()
    if name == nil or name == "" then
        return nil
    end
    return name
end

--- Returns the names of the object's attached sprites (wall decorations,
--- floor blends), leaving out erosion ones; nil when none.
local function attachedNames(obj)
    local list = obj:getAttachedAnimSprite()
    if not list or list:size() == 0 then
        return nil
    end
    local names = {}
    for i = 0, list:size() - 1 do
        local inst = list:get(i)
        local name = inst and nameOf(inst:getParentSprite())
        if name and not Classify.isNature(name) then
            names[#names + 1] = name
        end
    end
    if #names == 0 then
        return nil
    end
    return names
end

--- Copies an IsoThumpable's settings into a table.
local function thumpableSettings(obj)
    local t = {}
    for _, entry in ipairs(Factory.THUMPABLE_FLAGS) do
        t[entry[1]] = obj[entry[2]](obj) == true
    end
    for _, entry in ipairs(Factory.THUMPABLE_NUMBERS) do
        t[entry[1]] = obj[entry[2]](obj)
    end
    return t
end

--- Returns the object's containers' contents as { { type, items = { { t, n } } } },
--- or nil when they are all empty.
local function containerContents(obj)
    local count = obj:getContainerCount()
    if count == 0 then
        return nil
    end
    local out = {}
    local any = false
    for i = 0, count - 1 do
        local cont = obj:getContainerByIndex(i)
        local entry = { type = cont and cont:getType() or "", items = {} }
        if cont then
            local items = cont:getItems()
            local counts, order = {}, {}
            for j = 0, items:size() - 1 do
                local fullType = items:get(j):getFullType()
                if not counts[fullType] then
                    counts[fullType] = 0
                    order[#order + 1] = fullType
                end
                counts[fullType] = counts[fullType] + 1
            end
            for _, fullType in ipairs(order) do
                entry.items[#entry.items + 1] = { t = fullType, n = counts[fullType] }
                any = true
            end
        end
        out[#out + 1] = entry
    end
    if not any then
        return nil
    end
    return out
end

--- Returns a copy of the object's mod data, or nil when there is none or it
--- is too big to carry.
local function modDataCopy(obj)
    if not obj:hasModData() then
        return nil
    end
    local copy = Codec.plain(obj:getModData())
    if type(copy) ~= "table" then
        return nil
    end
    local hasAny = false
    for _ in pairs(copy) do
        hasAny = true
        break
    end
    if not hasAny or #Codec.encode(copy) > Capture.MAX_MOD_DATA then
        return nil
    end
    return copy
end

--- Makes a record for one object, or returns nil for objects blueprints
--- ignore. `opts.contents` adds container contents.
function Capture.record(obj, isFloor, opts)
    local cls = Capture.classOf(obj)
    if Classify.isExcluded(cls) then
        return nil
    end
    local sprite = nameOf(obj:getSprite())
    if not sprite then
        return nil
    end
    if not isFloor then
        if Classify.isNature(sprite) then
            return nil
        end
        local props = obj:getProperties()
        if props and props:has(IsoFlagType.canBeRemoved) then
            return nil
        end
    end
    local record = { cls = cls, sprite = sprite }
    if isFloor then
        record.floor = true
    end
    if NORTH_CLASSES[cls] and obj:getNorth() then
        record.north = true
    end
    local overlay = nameOf(obj:getOverlaySprite())
    if overlay then
        record.overlay = overlay
        local color = obj:getOverlaySpriteColor()
        if color then
            record.overlayColor = { color:getR(), color:getG(), color:getB(), color:getA() }
        end
    end
    record.attached = attachedNames(obj)
    local yOffset = obj:getRenderYOffset()
    if yOffset and yOffset ~= 0 then
        record.yOffset = yOffset
    end
    if cls == "IsoThumpable" then
        record.thump = thumpableSettings(obj)
        local name = obj:getName()
        if name and name ~= "" then
            record.name = name
        end
    end
    record.modData = modDataCopy(obj)
    if opts and opts.contents and not isFloor then
        record.containers = containerContents(obj)
    end
    return record
end

--- Reads a square. Returns its records and the matching objects, in the
--- square's order. A missing square reads as empty.
function Capture.square(square, opts)
    local records, objects = {}, {}
    if not square then
        return records, objects
    end
    local floor = square:getFloor()
    local list = square:getObjects()
    for i = 0, list:size() - 1 do
        local obj = list:get(i)
        local record = Capture.record(obj, obj == floor, opts)
        if record then
            records[#records + 1] = record
            objects[#objects + 1] = obj
        end
    end
    return records, objects
end

--- Returns true when the map around a column is loaded right now.
function Capture.isLoaded(x, y)
    return getCell():getChunkForGridSquare(x, y, 0) ~= nil
end

--- Walks an area's loaded squares. Calls fn(key, square) for each (square
--- may be nil where the map has nothing). Returns the set of keys skipped
--- because their map was not loaded, and how many.
function Capture.eachLoaded(area, fn)
    local cell = getCell()
    local unloaded, count = {}, 0
    for y = area.y1, area.y2 do
        for x = area.x1, area.x2 do
            local loaded = Capture.isLoaded(x, y)
            for z = area.z1, area.z2 do
                local key = Keys.square(x, y, z)
                if loaded then
                    fn(key, cell:getGridSquare(x, y, z))
                else
                    unloaded[key] = true
                    count = count + 1
                end
            end
        end
    end
    return unloaded, count
end

--- Returns key -> square signature for every non-empty loaded square in an
--- area, plus the unloaded set and count.
function Capture.signatures(area)
    local sigs = {}
    local unloaded, count = Capture.eachLoaded(area, function(key, square)
        local records = Capture.square(square)
        if #records > 0 then
            sigs[key] = Signature.ofList(records)
        end
    end)
    return sigs, unloaded, count
end

--- Returns key -> records for the listed keys (all loaded squares when
--- `keys` is nil). Squares with nothing on them are included as empty lists
--- so applying clears them.
function Capture.records(area, keys, opts)
    local wanted = nil
    if keys then
        wanted = {}
        for _, key in ipairs(keys) do
            wanted[key] = true
        end
    end
    local squares = {}
    Capture.eachLoaded(area, function(key, square)
        if not wanted or wanted[key] then
            squares[key] = Capture.square(square, opts)
        end
    end)
    return squares
end

return Capture
