--- A small stand-in for the game's vehicle classes. It copies the engine
--- behavior this mod depends on, read from the 42.21 jar:
--- - VehiclePart.doInventoryItemStats sets the container capacity from the
---   installed item's max capacity (condition-scaled when the script says
---   so), or from the script's capacity when nothing is installed;
--- - ItemContainer.getCapacity divides an occupied seat by 4 and caps
---   vehicle containers at 1000;
--- - VehicleUtils.createPartInventoryItem copies the part's capacity into a
---   newly spawned part item when it is above 0;
--- - the capacity and part mod data are saved with the vehicle.
local Fake = {}

local nextItemId = 1000

--- Wraps a Lua list in the Java ArrayList methods the mod calls.
function Fake.list(values)
    local list = { values = values or {} }
    --- Returns the list size.
    function list:size() return #self.values end
    --- Returns the element at a zero-based index.
    function list:get(i) return self.values[i + 1] end
    --- Returns true when the list has no elements.
    function list:isEmpty() return #self.values == 0 end
    return list
end

--- Copies the engine's VehiclePart.getNumberByCondition.
function Fake.byCondition(number, condition, minimum)
    condition = condition + 20 * (100 - condition) / 100
    local value = math.max(minimum, number * (condition / 100))
    return math.floor(value * 100 + 0.5) / 100
end

--- Makes an inventory item with an id, a max capacity and a condition.
function Fake.item(fullType, maxCapacity, condition)
    nextItemId = nextItemId + 1
    local item = { id = nextItemId, fullType = fullType, maxCapacity = maxCapacity or -1, condition = condition or 100 }
    --- Returns the item's unique id.
    function item:getID() return self.id end
    --- Returns the item's max capacity stat.
    function item:getMaxCapacity() return self.maxCapacity end
    --- Sets the item's max capacity stat.
    function item:setMaxCapacity(value) self.maxCapacity = value end
    --- Returns the item's condition.
    function item:getCondition() return self.condition end
    return item
end

--- Makes a vehicle part from a spec: id, seat, itemTypes, contentType,
--- scriptCapacity, conditionAffects, item.
function Fake.part(spec)
    local part = {
        spec = spec,
        id = spec.id,
        seat = spec.seat or -1,
        itemTypes = spec.itemTypes and Fake.list(spec.itemTypes) or nil,
        contentType = spec.contentType,
        modData = {},
        condition = spec.condition or 100,
        item = nil,
        setCalls = 0,
    }
    if not spec.contentType then
        part.container = { capacity = 0 }
        local container = part.container
        --- Returns the capacity the way ItemContainer.getCapacity does.
        function container.getCapacity(self)
            local value = self.capacity
            if self:isOccupiedVehicleSeat() then
                value = math.floor(value / 4)
            end
            return math.min(value, 1000)
        end
        --- Returns true when someone sits in the seat this container belongs to.
        function container.isOccupiedVehicleSeat()
            return part.seat >= 0 and part.vehicle ~= nil and part.vehicle:getCharacter(part.seat) ~= nil
        end
    end
    --- Returns the part id.
    function part:getId() return self.id end
    --- Returns the seat index, or -1.
    function part:getContainerSeatNumber() return self.seat end
    --- Returns the installable item types, or nil.
    function part:getItemType() return self.itemTypes end
    --- Returns the fluid type, or nil for item storage.
    function part:getContainerContentType() return self.contentType end
    --- Returns the item container, or nil for fluid parts.
    function part:getItemContainer() return self.container end
    --- Returns the installed item, or nil.
    function part:getInventoryItem() return self.item end
    --- Returns the part's mod data table.
    function part:getModData() return self.modData end
    --- Returns the part's condition.
    function part:getCondition() return self.condition end
    --- Sets the raw container capacity, like VehiclePart.setContainerCapacity.
    function part:setContainerCapacity(value)
        self.setCalls = self.setCalls + 1
        if self.container then
            self.container.capacity = value
        end
    end
    --- Returns the capacity the way VehiclePart.getContainerCapacity(nil) does.
    function part:getContainerCapacity()
        return self.container and self.container:getCapacity() or 0
    end
    --- Installs or removes an item, recomputing capacity like doInventoryItemStats.
    function part:setInventoryItem(item)
        self.item = item
        if not self.container then
            return
        end
        if item then
            if item.maxCapacity > 0 then
                if self.spec.conditionAffects then
                    self.container.capacity = math.floor(Fake.byCondition(item.maxCapacity, item.condition, 5))
                else
                    self.container.capacity = item.maxCapacity
                end
            end
            self.condition = item.condition
        elseif (self.spec.scriptCapacity or 0) > 0 then
            self.container.capacity = self.spec.scriptCapacity
        else
            self.container.capacity = 0
        end
    end
    part:setInventoryItem(nil)
    return part
end

--- Spawns the part's item like vanilla createPartInventoryItem, then installs it.
function Fake.spawnItem(part, fullType, itemMaxCapacity, condition)
    local item = Fake.item(fullType, itemMaxCapacity, condition)
    local shown = part:getContainerCapacity()
    if shown > 0 then
        item:setMaxCapacity(shown)
    end
    part:setInventoryItem(item)
    return item
end

--- Makes a vehicle from a script name and parts; opts: engine (default true), x, y.
function Fake.vehicle(scriptName, parts, opts)
    opts = opts or {}
    local vehicle = { scriptName = scriptName, parts = parts, seats = {}, x = opts.x or 0, y = opts.y or 0 }
    if opts.engine ~= false then
        vehicle.engine = Fake.part({ id = "Engine", contentType = "engine-stand-in" })
    end
    for _, part in ipairs(parts) do
        part.vehicle = vehicle
    end
    --- Returns the vehicle script name.
    function vehicle:getScriptName() return self.scriptName end
    --- Returns a part by id, or nil.
    function vehicle:getPartById(id)
        if id == "Engine" then
            return self.engine
        end
        for _, part in ipairs(self.parts) do
            if part.id == id then
                return part
            end
        end
        return nil
    end
    --- Returns the number of parts.
    function vehicle:getPartCount() return #self.parts end
    --- Returns a part by zero-based index.
    function vehicle:getPartByIndex(i) return self.parts[i + 1] end
    --- Returns who sits in a seat, or nil.
    function vehicle:getCharacter(seat) return self.seats[seat] end
    --- Returns the x coordinate.
    function vehicle:getX() return self.x end
    --- Returns the y coordinate.
    function vehicle:getY() return self.y end
    return vehicle
end

--- Copies a vehicle the way saving and loading does: raw capacity, item stats and mod data.
function Fake.reload(vehicle)
    local parts = {}
    for _, old in ipairs(vehicle.parts) do
        local part = Fake.part(old.spec)
        part.item = old.item
        part.condition = old.condition
        if part.container then
            part.container.capacity = old.container.capacity
        end
        for k, v in pairs(old.modData) do
            part.modData[k] = v
        end
        parts[#parts + 1] = part
    end
    return Fake.vehicle(vehicle.scriptName, parts, { engine = vehicle.engine ~= nil, x = vehicle.x, y = vehicle.y })
end

--- Makes a player standing at x, y, optionally inside a vehicle.
function Fake.player(x, y, vehicle)
    local player = { x = x, y = y, vehicle = vehicle }
    --- Returns the vehicle the player is in, or nil.
    function player:getVehicle() return self.vehicle end
    --- Returns the x coordinate.
    function player:getX() return self.x end
    --- Returns the y coordinate.
    function player:getY() return self.y end
    return player
end

--- Wraps a Lua list in the Java Set methods the game exposes. IsoCell.getVehicles
--- returns a java.util.Set in 42.21: no get(i), only iterator(), size() and contains().
function Fake.set(values)
    local set = { values = values or {} }
    --- Returns the set size.
    function set:size() return #self.values end
    --- Returns true when the set holds the value.
    function set:contains(value)
        for _, v in ipairs(self.values) do
            if v == value then return true end
        end
        return false
    end
    --- Returns a Java-style iterator over a snapshot of the values.
    function set:iterator()
        local snapshot, i = { unpack(self.values) }, 0
        return {
            --- Returns true while values remain.
            hasNext = function() return i < #snapshot end,
            --- Returns the next value.
            next = function() i = i + 1; return snapshot[i] end,
        }
    end
    return set
end

--- Installs fake game globals: getCell with the given vehicles, SandboxVars and Events.
function Fake.install(vehicles, sandbox)
    local cell = { list = Fake.set(vehicles or {}) }
    --- Returns the loaded vehicles as a Set, like IsoCell.getVehicles.
    function cell:getVehicles() return self.list end
    _G.getCell = function() return cell end
    _G.SandboxVars = { VehicleStorageCapacity = sandbox }
    local handlers = {}
    _G.Events = setmetatable({}, {
        __index = function(events, name)
            local event = {
                --- Registers a handler.
                Add = function(fn)
                    handlers[name] = handlers[name] or {}
                    table.insert(handlers[name], fn)
                end,
            }
            rawset(events, name, event)
            return event
        end,
    })
    return {
        cell = cell,
        --- Fires every handler registered for an event.
        fire = function(name, ...)
            for _, fn in ipairs(handlers[name] or {}) do
                fn(...)
            end
        end,
        --- Returns how many handlers an event has.
        count = function(name)
            return #(handlers[name] or {})
        end,
    }
end

return Fake
