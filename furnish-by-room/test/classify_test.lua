--- Which rooms and categories a tile lands in.
local Classify = require("FurnishByRoom/classify")

--- Returns "room=cat" pairs for a record, sorted, joined.
local function places(record)
    record.moveable = record.moveable ~= false
    local out = {}
    for _, p in ipairs((Classify.places(record))) do
        out[#out + 1] = p.room .. "=" .. p.cat
    end
    return table.concat(out, " ")
end

test("classify: label joins group and custom name", function()
    eq(Classify.label("White", "Fridge"), "White Fridge")
    eq(Classify.label(nil, "Bar Stool"), "Bar Stool")
    eq(Classify.label("  Fancy ", " Bed"), "Fancy Bed")
    eq(Classify.label(nil, nil), "")
end)

test("classify: kitchen pieces", function()
    eq(places({ sheet = "appliances_refrigeration_01", group = "White", custom = "Fridge" }),
        "bar=appliances garage=appliances kitchen=appliances")
    eq(places({ sheet = "appliances_cooking_01", group = "Modern", custom = "Oven" }), "kitchen=appliances")
    eq(places({ sheet = "appliances_cooking_01", group = "Jorge Foreguy", custom = "Barbecue" }), "garage=appliances")
    eq(places({ sheet = "fixtures_counters_01", group = "Oak", custom = "Counter" }), "kitchen=counters")
    eq(places({ sheet = "fixtures_counters_01", group = "Oak Floating", custom = "Counter" }), "kitchen=storage",
        "floating counters are wall cabinets")
end)

test("classify: bedroom, living, dining, bar, garage", function()
    eq(places({ sheet = "furniture_bedding_01", group = "Large Oak", custom = "Bed" }), "bedroom=beds")
    eq(places({ sheet = "furniture_storage_01", group = "Bedroom", custom = "Drawers" }), "bedroom=storage")
    eq(places({ sheet = "furniture_seating_indoor_01", group = "Red Comfy", custom = "Couch" }), "living=seating")
    eq(places({ sheet = "appliances_television_01", custom = "Television" }), "bedroom=electronics living=electronics")
    eq(places({ sheet = "furniture_tables_high_01", group = "Large Oak", custom = "Table" }), "dining=tables kitchen=tables")
    eq(places({ sheet = "location_restaurant_bar_01", custom = "Bar Stool" }), "bar=seating")
    eq(places({ sheet = "location_restaurant_bar_01", group = "Bar Wall", custom = "Bar" }), "bar=storage")
    eq(places({ sheet = "recreational_01", group = "Pool", custom = "Table" }), "bar=games")
    eq(places({ sheet = "location_business_machinery_01", group = "Wood Top", custom = "Workbench" }), "garage=tools")
    eq(places({ sheet = "furniture_shelving_01", group = "Large Metal", custom = "Shelves" }), "garage=storage")
    eq(places({ sheet = "furniture_shelving_01", group = "Oakwood", custom = "Shelves" }), "living=storage")
end)

test("classify: floors need the floor flag and land by material", function()
    eq(places({ sheet = "floors_interior_tilesandwood_01", custom = "Oakwood Floor", floor = true }),
        "bar=floors bedroom=floors dining=floors living=floors")
    eq(places({ sheet = "floors_interior_tilesandwood_01", custom = "White Tiles", floor = true }),
        "dining=floors garage=floors kitchen=floors")
    eq(places({ sheet = "floors_interior_carpet_01", custom = "Blue Carpet", floor = true }), "bedroom=floors living=floors")
    eq(places({ sheet = "floors_interior_tilesandwood_01", custom = "White Tiles" }), "", "no floor flag")
end)

test("classify: lit copies, non-moveables and unknown sheets stay out", function()
    eq(places({ sheet = "appliances_refrigeration_01_on", custom = "Fridge" }), "")
    eq(places({ sheet = "furniture_bedding_01", custom = "Bed", moveable = false }), "")
    eq(places({ sheet = "misc_junk_01", custom = "Junk" }), "")
end)

test("classify: container rules work on any sheet", function()
    eq(places({ sheet = "crafted_04", group = "Branch", custom = "Workbench", container = "toolcabinet" }), "garage=tools")
    eq(places({ sheet = "furniture_storage_02", group = "China", custom = "Cabinet", container = "dishescabinet" }),
        "dining=storage kitchen=storage")
end)

test("classify: unnamed concrete gets a name; categories have an order", function()
    local list, name = Classify.places({ sheet = "floors_exterior_street_01", floor = true })
    eq(#list, 1)
    eq(name, "Concrete")
    ok(Classify.categoryRank("appliances") < Classify.categoryRank("floors"))
    eq(Classify.categoryRank("unknown"), #Classify.CATEGORIES + 1)
    eq(Classify.labelKey("beds"), "UI_FBR_Cat_beds")
end)
