--- End to end through the runtime: claim a house, rearrange it, save it,
--- then start a "new game" with the same map and apply the blueprint, both
--- right away and as distant squares load.
local Fake = require("fake-game")

--- Builds the same small house in a fresh world: 4x3 rooms at 10,10 with a
--- floor everywhere, a wall row, a couch, a fridge with loot and a door.
local function buildHouse(keepFiles)
    local world = Fake.newWorld({ keepFiles = keepFiles })
    world.spriteFlags["appliances_refrigeration_01_0"] = { container = "fridge" }
    world.spriteFlags["carpentry_01_16"] = { container = "crate" }
    Fake.building(world, 10, 10, 4, 3, 0)
    for x = 9, 14 do
        for y = 9, 13 do
            world.put(x, y, 0, "IsoObject", "floors_interior_tilesandwood_01_0", { floor = true })
        end
    end
    for x = 10, 13 do
        world.put(x, 10, 0, "IsoObject", "walls_interior_house_01_1")
    end
    world.put(11, 11, 0, "IsoObject", "furniture_seating_indoor_01_0")
    local fridge = world.put(12, 11, 0, "IsoObject", "appliances_refrigeration_01_0")
    fridge.containers[1]:AddItems("Base.Milk", 1)
    world.put(10, 12, 0, "IsoDoor", "fixtures_doors_01_0", { north = true })
    freshModules()
    return world, require("BaseBlueprints/runtime")
end

--- Returns the sprite names on a square, in order.
local function names(world, x, y, z)
    local out = {}
    for i, o in ipairs(world.square(x, y, z).objects) do
        out[i] = o.sprite.name
    end
    return table.concat(out, " ")
end

--- Rearranges the claimed house: moves the couch, changes a floor, knocks
--- out a wall, opens the door, adds a crate with tools.
local function remodel(world)
    local sq = world.square(11, 11, 0)
    sq:RemoveTileObject(sq.objects[2])
    world.put(13, 12, 0, "IsoObject", "furniture_seating_indoor_01_0")
    world.square(12, 12, 0).objects[1]:setSprite(world.sprite("floors_interior_carpet_01_0"))
    local wallSq = world.square(12, 10, 0)
    wallSq:RemoveTileObject(wallSq.objects[2])
    world.square(10, 12, 0).objects[2]:setSprite(world.sprite("fixtures_doors_01_2"))
    local crate = world.put(11, 12, 0, "IsoThumpable", "carpentry_01_16")
    crate.containers[1]:AddItems("Base.Hammer", 1)
end

test("runtime: claim records the house and finds exactly the changed tiles", function()
    local world, Runtime = buildHouse()
    local okay = Runtime.claimBuilding(world.square(11, 11, 0), 1)
    ok(okay, "claimed")
    local claim = Runtime.claim()
    eq(claim.area.x1, 9)
    eq(claim.area.x2, 14)
    eq(claim.area.z2, 1)
    eq(#Runtime.findChanges().keys, 0, "nothing changed yet")
    remodel(world)
    local keys = Runtime.findChanges().keys
    eq(table.concat(keys, " "), "12,10,0 11,11,0 11,12,0 12,12,0 13,12,0", "opened door not a change")
end)

test("runtime: claim refuses squares outside buildings and unloaded maps", function()
    local world, Runtime = buildHouse()
    local okay = Runtime.claimBuilding(world.square(30, 30, 0), 1)
    ok(not okay)
    world.setLoaded(14, 13, false)
    okay = Runtime.claimBuilding(world.square(11, 11, 0), 1)
    ok(not okay, "part not loaded")
    eq(Runtime.claim(), nil)
end)

test("runtime: save, then apply in a new game rebuilds the remodel", function()
    local world, Runtime = buildHouse()
    Runtime.claimBuilding(world.square(11, 11, 0), 1)
    remodel(world)
    local entry = Runtime.save("Riverside", {})
    ok(entry, "saved")
    eq(entry.squares, 5)
    eq(entry.contents, false, "no contents by default")
    ok(Fake.files["BaseBlueprints_index.txt"])
    ok(Fake.files["BaseBlueprints_" .. entry.id .. ".txt"])
    local before = {}
    for _, key in ipairs({ "11,11,0", "12,10,0", "11,12,0", "12,12,0", "13,12,0" }) do
        local x, y, z = key:match("(%d+),(%d+),(%d+)")
        before[key] = names(world, tonumber(x), tonumber(y), tonumber(z))
    end

    local fresh, Runtime2 = buildHouse(true)
    local fridge = fresh.square(12, 11, 0).objects[2]
    local okay = Runtime2.apply(entry.id, false)
    ok(okay)
    for key, expected in pairs(before) do
        local x, y, z = key:match("(%d+),(%d+),(%d+)")
        eq(names(fresh, tonumber(x), tonumber(y), tonumber(z)), expected, key)
    end
    eq(names(fresh, 10, 12, 0), "floors_interior_tilesandwood_01_0 fixtures_doors_01_0", "door untouched")
    eq(fresh.square(12, 11, 0).objects[2], fridge, "fridge kept with its loot")
    eq(#fresh.square(11, 12, 0).objects[2].containers[1].items, 0, "new crate is empty")
    local run = Runtime2.state().runs[entry.id]
    eq(run.done, 5)
    eq(run.added, 3, "couch, crate and carpet; nothing for the wall")
    eq(run.removed, 2, "old couch and the wall")

    -- Applying again changes nothing.
    Runtime2.apply(entry.id, false)
    eq(Runtime2.state().runs[entry.id].added, 0)
    eq(Runtime2.state().runs[entry.id].removed, 0)
end)

test("runtime: contents come along only when saved and chosen", function()
    local world, Runtime = buildHouse()
    Runtime.claimBuilding(world.square(11, 11, 0), 1)
    remodel(world)
    local entry = Runtime.save("Stocked", { contents = true })
    eq(entry.contents, true)
    local fresh, Runtime2 = buildHouse(true)
    Runtime2.apply(entry.id, false)
    eq(#fresh.square(11, 12, 0).objects[2].containers[1].items, 0, "not chosen")
    local again, Runtime3 = buildHouse(true)
    Runtime3.apply(entry.id, true)
    eq(again.square(11, 12, 0).objects[2].containers[1].items[1], "Base.Hammer")
end)

test("runtime: distant squares wait until their map loads", function()
    local world, Runtime = buildHouse()
    Runtime.claimBuilding(world.square(11, 11, 0), 1)
    remodel(world)
    local entry = Runtime.save("Far", {})
    local fresh, Runtime2 = buildHouse(true)
    fresh.setLoaded(13, 12, false)
    fresh.setLoaded(12, 12, false)
    local _, message = Runtime2.apply(entry.id, false)
    ok(string.find(message, "UI_BBP_ApplyingLater"), message)
    eq(#Runtime2.state().columns["13,12"], 1)
    fresh.setLoaded(13, 12, true)
    Runtime2.onLoadGridsquare(fresh.square(13, 12, 0))
    Runtime2.onTick()
    eq(names(fresh, 13, 12, 0), "floors_interior_tilesandwood_01_0 furniture_seating_indoor_01_0")
    eq(Runtime2.state().columns["13,12"], nil)
    eq(Runtime2.state().runs[entry.id].done, 4)
    fresh.setLoaded(12, 12, true)
    Runtime2.processLoaded()
    eq(Runtime2.state().runs[entry.id].done, 5)
end)

test("runtime: every-tile saves, same-name replace, delete and auto-apply", function()
    local world, Runtime = buildHouse()
    Runtime.claimBuilding(world.square(11, 11, 0), 1)
    eq((Runtime.save("Home", {})), nil, "nothing changed yet")
    local whole = Runtime.save("Home", { everyTile = true })
    eq(whole.squares, 6 * 5 * 2, "every square, roof level included")
    remodel(world)
    local again = Runtime.save("home", {})
    eq(again.id, whole.id, "same name replaces")
    eq(#Runtime.entries(), 1)
    Runtime.setFlag(again.id, "auto", true)

    local fresh, Runtime2 = buildHouse(true)
    Runtime2.applyAuto()
    eq(names(fresh, 13, 12, 0), "floors_interior_tilesandwood_01_0 furniture_seating_indoor_01_0")
    Runtime2.delete(again.id)
    eq(#Runtime2.entries(), 0)
    eq((Runtime2.load(again.id)), nil)
end)
