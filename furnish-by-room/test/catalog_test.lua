--- Building the per-room catalog: one card per piece, facings folded in,
--- grid tiles hidden, sorted; plus a check against the real tile list
--- when the fixture from scripts/dump-tiles.py is present.
local Catalog = require("FurnishByRoom/catalog")

--- Makes a fridge record for one facing.
local function fridge(index, facing)
    return { sprite = "appliances_refrigeration_01_" .. index, sheet = "appliances_refrigeration_01", index = index,
        group = "White", custom = "Fridge", facing = facing, moveable = true }
end

test("catalog: facings fold into one entry that shows south first", function()
    local c = Catalog.build({ fridge(0, "N"), fridge(1, "W"), fridge(2, "S"), fridge(3, "E") })
    local list = Catalog.entries(c, "kitchen")
    eq(#list, 1)
    eq(list[1].label, "White Fridge")
    eq(list[1].sprite, "appliances_refrigeration_01_2")
    eq(list[1].faces.N, "appliances_refrigeration_01_0")
    eq(list[1].cat, "appliances")
    eq(Catalog.count(c, "bar"), 1, "fridges also in the bar")
end)

test("catalog: grid tiles that are not the anchor are left out", function()
    local c = Catalog.build({
        { sprite = "furniture_bedding_01_0", sheet = "furniture_bedding_01", index = 0, custom = "Bed", facing = "S", moveable = true },
        { sprite = "furniture_bedding_01_1", sheet = "furniture_bedding_01", index = 1, custom = "Bed", facing = "S", moveable = true, anchor = false },
    })
    local list = Catalog.entries(c, "bedroom")
    eq(#list, 1)
    eq(list[1].sprite, "furniture_bedding_01_0")
end)

test("catalog: same-named floors share an entry; unnamed ones need a rule name", function()
    local c = Catalog.build({
        { sprite = "floors_interior_tilesandwood_01_11", sheet = "floors_interior_tilesandwood_01", index = 11, custom = "White Tiles", floor = true },
        { sprite = "floors_interior_tilesandwood_01_40", sheet = "floors_interior_tilesandwood_01", index = 40, custom = "White Tiles", floor = true },
        { sprite = "floors_interior_tilesandwood_01_56", sheet = "floors_interior_tilesandwood_01", index = 56, floor = true },
        { sprite = "floors_exterior_street_01_3", sheet = "floors_exterior_street_01", index = 3, floor = true },
    })
    local kitchen = Catalog.entries(c, "kitchen")
    eq(#kitchen, 1)
    eq(kitchen[1].sprite, "floors_interior_tilesandwood_01_11", "lowest tile number")
    ok(kitchen[1].floor)
    local garage = Catalog.entries(c, "garage")
    eq(#garage, 2)
    eq(garage[1].label, "Concrete 3")
end)

test("catalog: entries sort by category then name, and list their categories", function()
    local c = Catalog.build({
        { sprite = "fixtures_counters_01_0", sheet = "fixtures_counters_01", index = 0, group = "Oak", custom = "Counter", facing = "S", moveable = true },
        fridge(2, "S"),
        { sprite = "floors_interior_tilesandwood_01_11", sheet = "floors_interior_tilesandwood_01", index = 11, custom = "White Tiles", floor = true },
        { sprite = "appliances_cooking_01_0", sheet = "appliances_cooking_01", index = 0, group = "Modern", custom = "Oven", facing = "S", moveable = true },
    })
    local labels = {}
    for _, e in ipairs(Catalog.entries(c, "kitchen")) do labels[#labels + 1] = e.label end
    eq(table.concat(labels, ","), "Modern Oven,White Fridge,Oak Counter,White Tiles")
    eq(table.concat(Catalog.categories(c, "kitchen"), ","), "appliances,counters,floors")
    eq(#Catalog.entries(c, "nowhere"), 0)
    eq(#Catalog.categories(nil, "kitchen"), 0)
end)

local fixture = io.open(TEST_ROOT .. "/test/fixtures/vanilla-tiles.lua")
if fixture then
    fixture:close()
    local records = dofile(TEST_ROOT .. "/test/fixtures/vanilla-tiles.lua")
    local real = Catalog.build(records)

    --- Returns true when the room has an entry with the label.
    local function has(room, label)
        for _, e in ipairs(Catalog.entries(real, room)) do
            if e.label == label then return true end
        end
        return false
    end

    test("catalog (real tiles): every room has what Max asked for", function()
        ok(has("kitchen", "White Fridge") or has("kitchen", "Plain Fridge"), "a fridge")
        ok(has("kitchen", "Modern Oven"), "an oven")
        ok(has("kitchen", "Oak Counter"), "a counter")
        ok(has("kitchen", "White Tiles"), "tile floor")
        ok(has("bedroom", "Large Oak Bed"), "a bed")
        ok(has("bedroom", "Bedroom Drawers"), "a dresser")
        ok(has("bedroom", "Small Table"), "an end table")
        ok(has("living", "ValuTech Television"), "a TV")
        ok(has("living", "Long Fancy Low Table"), "a TV stand or coffee table")
        ok(has("living", "Red Comfy Couch"), "a couch")
        ok(has("living", "Oakwood Shelves"), "a bookshelf")
        ok(has("living", "Oakwood Floor"), "wood floor")
        ok(has("dining", "Large Oak Table"), "a dining table")
        ok(has("dining", "Green Dinner Chair"), "a dining chair")
        ok(has("dining", "China Cabinet"), "a china cabinet")
        ok(has("bar", "Bar Stool"), "a bar stool")
        ok(has("bar", "Bar Counter"), "a bar counter")
        ok(has("bar", "Bar Wall Bar"), "a bar cabinet")
        ok(has("garage", "Wood Top Workbench"), "a workbench")
        ok(has("garage", "Large Metal Shelves"), "storage")
    end)

    test("catalog (real tiles): no duplicate keys and every entry has a picture", function()
        for room, r in pairs(real.rooms) do
            local seen = {}
            for _, e in ipairs(r.entries) do
                ok(not seen[e.key], room .. " duplicate " .. e.key)
                seen[e.key] = true
                ok(e.sprite, room .. " " .. e.key .. " has a sprite")
            end
            ok(r.count > 20, room .. " has a real selection")
        end
    end)
end
