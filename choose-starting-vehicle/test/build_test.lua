local Build = require("ChooseStartingVehicle/build")

--- Returns a full sample build with a trailer and cargo.
local function sample()
    local build = Build.new("Base.89defender110")
    build.name = "Desert: Wolf"
    build.skin = 3
    build.color = "red"
    build.parts = { DAMNBumperFront = "Base.89defenderBullbarFrontA", DAMNSnorkel = Build.NONE }
    Build.addStack(build.trunk, "Base.Axe", 1)
    Build.addStack(build.glovebox, "Base.Lighter", 2)
    build.trailer = Build.newTrailer("Base.TrailerKI5cargoSmall")
    build.trailer.skin = 1
    build.trailer.parts = { TrailerDoor = "Base.Door" }
    Build.addStack(build.trailer.cargo, "Base.Plank", 20)
    return build
end

test("serialize and parse round-trip every field", function()
    local parsed = Build.parse(Build.serialize({ sample() }))
    eq(#parsed, 1, "count")
    local b = parsed[1]
    eq(b.name, "Desert: Wolf", "name with colon")
    eq(b.vehicle, "Base.89defender110", "vehicle")
    eq(b.skin, 3, "skin")
    eq(b.color, "red", "color")
    eq(b.parts.DAMNBumperFront, "Base.89defenderBullbarFrontA", "part")
    eq(b.parts.DAMNSnorkel, Build.NONE, "none")
    eq(b.trunk[1].type, "Base.Axe", "trunk")
    eq(b.glovebox[1].count, 2, "glovebox count")
    eq(b.trailer.vehicle, "Base.TrailerKI5cargoSmall", "trailer")
    eq(b.trailer.skin, 1, "trailer skin")
    eq(b.trailer.parts.TrailerDoor, "Base.Door", "trailer part")
    eq(b.trailer.cargo[1].count, 20, "trailer cargo")
end)

test("parse skips builds without a vehicle and unknown or broken lines", function()
    local parsed = Build.parse({ "version=1", "pending=1", "build=a", "end", "build=b", "vehicle=Base.X", "skin=", "part=broken", "trunk=Base.A*x", "nonsense", "end" })
    eq(#parsed, 1, "only b")
    eq(parsed[1].skin, nil, "empty skin")
    eq(#parsed[1].trunk, 0, "bad stack")
end)

test("parse tolerates CRLF line endings", function()
    local parsed = Build.parse({ "build=a\r", "vehicle=Base.X\r", "end\r" })
    eq(parsed[1].vehicle, "Base.X", "vehicle")
end)

test("clone is independent", function()
    local a = sample()
    local b = Build.clone(a)
    b.parts.DAMNSnorkel = "x"
    b.trunk[1].count = 9
    b.trailer.cargo[1].count = 1
    eq(a.parts.DAMNSnorkel, Build.NONE, "parts")
    eq(a.trunk[1].count, 1, "trunk")
    eq(a.trailer.cargo[1].count, 20, "trailer cargo")
end)

test("slot choices apply to every part of the slot", function()
    local build = Build.new("Base.X")
    local slot = { partIds = { "TireFrontLeft", "TireFrontRight" } }
    Build.setSlotChoice(build, slot, "Base.Tire")
    eq(build.parts.TireFrontRight, "Base.Tire", "second part")
    eq(Build.slotChoice(build, slot), "Base.Tire", "read back")
    Build.setSlotChoice(build, slot, nil)
    eq(build.parts.TireFrontLeft, nil, "cleared")
end)

test("stacks merge, count and remove", function()
    local stacks = {}
    Build.addStack(stacks, "Base.A", 2)
    Build.addStack(stacks, "Base.A", 3)
    Build.addStack(stacks, "Base.B", 0)
    eq(#stacks, 1, "merged and zero ignored")
    eq(Build.stackTotal(stacks), 5, "total")
    Build.setStackCount(stacks, "Base.A", 0)
    eq(#stacks, 0, "removed")
    Build.setStackCount(stacks, "Base.C", 4)
    eq(stacks[1].count, 4, "set adds")
end)

test("sanitize keeps offered choices and drops the rest", function()
    local entries = {
        ["Base.89defender110"] = {
            skinCount = 4,
            slots = {
                { partIds = { "DAMNBumperFront" }, allowNone = true, options = { { itemType = "Base.89defenderBullbarFrontA" } } },
                { partIds = { "TireFrontLeft" }, allowNone = false, options = { { itemType = "Base.Tire" } } },
            },
        },
        ["Base.TrailerKI5cargoSmall"] = { isTrailer = true, skinCount = 1, slots = {} },
    }
    local build = sample()
    build.parts.TireFrontLeft = Build.NONE
    local clean, notes = Build.sanitize(build, function(n) return entries[n] end, function(t) return t ~= "Base.Lighter" end)
    eq(clean.parts.DAMNBumperFront, "Base.89defenderBullbarFrontA", "kept")
    eq(clean.parts.DAMNSnorkel, nil, "unknown slot dropped")
    eq(clean.parts.TireFrontLeft, nil, "None not allowed on tires")
    eq(clean.skin, 3, "skin in range")
    eq(#clean.glovebox, 0, "missing item dropped")
    eq(clean.trailer.skin, nil, "trailer skin out of range")
    eq(#clean.trailer.cargo, 1, "trailer cargo kept")
    ok(#notes >= 4, "notes")
end)

test("sanitize returns nil when the vehicle is gone", function()
    local clean, notes = Build.sanitize(sample(), function() return nil end, function() return true end)
    eq(clean, nil, "nil")
    eq(notes[1], "Base.89defender110", "note")
end)

test("upsert replaces by name and keeps the list sorted; remove deletes", function()
    local builds = {}
    Build.upsert(builds, "zeta", Build.new("Base.Z"))
    Build.upsert(builds, "Alpha", Build.new("Base.A"))
    Build.upsert(builds, "zeta", Build.new("Base.Z2"))
    eq(#builds, 2, "count")
    eq(builds[1].name, "Alpha", "sorted")
    eq(builds[2].vehicle, "Base.Z2", "replaced")
    Build.remove(builds, "Alpha")
    eq(#builds, 1, "removed")
end)

test("setPartChoice sets one part or its whole slot", function()
    local section = Build.new("Base.Car")
    local slot = { partIds = { "TireFrontLeft", "TireFrontRight" } }
    Build.setPartChoice(section, "TireFrontLeft", "Base.A", slot, false)
    eq(Build.partChoice(section, "TireFrontLeft"), "Base.A", "one")
    eq(Build.partChoice(section, "TireFrontRight"), nil, "other untouched")
    Build.setPartChoice(section, "TireFrontRight", "Base.B", slot, true)
    eq(Build.partChoice(section, "TireFrontLeft"), "Base.B", "whole slot")
    Build.setPartChoice(section, "TireFrontLeft", nil, slot, false)
    eq(Build.partChoice(section, "TireFrontLeft"), nil, "cleared")
end)
