local Claim = require("BaseBlueprints/claim")

test("claim: reshaping keeps the old baseline where the areas overlap", function()
    local old = { x1 = 0, y1 = 0, x2 = 1, y2 = 0, z1 = 0, z2 = 0 }
    local new = { x1 = 1, y1 = 0, x2 = 2, y2 = 0, z1 = 0, z2 = 0 }
    local baseline = Claim.reshape(old, { ["0,0,0"] = "a", ["1,0,0"] = "original" }, new,
        { ["1,0,0"] = "changed since", ["2,0,0"] = "now" })
    eq(baseline["1,0,0"], "original", "change stays visible")
    eq(baseline["2,0,0"], "now", "new square recorded as it is")
    eq(baseline["0,0,0"], nil, "square outside the new area dropped")
end)

test("claim: with no old claim everything is recorded as it is now", function()
    local area = { x1 = 0, y1 = 0, x2 = 0, y2 = 0, z1 = 0, z2 = 1 }
    local baseline = Claim.reshape(nil, nil, area, { ["0,0,1"] = "x" })
    eq(baseline["0,0,1"], "x")
    eq(baseline["0,0,0"], nil)
end)
