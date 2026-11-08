--- Small fakes of the game objects apply.lua and state.lua touch: items,
--- containers, vehicle parts, vehicles, squares, the cell, the script manager
--- and the file reader/writer. Each test calls Stubs.reset() for a clean world.
local Stubs = {}

--- A vector with JOML-style x()/y()/z() getters.
local function vec(x, y, z)
    return { x = function() return x end, y = function() return y end, z = function() return z end }
end

--- Creates a fake inventory item.
function Stubs.item(fullType)
    return { fullType = fullType, getFullType = function(self) return self.fullType end, usedDelta = nil,
        setUsedDelta = function(self, v) self.usedDelta = v end, drainable = string.find(fullType, "Battery", 1, true) ~= nil,
        getContainer = function(self) return self.container end }
end

--- Creates a fake item container; `bags` holds nested containers.
function Stubs.container()
    local c = { items = {}, bags = {} }
    function c:AddItem(item)
        if type(item) == "string" then
            item = Stubs.item(item)
        end
        table.insert(self.items, item)
        item.container = self
        return item
    end
    function c:Remove(item)
        for i, it in ipairs(self.items) do
            if it == item then
                table.remove(self.items, i)
                item.container = nil
                return
            end
        end
    end
    function c:containsRecursive(item)
        for _, it in ipairs(self.items) do
            if it == item then return true end
        end
        for _, bag in ipairs(self.bags) do
            if bag:containsRecursive(item) then return true end
        end
        return false
    end
    return c
end

--- Creates a fake vehicle part. `opts`: item, itemTypes, wheel, capacity, door, category, container, install, uninstall.
function Stubs.part(id, opts)
    opts = opts or {}
    local p = { id = id, item = opts.item, condition = 50, content = 0, opts = opts, log = {} }
    if opts.door then
        p.door = { locked = true, setLocked = function(self, v) self.locked = v end }
    end
    p.itemContainer = opts.container and Stubs.container() or nil
    function p:getId() return self.id end
    function p:getInventoryItem() return self.item end
    function p:setInventoryItem(item) self.item = item end
    function p:getTable(name) return self.opts[name] end
    function p:getWheelIndex() return self.opts.wheel or -1 end
    function p:getContainerCapacity() return self.opts.capacity or 0 end
    function p:setContainerContentAmount(v) self.content = v end
    function p:setCondition(v) self.condition = v end
    function p:getDoor() return self.door end
    function p:getItemContainer() return self.itemContainer end
    function p:getCategory() return self.opts.category end
    function p:getItemType()
        local list = self.opts.itemTypes or {}
        return { isEmpty = function() return #list == 0 end }
    end
    return p
end

--- Creates a fake vehicle from a list of parts.
function Stubs.vehicle(scriptName, parts)
    local v = { scriptName = scriptName, parts = parts or {}, modData = {}, rust = 1, constraints = {}, transmits = 0, skin = 0, skinCount = 3 }
    function v:getPartCount() return #self.parts end
    function v:getPartByIndex(i) return self.parts[i + 1] end
    function v:getPartById(id)
        for _, p in ipairs(self.parts) do
            if p.id == id then return p end
        end
        return nil
    end
    function v:getModData() return self.modData end
    function v:getScriptName() return self.scriptName end
    function v:transmitPartItem() self.transmits = self.transmits + 1 end
    function v:transmitPartCondition() end
    function v:transmitPartDoor() end
    function v:transmitPartModData() end
    function v:transmitPartUsedDelta() end
    function v:transmitRust() end
    function v:transmitColorHSV() end
    function v:setRust(r) self.rust = r end
    function v:setTrunkLocked(b) self.trunkLocked = b end
    function v:setAlarmed(b) self.alarmed = b end
    function v:getSkinCount() return self.skinCount end
    function v:setSkinIndex(i) self.skin = i end
    function v:updateSkin() end
    function v:setColorHSV(h, s, val) self.hsv = { h, s, val } end
    function v:updatePartStats() end
    function v:doDamageOverlay() end
    function v:createVehicleKey() return Stubs.item("Base.CarKey") end
    function v:attachmentExist(id) return id == "trailer" or id == "trailerfront" end
    function v:addPointConstraint(player, other, a, b) table.insert(self.constraints, { other = other, a = a, b = b }) end
    v.angles = { 0, 0, 0 }
    function v:getAngleX() return self.angles[1] end
    function v:getAngleY() return self.angles[2] end
    function v:getAngleZ() return self.angles[3] end
    function v:setAngles(x, y, z) self.angles = { x, y, z } end
    function v:permanentlyRemove() self.removed = true end
    function v:getX() local at = self.spawnedAt or { x = 0 } return at.x + 0.5 end
    function v:getY() local at = self.spawnedAt or { y = 0 } return at.y + 0.5 end
    v.canAttach = true
    function v:canAttachTrailer() return self.canAttach end
    --- World position of a local point, for an axis-aligned vehicle at its spawn tile.
    function v:getWorldPos(lx, ly, lz)
        local at = self.spawnedAt or { x = 0, y = 0, dir = "N" }
        local f = ({ N = { 0, -1 }, E = { 1, 0 }, S = { 0, 1 }, W = { -1, 0 } })[at.dir]
        local px, py = at.x + 0.5 + f[1] * lz, at.y + 0.5 + f[2] * lz
        return { x = function() return px end, y = function() return py end, z = function() return 0 end }
    end
    return v
end

--- Creates a fake vehicle script with extents and hitch attachments.
function Stubs.script(fullName, width, length, hitches)
    local s = { fullName = fullName }
    function s:getFullName() return self.fullName end
    function s:getExtents() return vec(width, 1, length) end
    function s:getAttachmentById(id)
        local z = hitches and hitches[id]
        if not z then return nil end
        return { getOffset = function() return vec(0, 0, z) end }
    end
    function s:getModel() return { getOffset = function() return vec(0, 0, 0) end } end
    return s
end

--- Creates a fake game event with Add, Remove and a test-only fire.
local function event()
    local e = { handlers = {} }
    function e.Add(fn) table.insert(e.handlers, fn) end
    function e.Remove(fn)
        for i, h in ipairs(e.handlers) do
            if h == fn then table.remove(e.handlers, i) return end
        end
    end
    function e.fire(...)
        local copy = {}
        for i, h in ipairs(e.handlers) do copy[i] = h end
        for _, h in ipairs(copy) do h(...) end
    end
    return e
end

--- Runs `n` game ticks, advancing the fake clock by `ms` (default 100) each.
function Stubs.tick(n, ms)
    for _ = 1, n do
        Stubs.now = Stubs.now + (ms or 100)
        Events.OnTick.fire()
    end
end

--- Resets the fake world and installs the globals.
function Stubs.reset()
    Stubs.now = 0
    Stubs.unloaded = nil
    Events = { OnTick = event(), OnNewGame = event(), OnMainMenuEnter = event() }
    getTimestampMs = function() return Stubs.now end
    isClient = function() return false end
    isServer = function() return false end
    Stubs.spawned = {}
    Stubs.scripts = {}
    Stubs.makeVehicle = function(fullType) return Stubs.vehicle(fullType, {}) end
    Stubs.blocked = {}
    Stubs.files = Stubs.files or {}
    VehicleUtils = {
        callLua = function(name, vehicle, part, item)
            table.insert(part.log, name .. ":" .. (item and item.fullType or "-"))
        end,
    }
    instanceItem = function(t)
        if t == "Base.Missing" then return nil end
        return Stubs.item(t)
    end
    instanceof = function(obj, class)
        return class == "DrainableComboItem" and obj and obj.drainable == true
    end
    IsoDirections = { N = "N", E = "E", S = "S", W = "W" }
    Vector3f = { new = function() return {} end }
    IsoFlagType = { collideN = "collideN", collideW = "collideW" }
    getScriptManager = function()
        return { getVehicle = function(_, name) return Stubs.scripts[name] end }
    end
    getCell = function()
        return {
            getGridSquare = function(_, x, y, z)
                if Stubs.unloaded and Stubs.unloaded(x, y) then
                    return nil
                end
                local key = x .. "," .. y
                local blocked = Stubs.blocked[key]
                return {
                    x = x, y = y,
                    getFloor = function() return { getSprite = function() return { getName = function() return "grass" end } end } end,
                    getRoom = function() return nil end,
                    getBuilding = function() return nil end,
                    isSolid = function() return blocked == true end,
                    isSolidTrans = function() return false end,
                    HasTree = function() return false end,
                    isWaterSquare = function() return false end,
                    hasWater = function() return false end,
                    getVehicleContainer = function() return nil end,
                    has = function() return false end,
                    isFree = function() return not blocked end,
                }
            end,
        }
    end
    addVehicleDebug = function(fullType, dir, skin, sq)
        local v = Stubs.makeVehicle(fullType)
        v.spawnedAt = { x = sq.x, y = sq.y, dir = dir }
        table.insert(Stubs.spawned, v)
        return v
    end
    getFileReader = function(name)
        local lines = Stubs.files[name]
        if not lines then return nil end
        local i = 0
        return { readLine = function() i = i + 1 return lines[i] end, close = function() end }
    end
    getFileWriter = function(name)
        local buffer = {}
        return {
            write = function(_, text) table.insert(buffer, text) end,
            close = function()
                local lines = {}
                for line in string.gmatch(table.concat(buffer), "([^\n]*)\n") do
                    table.insert(lines, line)
                end
                Stubs.files[name] = lines
            end,
        }
    end
end

--- Returns a fake player with an inventory at (x, y); tests may move it by
--- setting pos.x/pos.y or sit it in a vehicle by setting `vehicle`.
function Stubs.player(x, y)
    local inv = Stubs.container()
    local p = { inv = inv, pos = { x = x, y = y, z = 0 }, vehicle = nil, dead = false }
    function p:getInventory() return self.inv end
    function p:getX() return self.pos.x end
    function p:getY() return self.pos.y end
    function p:getZ() return self.pos.z end
    function p:getVehicle() return self.vehicle end
    function p:isDead() return self.dead end
    return p
end

return Stubs
