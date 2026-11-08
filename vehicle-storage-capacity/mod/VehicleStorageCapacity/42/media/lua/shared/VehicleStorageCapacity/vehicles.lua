--- Game adapter: reads live vehicle parts, runs the pure capacity rule and
--- writes the result. Works on any vehicle the game loads, so vanilla, KI5
--- and other mods' vehicles need no list.
local Classify = require "VehicleStorageCapacity/classify"
local Capacity = require "VehicleStorageCapacity/capacity"

local Vehicles = {}

Vehicles.KEY_BASE = "VehicleStorageCapacity_base"
Vehicles.KEY_APPLIED = "VehicleStorageCapacity_applied"
Vehicles.KEY_ITEM = "VehicleStorageCapacity_item"

local trailerCache = {}
local categoryCache = {}

--- Forgets cached trailer and category lookups (used by tests).
function Vehicles.resetCaches()
    trailerCache = {}
    categoryCache = {}
end

--- Returns the record this mod saved in a part's mod data, or nil.
function Vehicles.readRecord(modData)
    local base = modData[Vehicles.KEY_BASE]
    if base == nil then
        return nil
    end
    return { base = base, applied = modData[Vehicles.KEY_APPLIED], item = modData[Vehicles.KEY_ITEM] }
end

--- Saves or clears the record in a part's mod data, writing only what changed.
function Vehicles.writeRecord(modData, record)
    local base = record and record.base
    local applied = record and record.applied
    local item = record and record.item
    if modData[Vehicles.KEY_BASE] ~= base then
        modData[Vehicles.KEY_BASE] = base
    end
    if modData[Vehicles.KEY_APPLIED] ~= applied then
        modData[Vehicles.KEY_APPLIED] = applied
    end
    if modData[Vehicles.KEY_ITEM] ~= item then
        modData[Vehicles.KEY_ITEM] = item
    end
end

--- Copies a Java list of strings into a Lua list.
local function toList(javaList)
    local list = {}
    if javaList then
        for i = 0, javaList:size() - 1 do
            list[#list + 1] = javaList:get(i)
        end
    end
    return list
end

--- Returns true when the vehicle is a trailer or camper (cached per script).
function Vehicles.isTrailer(vehicle)
    local name = vehicle:getScriptName() or ""
    local cached = trailerCache[name]
    if cached == nil then
        cached = Classify.isTrailer(name, vehicle:getPartById("Engine") ~= nil)
        trailerCache[name] = cached
    end
    return cached
end

--- Returns the sandbox category of a part (cached per script and part id).
local function categoryOf(part, scriptName, trailer)
    local key = scriptName .. "|" .. tostring(part:getId())
    local cached = categoryCache[key]
    if cached == nil then
        cached = Classify.category({
            id = part:getId(),
            seatNumber = part:getContainerSeatNumber(),
            itemTypes = toList(part:getItemType()),
        }, trailer)
        categoryCache[key] = cached
    end
    return cached
end

--- Returns true when the part holds a fluid (fuel, air, water) rather than items.
local function holdsFluid(part)
    local contentType = part:getContainerContentType()
    return contentType ~= nil and contentType ~= ""
end

--- Applies the settings to one part; returns true when its capacity changed and
--- appends "Part old -> new" to `changes` when given.
function Vehicles.applyPart(part, settings, scriptName, trailer, changes)
    local container = part:getItemContainer()
    if container == nil or holdsFluid(part) then
        return false
    end
    local itemTypes = part:getItemType()
    local item = part:getInventoryItem()
    local modData = part:getModData()
    local raw = container:getCapacity()
    local decision = Capacity.decide({
        raw = raw,
        percent = settings[categoryOf(part, scriptName, trailer)] or 100,
        occupiedSeat = container:isOccupiedVehicleSeat(),
        needsItem = itemTypes ~= nil and not itemTypes:isEmpty(),
        itemId = item and item:getID() or nil,
        record = Vehicles.readRecord(modData),
    })
    if decision.keep then
        return false
    end
    Vehicles.writeRecord(modData, decision.record)
    if decision.capacity then
        part:setContainerCapacity(decision.capacity)
        if changes then
            changes[#changes + 1] = tostring(part:getId()) .. " " .. tostring(raw) .. " -> " .. tostring(decision.capacity)
        end
        return true
    end
    return false
end

--- Applies the settings to every storage part of a vehicle; returns how many
--- changed. When `report` is given it is called with the script name and a
--- list of "Part old -> new" strings for a vehicle that changed.
function Vehicles.applyVehicle(vehicle, settings, report)
    local scriptName = vehicle:getScriptName() or ""
    local trailer = Vehicles.isTrailer(vehicle)
    local changes = report and {} or nil
    local changed = 0
    for i = 0, vehicle:getPartCount() - 1 do
        if Vehicles.applyPart(vehicle:getPartByIndex(i), settings, scriptName, trailer, changes) then
            changed = changed + 1
        end
    end
    if report and changed > 0 then
        report(scriptName, changes)
    end
    return changed
end

--- Calls fn with each loaded vehicle. IsoCell.getVehicles is a java.util.Set in
--- 42.21, so it is walked with its iterator; it has no get(i).
local function eachLoadedVehicle(fn)
    local cell = getCell and getCell()
    local set = cell and cell:getVehicles()
    if set == nil then
        return
    end
    local iterator = set:iterator()
    while iterator:hasNext() do
        fn(iterator:next())
    end
end

--- Applies the settings to every loaded vehicle; returns parts and vehicles changed.
function Vehicles.applyLoaded(settings, report)
    local parts, vehicles = 0, 0
    eachLoadedVehicle(function(vehicle)
        local changed = Vehicles.applyVehicle(vehicle, settings, report)
        if changed > 0 then
            parts = parts + changed
            vehicles = vehicles + 1
        end
    end)
    return parts, vehicles
end

--- Applies the settings to the player's vehicle and vehicles within radius tiles.
function Vehicles.applyNear(player, settings, radius, report)
    local parts = 0
    local own = player:getVehicle()
    if own then
        parts = parts + Vehicles.applyVehicle(own, settings, report)
    end
    local px, py, limit = player:getX(), player:getY(), radius * radius
    eachLoadedVehicle(function(vehicle)
        local dx, dy = vehicle:getX() - px, vehicle:getY() - py
        if vehicle ~= own and dx * dx + dy * dy <= limit then
            parts = parts + Vehicles.applyVehicle(vehicle, settings, report)
        end
    end)
    return parts
end

--- Returns the console line for one resized vehicle.
function Vehicles.reportLine(scriptName, changes)
    return "[VehicleStorageCapacity] " .. scriptName .. ": " .. table.concat(changes, ", ")
end

--- Prints one resized vehicle to the console.
function Vehicles.printReport(scriptName, changes)
    print(Vehicles.reportLine(scriptName, changes))
end

return Vehicles
