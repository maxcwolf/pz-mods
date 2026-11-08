local Items = require("ChooseStartingVehicle/items")

local raws = {
    { fullType = "Base.Axe", displayName = "Axe", category = "Weapon", weight = 3 },
    { fullType = "Base.axe2", displayName = "axe", category = "Weapon", weight = 2 },
    { fullType = "Base.Hidden", displayName = "Hidden", hidden = true },
    { fullType = "Base.Old", displayName = "Old", obsolete = true },
    { fullType = "Moveables.Chair", displayName = "Chair" },
    { fullType = "Base.Mov_Sofa", displayName = "Sofa" },
    { fullType = "Base.Plank", displayName = "Plank", category = "Material", weight = 1 },
}

test("buildEntries drops hidden, obsolete and furniture items and sorts by name", function()
    local entries = Items.buildEntries(raws)
    eq(#entries, 3, "kept")
    eq(entries[1].fullType, "Base.Axe", "case-insensitive tie broken by type")
    eq(entries[3].label, "Plank", "last")
end)

test("filter matches every word in name or type, by category, with a limit", function()
    local entries = Items.buildEntries(raws)
    eq(#Items.filter(entries, "axe", nil), 2, "name")
    eq(#Items.filter(entries, "base plank", nil), 1, "type and name words")
    eq(#Items.filter(entries, "", "Material"), 1, "category")
    eq(#Items.filter(entries, "", nil, 1), 1, "limit")
end)

test("categories are distinct and sorted", function()
    listEq(Items.categories(Items.buildEntries(raws)), { "Material", "Weapon" }, "categories")
end)

test("stackWeight sums weight times count", function()
    eq(Items.stackWeight({ { type = "A", count = 2 }, { type = "B", count = 1 } }, function(t) return t == "A" and 1.5 or nil end), 3, "weight")
end)
