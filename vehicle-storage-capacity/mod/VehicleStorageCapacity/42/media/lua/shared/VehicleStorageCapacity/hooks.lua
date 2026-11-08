--- Event wiring shared by single player, the multiplayer server and clients.
--- Every side runs the same deterministic rule, so they agree without sending
--- anything: the game's part packets make clients recompute capacity on
--- their own, and mod data packets do not carry it.
local Settings = require "VehicleStorageCapacity/settings"
local Vehicles = require "VehicleStorageCapacity/vehicles"

local TAG = "[VehicleStorageCapacity] "

--- Resizes every loaded vehicle's storage and logs when anything changed.
local function sweep()
    local parts, vehicles = Vehicles.applyLoaded(Settings.current(), Vehicles.printReport)
    if parts > 0 then
        print(TAG .. "resized " .. parts .. " containers on " .. vehicles .. " vehicles")
    end
end

--- Logs the active settings, then resizes what is already loaded.
local function onStart()
    print(TAG .. "active: " .. Settings.describe(Settings.current()))
    sweep()
end

--- Resizes the vehicle a player just got into, before they open its seats.
local function onEnterVehicle(player)
    local vehicle = player and player:getVehicle()
    if vehicle then
        Vehicles.applyVehicle(vehicle, Settings.current(), Vehicles.printReport)
    end
end

Events.OnGameStart.Add(onStart)
Events.OnServerStarted.Add(onStart)
Events.EveryOneMinute.Add(sweep)
Events.OnEnterVehicle.Add(onEnterVehicle)
