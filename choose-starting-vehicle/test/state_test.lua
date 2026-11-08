package.path = TEST_ROOT .. "/test/harness/?.lua;" .. package.path
local Stubs = require("pz-stubs")
local Build = require("ChooseStartingVehicle/build")
Stubs.reset()

-- state.lua needs the runtime catalog; give it a tiny fake one.
CSV_Runtime = {
    findEntry = function(name)
        if name == "Base.Car" then
            return { name = name, skinCount = 2, slots = { { partIds = { "DAMNSnorkel" }, allowNone = true, options = { { itemType = "Base.Snorkel" } } } } }
        end
        return nil
    end,
    itemExists = function() return true end,
}
package.loaded["ChooseStartingVehicle/runtime"] = true
require("ChooseStartingVehicle/state")

--- Resets the state module and the fake files.
local function fresh()
    Stubs.reset()
    Stubs.files = {}
    CSV_State.build = Build.new(nil)
    CSV_State.builds = {}
    CSV_State.pending = false
    CSV_State.loaded = false
end

test("markPending writes the build with a pending flag; takePending consumes it once", function()
    fresh()
    CSV_State.build = Build.new("Base.Car")
    CSV_State.build.parts.DAMNSnorkel = "Base.Snorkel"
    CSV_State.markPending()
    ok(CSV_State.pending, "armed in memory")
    local _, pending = CSV_State.readLast()
    ok(pending, "armed on disk")
    local build = CSV_State.takePending()
    eq(build.parts.DAMNSnorkel, "Base.Snorkel", "build")
    eq(CSV_State.takePending(), nil, "only once")
    local last, still = CSV_State.readLast()
    eq(still, false, "flag cleared on disk")
    eq(last.vehicle, "Base.Car", "build kept on disk")
end)

test("takePending falls back to the file when Lua was reloaded", function()
    fresh()
    CSV_State.build = Build.new("Base.Car")
    CSV_State.markPending()
    CSV_State.pending = false
    CSV_State.build = Build.new(nil)
    local build = CSV_State.takePending()
    eq(build and build.vehicle, "Base.Car", "from file")
    eq(CSV_State.readLast().vehicle, "Base.Car", "last build not wiped")
end)

test("no vehicle means nothing is armed", function()
    fresh()
    CSV_State.markPending()
    eq(CSV_State.pending, false, "not armed")
    eq(CSV_State.takePending(), nil, "nothing")
end)

test("saved builds persist, load sanitized and delete", function()
    fresh()
    CSV_State.build = Build.new("Base.Car")
    CSV_State.build.parts.DAMNSnorkel = "Base.Snorkel"
    CSV_State.build.parts.Gone = "Base.X"
    CSV_State.saveAs("Beach run")
    CSV_State.builds = {}
    CSV_State.loaded = false
    CSV_State.load()
    eq(#CSV_State.builds, 1, "read back")
    local notes = CSV_State.loadNamed("Beach run")
    eq(CSV_State.build.parts.Gone, nil, "unknown part dropped")
    eq(#notes, 1, "one note")
    CSV_State.deleteNamed("Beach run")
    eq(#Build.parse(Stubs.files[CSV_State.BUILDS_FILE]), 0, "deleted on disk")
end)

test("a build whose vehicle is gone loads as no vehicle", function()
    fresh()
    CSV_State.setBuild(Build.new("Base.Ghost"))
    ok(Build.isEmpty(CSV_State.build), "empty")
end)
