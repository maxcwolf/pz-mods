require "ALifeRepEditor/kill-ledger"
local Ledger = ALifeRepEditor.KillLedger

test("push puts the newest first and trims to the limit", function()
    local list = {}
    for i = 1, 5 do Ledger.push(list, { id = "k" .. i }, 3) end
    eq(#list, 3); eq(list[1].id, "k5"); eq(list[3].id, "k3")
end)

test("push replaces an older copy of the same kill", function()
    local list = { { id = "a" }, { id = "b" } }
    Ledger.push(list, { id = "b", fresh = true }, 6)
    eq(#list, 2); eq(list[1].id, "b"); ok(list[1].fresh); eq(list[2].id, "a")
end)

test("find returns the entry and its position", function()
    local list = { { id = "a" }, { id = "b" } }
    local entry, index = Ledger.find(list, "b")
    eq(entry.id, "b"); eq(index, 2)
    eq(Ledger.find(list, "z"), nil)
end)

test("ageText reads in hours, then days", function()
    eq(Ledger.ageText(100, 100.5), "just now")
    eq(Ledger.ageText(100, 103.9), "3h ago")
    eq(Ledger.ageText(100, 172), "3d ago")
end)

test("classText falls back for unknown classes", function()
    eq(Ledger.classText("neutral"), "meant you no harm")
    eq(Ledger.classText("weird"), Ledger.CLASS_TEXT.unknown)
end)

test("describe names the NPC, faction, reason, change and time", function()
    local text = Ledger.describe({ name = "Joe Doe", factionName = "Ashguard", class = "neutral", applied = -40, atHours = 98 }, 100)
    eq(text, "Joe Doe (Ashguard) meant you no harm. Reputation -40, 2h ago")
    eq(Ledger.describe({ class = "hostile", applied = 10, atHours = 100 }, 100), "An NPC was hostile to you. Reputation +10, just now")
end)
