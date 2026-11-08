--- Regression tests for CSV_Runtime.entry: in the real game, vehicle templates
--- keep no script text (only vehicle scripts do), so parts that come from
--- templates (every KI5 add-on, vanilla tires and brakes) must be read from a
--- real vehicle object instead. These fakes mirror that: templates have no
--- bodies, and BaseVehicle.new builds parts from the script's final part list.

package.path = TEST_ROOT .. "/test/harness/?.lua;" .. package.path
local FakeGame = require("fake-game")

--- Loads a fresh copy of runtime.lua against the fakes.
local function freshRuntime()
    FakeGame.install()
    CSV_Runtime = nil
    FakeGame.load("ChooseStartingVehicle/runtime.lua")
    return CSV_Runtime
end

--- Finds a slot by one of its part ids.
local function slotWith(entry, partId)
    for _, slot in ipairs(entry.slots) do
        for _, id in ipairs(slot.partIds) do
            if id == partId then return slot end
        end
    end
    return nil
end

test("runtime: parts from templates with no stored text still get slots", function()
    local entry = freshRuntime().entry("Base.TestTruck")
    ok(entry, "entry")
    local bumper = slotWith(entry, "DAMNBumperFront")
    ok(bumper, "bumper slot")
    eq(#bumper.options, 2, "bumper options")
    eq(bumper.allowNone, true, "bumper can be removed")
    local tires = slotWith(entry, "TireFrontLeft")
    ok(tires, "tire slot")
    eq(#tires.partIds, 2, "tires merged")
end)

test("runtime: entry lists every displayed part in mechanics order", function()
    local entry = freshRuntime().entry("Base.TestTruck")
    eq(#entry.parts, 7, "parts")
    eq(entry.parts[1].id, "DAMNBumperFront", "first part")
    eq(entry.parts[4].container, true, "seat is a container")
    eq(entry.parts[5].capacity, 80, "truck bed capacity")
    eq(entry.parts[1].models[2].file, "TTBullbar1", "part models kept")
end)

test("runtime: paints still come from the vehicle's own text", function()
    local entry = freshRuntime().entry("Base.TestTruck")
    eq(entry.skins[1], "Red", "first paint")
    eq(entry.skins[2], "Blue", "second paint")
end)
