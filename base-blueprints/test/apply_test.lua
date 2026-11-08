local Fake = require("fake-game")

--- Loads the apply and capture modules against a fresh fake world.
local function setup()
    local world = Fake.newWorld()
    freshModules()
    return world, require("BaseBlueprints/apply"), require("BaseBlueprints/capture"), require("BaseBlueprints/signature")
end

local function rec(cls, sprite, extra)
    local r = { cls = cls, sprite = sprite }
    for k, v in pairs(extra or {}) do
        r[k] = v
    end
    return r
end

test("apply: swaps a couch for a table and keeps the wall object itself", function()
    local world, Apply, Capture, Signature = setup()
    world.put(1, 1, 0, "IsoObject", "floor_wood_1", { floor = true })
    local wall = world.put(1, 1, 0, "IsoObject", "walls_interior_1")
    world.put(1, 1, 0, "IsoObject", "couch_1")
    local target = {
        rec("IsoObject", "floor_wood_1", { floor = true }),
        rec("IsoObject", "walls_interior_1"),
        rec("IsoObject", "table_1", { yOffset = 8 }),
    }
    local stats = Apply.square(1, 1, 0, target)
    eq(stats.removed, 1)
    eq(stats.added, 1)
    eq(stats.kept, 2)
    local sq = world.square(1, 1, 0)
    eq(sq.objects[2], wall, "same wall object")
    eq(sq.objects[3].sprite.name, "table_1")
    eq(sq.objects[3].yOffset, 8)
    eq(Signature.ofList((Capture.square(sq))), Signature.ofList(target))
    eq(#world.added, 1, "OnObjectAdded fired")
    ok(sq.recalcs > 0)
end)

test("apply: an unchanged square is not touched", function()
    local world, Apply = setup()
    world.put(1, 1, 0, "IsoObject", "floor_wood_1", { floor = true })
    local stats = Apply.square(1, 1, 0, { rec("IsoObject", "floor_wood_1", { floor = true }) })
    eq(stats.kept, 1)
    eq(world.square(1, 1, 0).recalcs, 0)
end)

test("apply: floors are replaced in place or added where missing", function()
    local world, Apply = setup()
    local floor = world.put(1, 1, 0, "IsoObject", "floor_wood_1", { floor = true })
    floor.attached = { "blends_street_01_1" }
    Apply.square(1, 1, 0, { rec("IsoObject", "floor_carpet_1", { floor = true }) })
    local sq = world.square(1, 1, 0)
    eq(sq.objects[1], floor, "same floor object")
    eq(floor.sprite.name, "floor_carpet_1")
    eq(#floor.attached, 0)
    world.setLoaded(5, 5, true)
    local stats = Apply.square(5, 5, 1, { rec("IsoObject", "floor_wood_2", { floor = true }), rec("IsoObject", "chair_1") })
    eq(stats.added, 2)
    local made = world.square(5, 5, 1)
    eq(made.objects[1].sprite.name, "floor_wood_2")
    eq(made.objects[2].sprite.name, "chair_1")
end)

test("apply: new objects go after the object before them in the blueprint", function()
    local world, Apply = setup()
    world.put(1, 1, 0, "IsoObject", "floor_1", { floor = true })
    world.put(1, 1, 0, "IsoObject", "wall_1")
    world.put(1, 1, 0, "IsoObject", "lamp_1")
    Apply.square(1, 1, 0, {
        rec("IsoObject", "floor_1", { floor = true }),
        rec("IsoObject", "wall_1"),
        rec("IsoObject", "wallpaper_1"),
        rec("IsoObject", "lamp_1"),
    })
    local names = {}
    for i, o in ipairs(world.square(1, 1, 0).objects) do
        names[i] = o.sprite.name
    end
    eq(table.concat(names, " "), "floor_1 wall_1 wallpaper_1 lamp_1")
end)

test("apply: doors, thumpables and contents are rebuilt; unknown tiles skipped", function()
    local world, Apply = setup()
    world.spriteFlags["carpentry_01_16"] = { container = "crate" }
    world.missing = { ["moddedtiles_01_0"] = true }
    world.setLoaded(2, 2, true)
    local stats = Apply.square(2, 2, 0, {
        rec("IsoDoor", "fixtures_doors_01_0", { north = true }),
        rec("IsoThumpable", "carpentry_01_16", { thump = { blockAll = true, maxHealth = 800, health = 650 }, name = "Tools",
            containers = { { type = "crate", items = { { t = "Base.Hammer", n = 2 }, { t = "MissingMod.Thing", n = 1 } } } } }),
        rec("IsoObject", "moddedtiles_01_0"),
        rec("IsoMultiMedia", "appliances_misc_01_20"),
    })
    eq(stats.added, 3)
    eq(stats.skipped, 1)
    ok(string.find(stats.problems[1], "moddedtiles_01_0"), "problem names the tile")
    local objs = world.square(2, 2, 0).objects
    eq(objs[1].cls, "IsoDoor")
    eq(objs[1].north, true)
    eq(objs[2].thump.health, 650)
    eq(objs[2].name, "Tools")
    eq(#objs[2].containers[1].items, 2, "known items only")
    ok(objs[2].containers[1].explored)
    eq(world.brushed, 1, "unexposed class placed by the game's brush")
end)

test("apply: an empty target clears recorded objects but not nature", function()
    local world, Apply = setup()
    world.put(4, 4, 0, "IsoObject", "trash_1")
    world.put(4, 4, 0, "IsoObject", "e_newgrass_1_1")
    local stats = Apply.square(4, 4, 0, {})
    eq(stats.removed, 1)
    eq(#world.square(4, 4, 0).objects, 1)
    world.setLoaded(9, 9, true)
    eq(Apply.square(9, 9, 0, {}).added, 0, "no square created for nothing")
    eq(world.squares["9,9,0"], nil)
end)
