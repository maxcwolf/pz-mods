require "ALifeRepEditor/faction-restore"
local Restore = ALifeRepEditor.FactionRestore

test("copy is shallow and nil-safe", function()
    local entry = { status = "hostile", cause = "attack" }
    local copy = Restore.copy(entry)
    eq(copy.status, "hostile"); ok(copy ~= entry)
    eq(Restore.copy(nil), nil)
end)

test("noteOrigin keeps the earliest escalation inside the window", function()
    local origins = {}
    Restore.noteOrigin(origins, "ash", nil, 10, 24)
    Restore.noteOrigin(origins, "ash", { status = "hostile" }, 12, 24)
    eq(origins.ash.atHours, 10); eq(origins.ash.before, nil)
end)

test("noteOrigin starts over once the old one is outside the window", function()
    local origins = { ash = { atHours = 10, before = nil } }
    Restore.noteOrigin(origins, "ash", { status = "careful" }, 40, 24)
    eq(origins.ash.atHours, 40); eq(origins.ash.before.status, "careful")
end)

test("pick uses the pre-escalation attitude for a recent origin", function()
    local target = Restore.pick({ atHours = 99, before = nil }, { status = "hostile", cause = "attack" }, 100, 24)
    eq(target, nil)
end)

test("pick falls back to the pre-kill attitude for stale or later origins", function()
    eq(Restore.pick({ atHours = 50, before = nil }, { status = "hostile" }, 100, 24).status, "hostile")
    eq(Restore.pick({ atHours = 101, before = nil }, { status = "careful" }, 100, 24).status, "careful")
    eq(Restore.pick(nil, nil, 100, 24), nil)
end)

test("isRecent needs an origin at or before the kill and inside the window", function()
    ok(Restore.isRecent({ atHours = 90 }, 100, 24))
    ok(not Restore.isRecent({ atHours = 70 }, 100, 24))
    ok(not Restore.isRecent({ atHours = 101 }, 100, 24))
    ok(not Restore.isRecent(nil, 100, 24))
end)

