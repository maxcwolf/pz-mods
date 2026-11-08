--- Resizes nearby vehicles right before the loot window lists their containers,
--- so a freshly loaded car or a just-installed trunk shows the right capacity
--- without waiting for the once-a-minute sweep.
local Settings = require "VehicleStorageCapacity/settings"
local Vehicles = require "VehicleStorageCapacity/vehicles"

--- Loot panels list containers within a few tiles; this covers them with room to spare.
local RADIUS = 6

--- Handles the loot window's refresh event at its "begin" stage.
local function onRefresh(page, state)
    if state ~= "begin" or page == nil or page.onCharacter then
        return
    end
    local player = getSpecificPlayer(page.player)
    if player then
        Vehicles.applyNear(player, Settings.current(), RADIUS, Vehicles.printReport)
    end
end

Events.OnRefreshInventoryWindowContainers.Add(onRefresh)
