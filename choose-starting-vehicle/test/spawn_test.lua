package.path = TEST_ROOT .. "/test/harness/?.lua;" .. package.path
local Stubs = require("pz-stubs")
local Build = require("ChooseStartingVehicle/build")
local Plan = require("ChooseStartingVehicle/plan")
local Settings = require("ChooseStartingVehicle/settings")
Stubs.reset()
CSV_State = CSV_State or {}
package.loaded["ChooseStartingVehicle/state"] = true
require("ChooseStartingVehicle/apply")
package.loaded["ChooseStartingVehicle/spawn"] = nil
require("ChooseStartingVehicle/spawn")

--- Sets up a fresh world with a car script and returns a plan, settings and player at (100, 100).
local function world()
    Stubs.reset()
    Stubs.scripts["Base.Car"] = Stubs.script("Base.Car", 1.8, 4.4, {})
    local settings = Settings.fromSandbox(nil)
    return Plan.fromBuild(Build.new("Base.Car"), settings), settings, Stubs.player(100, 100)
end

--- Counts the spawned vehicles not yet permanently removed.
local function live()
    local n = 0
    for _, v in ipairs(Stubs.spawned) do
        if not v.removed then n = n + 1 end
    end
    return n
end

test("spawn: the first spawn waits until the player's area is loaded", function()
    local plan, settings, player = world()
    Stubs.unloaded = function() return true end
    CSV_Spawn.run(player, plan, settings)
    Stubs.tick(10)
    eq(#Stubs.spawned, 0, "nothing while unloaded")
    Stubs.unloaded = nil
    Stubs.tick(1)
    eq(#Stubs.spawned, 1, "spawned once loaded")
end)

test("spawn: the first spawn tries anyway after the load timeout", function()
    local plan, settings, player = world()
    Stubs.unloaded = function(x, y) return x == 130 and y == 130 end
    CSV_Spawn.run(player, plan, settings)
    Stubs.tick(299)
    eq(#Stubs.spawned, 0, "still waiting at 29.9 s")
    Stubs.tick(2)
    eq(#Stubs.spawned, 1, "spawned after 30 s")
end)

test("spawn: a teleport moves the car and the key to the new spot", function()
    local plan, settings, player = world()
    CSV_Spawn.run(player, plan, settings)
    Stubs.tick(5)
    eq(#player.inv.items, 1, "one key")
    local first = Stubs.spawned[1]
    player.pos.x, player.pos.y = 5000, 7000
    Stubs.tick(30)
    eq(live(), 1, "one car in the world")
    ok(first.removed, "old car removed")
    local second = Stubs.spawned[2]
    ok(math.abs(second.spawnedAt.x - 5000) <= 30 and math.abs(second.spawnedAt.y - 7000) <= 30, "parked near the new spot")
    eq(#player.inv.items, 1, "still one key")
    eq(Stubs.spawned[2].scriptName, "Base.Car", "same build")
end)

test("spawn: a teleport into an area that never loads leaves the car", function()
    local plan, settings, player = world()
    CSV_Spawn.run(player, plan, settings)
    Stubs.tick(5)
    player.pos.x, player.pos.y = 5000, 7000
    Stubs.unloaded = function(x) return x > 1000 end
    Stubs.tick(400)
    eq(#Stubs.spawned, 1, "no second car")
    eq(Stubs.spawned[1].removed, nil, "old car kept")
    eq(#Events.OnTick.handlers, 0, "watch stopped")
end)

test("spawn: no follow once the player sat in the car", function()
    local plan, settings, player = world()
    CSV_Spawn.run(player, plan, settings)
    Stubs.tick(5)
    player.vehicle = Stubs.spawned[1]
    Stubs.tick(1)
    player.vehicle = nil
    player.pos.x, player.pos.y = 5000, 7000
    Stubs.tick(40)
    eq(#Stubs.spawned, 1, "not followed")
end)
