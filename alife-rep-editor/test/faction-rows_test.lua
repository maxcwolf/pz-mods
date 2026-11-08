require "ALifeRepEditor/faction-rows"
local Rows = ALifeRepEditor.FactionRows

test("statusText names attitudes and calls careful Wary", function()
    eq(Rows.statusText("careful"), "Wary"); eq(Rows.statusText("hostile"), "Hostile"); eq(Rows.statusText(nil), "Unknown")
end)

test("reasonText explains a recorded attitude and the usual one", function()
    eq(Rows.reasonText({ status = "neutral", baseline = "neutral" }), "their usual attitude")
    eq(Rows.reasonText({ status = "hostile", recorded = "hostile", baseline = "neutral", cause = "attack" }),
        "you attacked them (usually neutral)")
    eq(Rows.reasonText({ status = "hostile", recorded = "hostile", baseline = "hostile", cause = "admin" }), "set in this editor")
end)

test("forgivable needs a recorded attitude or grudges", function()
    ok(not Rows.forgivable({ grudges = 0 }))
    ok(Rows.forgivable({ recorded = "hostile" }))
    ok(Rows.forgivable({ grudges = 2 }))
end)

test("sort puts changed factions first, then by name", function()
    local rows = Rows.sort({ { name = "Zeta" }, { name = "alpha" }, { name = "Mid", recorded = "hostile" } })
    eq(rows[1].name, "Mid"); eq(rows[2].name, "alpha"); eq(rows[3].name, "Zeta")
end)
