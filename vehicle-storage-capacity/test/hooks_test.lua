--- Loads the real event files against the fake game and fires their events.
local Fake = require("fake-game")
local ROOT = TEST_ROOT .. "/mod/VehicleStorageCapacity/42/media/lua/"

--- Runs fn with print captured; returns the captured lines.
local function capture(fn)
    local lines, saved = {}, print
    print = function(text) lines[#lines + 1] = tostring(text) end
    local okay, err = pcall(fn)
    print = saved
    if not okay then error(err, 2) end
    return lines
end

--- Builds a car with a 50-capacity trunk at x, y.
local function car(x, y)
    local trunk = Fake.part({ id = "TruckBed", itemTypes = { "Base.NormalTrunk" } })
    local vehicle = Fake.vehicle("Base.CarNormal", { trunk }, { x = x, y = y })
    Fake.spawnItem(trunk, "Base.NormalTrunk", 50)
    return vehicle, trunk
end

test("hooks: registers its events", function()
    local game = Fake.install({}, {})
    freshModules()
    dofile(ROOT .. "shared/VehicleStorageCapacity/hooks.lua")
    dofile(ROOT .. "client/VehicleStorageCapacity/inventory-refresh.lua")
    eq(game.count("OnGameStart"), 1, "OnGameStart")
    eq(game.count("OnServerStarted"), 1, "OnServerStarted")
    eq(game.count("EveryOneMinute"), 1, "EveryOneMinute")
    eq(game.count("OnEnterVehicle"), 1, "OnEnterVehicle")
    eq(game.count("OnRefreshInventoryWindowContainers"), 1, "loot refresh")
end)

test("hooks: game start logs settings and the minute sweep resizes loaded vehicles", function()
    local vehicle, trunk = car(0, 0)
    local game = Fake.install({}, { TrunkPercent = 300 })
    freshModules()
    dofile(ROOT .. "shared/VehicleStorageCapacity/hooks.lua")
    local lines = capture(function() game.fire("OnGameStart") end)
    ok(string.find(lines[1], "active: trunks 300", 1, true), lines[1])
    game.cell.list.values[1] = vehicle
    lines = capture(function() game.fire("EveryOneMinute") end)
    eq(trunk:getContainerCapacity(), 150, "tripled")
    eq(lines[1], "[VehicleStorageCapacity] Base.CarNormal: TruckBed 50 -> 150", "per-vehicle line")
    eq(lines[2], "[VehicleStorageCapacity] resized 1 containers on 1 vehicles", "summary")
    lines = capture(function() game.fire("EveryOneMinute") end)
    eq(#lines, 0, "quiet when nothing changed")
end)

test("hooks: entering a vehicle resizes it", function()
    local vehicle, trunk = car(500, 500)
    local game = Fake.install({}, { TrunkPercent = 200 })
    freshModules()
    dofile(ROOT .. "shared/VehicleStorageCapacity/hooks.lua")
    local lines = capture(function() game.fire("OnEnterVehicle", Fake.player(500, 500, vehicle)) end)
    eq(trunk:getContainerCapacity(), 100, "doubled")
    eq(lines[1], "[VehicleStorageCapacity] Base.CarNormal: TruckBed 50 -> 100", "logged")
end)

test("hooks: the loot window resizes nearby vehicles at begin only", function()
    local near, nearTrunk = car(102, 100)
    local far, farTrunk = car(140, 100)
    local game = Fake.install({ near, far }, { TrunkPercent = 200 })
    local player = Fake.player(100, 100)
    _G.getSpecificPlayer = function(index) return index == 0 and player or nil end
    freshModules()
    dofile(ROOT .. "client/VehicleStorageCapacity/inventory-refresh.lua")
    game.fire("OnRefreshInventoryWindowContainers", { player = 0, onCharacter = false }, "end")
    eq(nearTrunk:getContainerCapacity(), 50, "ignored at end")
    game.fire("OnRefreshInventoryWindowContainers", { player = 0, onCharacter = true }, "begin")
    eq(nearTrunk:getContainerCapacity(), 50, "ignored for the character panel")
    local lines = capture(function()
        game.fire("OnRefreshInventoryWindowContainers", { player = 0, onCharacter = false }, "begin")
    end)
    eq(nearTrunk:getContainerCapacity(), 100, "near doubled")
    eq(#lines, 1, "one vehicle logged")
    lines = capture(function()
        game.fire("OnRefreshInventoryWindowContainers", { player = 0, onCharacter = false }, "begin")
    end)
    eq(#lines, 0, "quiet on the next refresh")
    eq(farTrunk:getContainerCapacity(), 50, "far left for the sweep")
    _G.getSpecificPlayer = nil
end)
