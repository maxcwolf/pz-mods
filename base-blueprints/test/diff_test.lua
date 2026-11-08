local Diff = require("BaseBlueprints/diff")

local function rec(sprite, extra)
    local r = { cls = "IsoObject", sprite = sprite }
    for k, v in pairs(extra or {}) do
        r[k] = v
    end
    return r
end

test("diff: changed keys compare square texts and skip unknown squares", function()
    local a, b, c, d = "1,0,0", "2,0,0", "3,0,0", "4,0,0"
    local baseline = { [a] = "x", [b] = "y" }
    local current = { [a] = "x", [b] = "z", [c] = "new" }
    local changed = Diff.changedKeys(baseline, current, { a, b, c, d })
    eq(table.concat(changed, " "), b .. " " .. c)
    changed = Diff.changedKeys(baseline, current, { a, b, c }, { [b] = true })
    eq(table.concat(changed, " "), c)
end)

test("diff: edit script keeps matches, removes extras, adds missing", function()
    local floor = rec("floors_interior_tilesandwood_01_0", { floor = true })
    local wall = rec("walls_interior_house_01_0")
    local couch = rec("furniture_seating_indoor_01_0")
    local table1 = rec("furniture_tables_low_01_0")
    local current = { floor, wall, couch }
    local target = { floor, wall, table1 }
    local s = Diff.editScript(current, target)
    eq(s.keep[1], 1, "floor kept")
    eq(s.keep[2], 2, "wall kept")
    eq(#s.remove, 1)
    eq(s.remove[1], 3, "couch removed")
    eq(#s.add, 1)
    eq(s.add[1], 3, "table added")
    eq(s.floor, nil)
    ok(not Diff.isEmpty(s))
end)

test("diff: floors are set, added or removed separately", function()
    local wood = rec("floors_interior_tilesandwood_01_0", { floor = true })
    local carpet = rec("floors_interior_carpet_01_0", { floor = true })
    local s = Diff.editScript({ wood }, { carpet })
    eq(s.floor.op, "set")
    eq(s.floor.target, 1)
    eq(#s.add + #s.remove, 0)
    eq(Diff.editScript({}, { carpet }).floor.op, "add")
    eq(Diff.editScript({ wood }, {}).floor.op, "remove")
    ok(Diff.isEmpty(Diff.editScript({ wood }, { wood })))
end)

test("diff: duplicates match one to one", function()
    local crate = rec("carpentry_01_16")
    local s = Diff.editScript({ crate, crate }, { crate, crate, crate })
    eq(#s.add, 1)
    eq(#s.remove, 0)
    s = Diff.editScript({ crate, crate, crate }, { crate })
    eq(#s.remove, 2)
end)

test("diff: an opened door still matches its closed record", function()
    local closed = { cls = "IsoDoor", sprite = "fixtures_doors_01_0", north = true }
    local open = { cls = "IsoDoor", sprite = "fixtures_doors_01_2", north = true }
    ok(Diff.isEmpty(Diff.editScript({ open }, { closed })))
end)
