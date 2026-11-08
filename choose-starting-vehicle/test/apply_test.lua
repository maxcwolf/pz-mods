package.path = TEST_ROOT .. "/test/harness/?.lua;" .. package.path
local Stubs = require("pz-stubs")
local Build = require("ChooseStartingVehicle/build")
local Plan = require("ChooseStartingVehicle/plan")
local Settings = require("ChooseStartingVehicle/settings")
Stubs.reset()
require("ChooseStartingVehicle/apply")

local HOOKS = { install = { complete = "KI5.Install" }, uninstall = { complete = "KI5.Uninstall" } }

--- A Defender-like car: a bumper add-on, a tire, a door, a tank, a battery, containers.
local function car()
    return Stubs.vehicle("Base.Car", {
        Stubs.part("DAMNBumperFront", { item = Stubs.item("Base.Bumper"), install = HOOKS.install, uninstall = HOOKS.uninstall, itemTypes = { "Base.Bumper", "Base.Bullbar" } }),
        Stubs.part("TireFrontLeft", { item = Stubs.item("Base.Tire"), wheel = 0, capacity = 35, container = true, itemTypes = { "Base.Tire" } }),
        Stubs.part("DoorFrontLeft", { item = Stubs.item("Base.Door"), door = true, itemTypes = { "Base.Door" } }),
        Stubs.part("GasTank", { item = Stubs.item("Base.Tank"), capacity = 60, container = true, category = "gastank", itemTypes = { "Base.Tank" } }),
        Stubs.part("Battery", { item = Stubs.item("Base.CarBattery2"), itemTypes = { "Base.CarBattery" } }),
        Stubs.part("GloveBox", { item = Stubs.item("Base.GloveBox"), capacity = 5, container = true, itemTypes = { "Base.GloveBox" } }),
        Stubs.part("TruckBed", { capacity = 80, container = true }),
        Stubs.part("SeatFrontLeft", { item = Stubs.item("Base.Seat"), capacity = 20, container = true, category = "seat", itemTypes = { "Base.Seat" } }),
    })
end

test("install swaps the item and runs the uninstall then install hooks", function()
    Stubs.reset()
    local v = car()
    local part = v:getPartById("DAMNBumperFront")
    ok(CSV_Apply.install(v, part, "Base.Bullbar"), "installed")
    eq(part.item.fullType, "Base.Bullbar", "new item")
    listEq(part.log, { "KI5.Uninstall:Base.Bumper", "KI5.Install:-" }, "hooks")
end)

test("install leaves an identical item alone and reports missing items", function()
    Stubs.reset()
    local v = car()
    local part = v:getPartById("DAMNBumperFront")
    ok(CSV_Apply.install(v, part, "Base.Bumper"), "same item")
    eq(#part.log, 0, "no hooks")
    eq(CSV_Apply.install(v, part, "Base.Missing"), false, "missing item")
end)

test("parts removes None slots, counts missing parts and marks damnlib defaults", function()
    Stubs.reset()
    local v = car()
    local failed = CSV_Apply.parts(v, { { id = "DAMNBumperFront", remove = true }, { id = "Nope", itemType = "Base.X" } })
    eq(failed, 1, "missing part")
    eq(v:getPartById("DAMNBumperFront").item, nil, "removed")
    eq(v.modData.defaultPartSet_DAMNBumperFront, "true", "damn flag")
    eq(v.modData.defaultPartSet_TruckBed, "true", "every part flagged")
end)

test("condition sets parts, fills tires, unlocks doors and clears rust at 100", function()
    Stubs.reset()
    local v = car()
    CSV_Apply.condition(v, 100)
    eq(v:getPartById("Battery").condition, 100, "condition")
    eq(v:getPartById("TireFrontLeft").content, 35, "air")
    eq(v:getPartById("DoorFrontLeft").door.locked, false, "unlocked")
    eq(v.rust, 0, "rust")
    eq(v.alarmed, false, "alarm off")
end)

test("levels set fuel and battery", function()
    Stubs.reset()
    local v = car()
    CSV_Apply.levels(v, 0.5, 0.75)
    eq(v:getPartById("GasTank").content, 30, "fuel")
    eq(v:getPartById("Battery").item.usedDelta, 0.75, "battery")
end)

test("containers skip uninstalled parts and pick trunk and glove box", function()
    Stubs.reset()
    local v = car()
    table.insert(v.parts, Stubs.part("DAMNRoofrack", { capacity = 200, container = true, itemTypes = { "Base.Rack" } }))
    local list = CSV_Apply.containers(v)
    eq(Plan.pickTrunk(list), "TruckBed", "trunk ignores the empty roof rack slot")
    eq(Plan.pickGloveBox(list), "GloveBox", "glove box")
end)

test("key goes to the pocket or the glove box", function()
    Stubs.reset()
    local v = car()
    local player = Stubs.player(0, 0)
    CSV_Apply.key(v, player, true, "GloveBox")
    eq(#player.inv.items, 1, "pocket")
    CSV_Apply.key(v, player, false, "GloveBox")
    eq(#v:getPartById("GloveBox").itemContainer.items, 1, "glove box")
end)

test("spawn parks the car, dresses it, packs cargo and hitches the trailer", function()
    Stubs.reset()
    Stubs.scripts["Base.Car"] = Stubs.script("Base.Car", 1.8, 4.4, { trailer = -2.5 })
    Stubs.scripts["Base.TrailerCargo"] = Stubs.script("Base.TrailerCargo", 1.6, 3.0, { trailer = 2.0 })
    Stubs.makeVehicle = function(fullType)
        if fullType == "Base.Car" then
            return car()
        end
        return Stubs.vehicle(fullType, { Stubs.part("TrailerTrunk", { capacity = 100, container = true }) })
    end
    local build = Build.new("Base.Car")
    build.skin = 2
    build.parts.DAMNBumperFront = "Base.Bullbar"
    Build.addStack(build.trunk, "Base.Axe", 2)
    Build.addStack(build.glovebox, "Base.Lighter", 1)
    build.trailer = Build.newTrailer("Base.TrailerCargo")
    Build.addStack(build.trailer.cargo, "Base.Plank", 3)
    local settings = Settings.fromSandbox({ KeyInPocket = false })
    local player = Stubs.player(100, 100)
    local result = CSV_Apply.spawn(player, Plan.fromBuild(build, settings), settings)
    ok(result and result.vehicle and result.trailer, "both spawned")
    local v, t = result.vehicle, result.trailer
    eq(v.skin, 2, "paint")
    eq(v:getPartById("DAMNBumperFront").item.fullType, "Base.Bullbar", "bullbar")
    eq(#v:getPartById("TruckBed").itemContainer.items, 2, "trunk cargo")
    eq(#v:getPartById("GloveBox").itemContainer.items, 2, "glove box cargo plus key")
    eq(#player.inv.items, 0, "key not in pocket")
    eq(#t:getPartById("TrailerTrunk").itemContainer.items, 3, "trailer cargo")
    eq(#v.constraints, 1, "hitched")
    eq(v.constraints[1].a, "trailer", "car hitch")
    eq(v.constraints[1].b, "trailer", "trailer tongue")
    local dx = t.spawnedAt.x - v.spawnedAt.x
    local dy = t.spawnedAt.y - v.spawnedAt.y
    eq(math.abs(dx) + math.abs(dy), 5, "trailer 4.5 tiles back, rounded away to 5")
    eq(v.spawnedAt.dir, t.spawnedAt.dir, "same heading")
end)

test("spawn copies the car's angles to the trailer and skips a hitch that doesn't line up", function()
    Stubs.reset()
    Stubs.scripts["Base.Car"] = Stubs.script("Base.Car", 1.8, 4.4, { trailer = -2.5 })
    Stubs.scripts["Base.T"] = Stubs.script("Base.T", 1.6, 3.0, { trailer = 2.0 })
    Stubs.makeVehicle = function(fullType)
        local v = Stubs.vehicle(fullType, {})
        if fullType == "Base.Car" then
            v.angles = { 0, 97, 0 }
            v.canAttach = false
        end
        return v
    end
    local build = Build.new("Base.Car")
    build.trailer = Build.newTrailer("Base.T")
    local settings = Settings.fromSandbox(nil)
    local result = CSV_Apply.spawn(Stubs.player(50, 50), Plan.fromBuild(build, settings), settings)
    eq(result.trailer.angles[2], 97, "trailer yaw matches the car")
    eq(#result.vehicle.constraints, 0, "not hitched when canAttachTrailer says no")
end)

test("reapply leaves an unchanged vehicle alone and repairs a drifted one", function()
    Stubs.reset()
    local v = car()
    local plan = { condition = 100, fuel = 1, battery = 1, steps = { { id = "DAMNBumperFront", itemType = "Base.Bumper" } } }
    CSV_Apply.reapply({ vehicle = v }, plan)
    eq(v:getPartById("Battery").condition, 50, "untouched")
    plan.steps[1].itemType = "Base.Bullbar"
    CSV_Apply.reapply({ vehicle = v }, plan)
    eq(v:getPartById("DAMNBumperFront").item.fullType, "Base.Bullbar", "repaired")
    eq(v:getPartById("Battery").condition, 100, "condition redone")
end)

test("spawn gives up cleanly when the script is missing or there is no room", function()
    Stubs.reset()
    local settings = Settings.fromSandbox(nil)
    eq(CSV_Apply.spawn(Stubs.player(0, 0), Plan.fromBuild(Build.new("Base.Ghost"), settings), settings), nil, "no script")
    Stubs.scripts["Base.Car"] = Stubs.script("Base.Car", 1.8, 4.4, {})
    setmetatable(Stubs.blocked, { __index = function() return true end })
    eq(CSV_Apply.spawn(Stubs.player(0, 0), Plan.fromBuild(Build.new("Base.Car"), settings), settings), nil, "no room")
    eq(#Stubs.spawned, 0, "nothing spawned")
end)

test("trailerHitchId prefers the trailer's own trailer attachment", function()
    eq(CSV_Apply.trailerHitchId(Stubs.script("T", 1, 1, { trailer = 2, trailerfront = 1 })), "trailer", "both")
    eq(CSV_Apply.trailerHitchId(Stubs.script("T", 1, 1, { trailerfront = 1 })), "trailerfront", "front only")
    eq(CSV_Apply.trailerHitchId(Stubs.script("T", 1, 1, {})), nil, "none")
end)

test("reapply restores choices damnlib overwrote", function()
    Stubs.reset()
    local v = car()
    local plan = { condition = 100, fuel = 1, battery = 1, steps = { { id = "DAMNBumperFront", itemType = "Base.Bullbar" } } }
    CSV_Apply.reapply({ vehicle = v }, plan)
    eq(v:getPartById("DAMNBumperFront").item.fullType, "Base.Bullbar", "restored")
end)

test("key returns the key and where it went", function()
    Stubs.reset()
    local v = car()
    local player = Stubs.player(0, 0)
    local key, inPocket = CSV_Apply.key(v, player, true, "GloveBox")
    eq(key, player.inv.items[1], "pocket key returned")
    eq(inPocket, true, "in pocket")
    local boxKey, boxPocket = CSV_Apply.key(v, player, false, "GloveBox")
    eq(boxKey, v:getPartById("GloveBox").itemContainer.items[1], "glove box key returned")
    eq(boxPocket, false, "not in pocket")
end)

test("spawn remembers the pocket key and where the car landed", function()
    Stubs.reset()
    Stubs.scripts["Base.Car"] = Stubs.script("Base.Car", 1.8, 4.4, {})
    local settings = Settings.fromSandbox(nil)
    local player = Stubs.player(100, 100)
    local result = CSV_Apply.spawn(player, Plan.fromBuild(Build.new("Base.Car"), settings), settings)
    eq(result.key, player.inv.items[1], "pocket key kept")
    eq(result.x, result.vehicle:getX(), "car x")
    eq(result.y, result.vehicle:getY(), "car y")
end)

test("removeSpawn takes away the car, the trailer and the pocket key", function()
    Stubs.reset()
    local v, t = car(), Stubs.vehicle("Base.T", {})
    local player = Stubs.player(0, 0)
    local key = CSV_Apply.key(v, player, true, "GloveBox")
    local result = { vehicle = v, trailer = t, key = key }
    CSV_Apply.removeSpawn(result, player)
    ok(v.removed and t.removed, "both permanently removed")
    eq(#player.inv.items, 0, "key gone")
    ok(result.removed, "marked removed")
end)

test("removeSpawn finds the key in a bag and leaves a dropped key alone", function()
    Stubs.reset()
    local v = car()
    local player = Stubs.player(0, 0)
    local bag = Stubs.container()
    player.inv.bags = { bag }
    local key = v:createVehicleKey()
    bag:AddItem(key)
    CSV_Apply.removeSpawn({ vehicle = v, key = key }, player)
    eq(#bag.items, 0, "key taken from the bag")
    local dropped = v:createVehicleKey()
    CSV_Apply.removeSpawn({ vehicle = car(), key = dropped }, player)
    eq(dropped.container, nil, "dropped key untouched")
end)

test("reapply skips a spawn that was removed", function()
    Stubs.reset()
    local v = car()
    local plan = { condition = 100, fuel = 1, battery = 1, steps = { { id = "DAMNBumperFront", itemType = "Base.Bullbar" } } }
    CSV_Apply.reapply({ vehicle = v, removed = true }, plan)
    eq(v:getPartById("DAMNBumperFront").item.fullType, "Base.Bumper", "left alone")
end)
