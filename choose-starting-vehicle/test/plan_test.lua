local Plan = require("ChooseStartingVehicle/plan")
local Build = require("ChooseStartingVehicle/build")
local Settings = require("ChooseStartingVehicle/settings")

test("partSteps sorts ids and turns none into removals", function()
    local steps = Plan.partSteps({ B = Build.NONE, A = "Base.X" })
    eq(steps[1].id, "A", "sorted")
    eq(steps[1].itemType, "Base.X", "install")
    ok(steps[2].remove, "remove")
end)

test("pickTrunk takes the biggest real container", function()
    local id = Plan.pickTrunk({
        { id = "SeatFrontLeft", category = "seat", capacity = 80 },
        { id = "TireFrontLeft", wheel = true, capacity = 35 },
        { id = "GasTank", category = "gastank", capacity = 70 },
        { id = "GloveBox", gloveBox = true, capacity = 5 },
        { id = "DEF89Roofrack", category = "Other", capacity = 90 },
        { id = "DEF89Trunk", category = "bodywork", capacity = 60 },
    })
    eq(id, "DEF89Trunk", "trunk-named beats a bigger roof rack")
    eq(Plan.pickTrunk({ { id = "DAMNRoofrack", capacity = 50 }, { id = "Cargo", capacity = 70 } }), "Cargo", "biggest without a trunk")
    eq(Plan.pickTrunk({}), nil, "none")
end)

test("pickGloveBox prefers the GloveBox part, else a console", function()
    eq(Plan.pickGloveBox({ { id = "DEF89CenterConsole", gloveBox = true }, { id = "GloveBox", gloveBox = true } }), "GloveBox", "glovebox")
    eq(Plan.pickGloveBox({ { id = "DEF89CenterConsole", gloveBox = true } }), "DEF89CenterConsole", "console")
    ok(Plan.isGloveBoxId("DEF89CenterConsole"), "console id")
end)

test("fromBuild honors the sandbox switches", function()
    local build = Build.new("Base.Car")
    build.color = "red"
    Build.addStack(build.trunk, "Base.Axe", 1)
    build.trailer = Build.newTrailer("Base.Trailer")
    local settings = Settings.fromSandbox({ AllowTrailer = false, AllowCargo = false, FuelPercent = 50 })
    local plan = Plan.fromBuild(build, settings)
    eq(plan.trailer, nil, "no trailer")
    eq(#plan.trunk, 0, "no cargo")
    eq(plan.fuel, 0.5, "fuel fraction")
    eq(plan.color.key, "red", "color preset")
    eq(Plan.fromBuild(build, Settings.fromSandbox({ Enabled = false })), nil, "disabled")
    eq(Plan.fromBuild(Build.new(nil), settings), nil, "no vehicle")
end)

test("fromBuild keeps the trailer and its cargo by default", function()
    local build = Build.new("Base.Car")
    build.trailer = Build.newTrailer("Base.Trailer")
    Build.addStack(build.trailer.cargo, "Base.Plank", 3)
    local plan = Plan.fromBuild(build, Settings.fromSandbox(nil))
    eq(plan.trailer.vehicle, "Base.Trailer", "trailer")
    eq(plan.trailer.cargo[1].count, 3, "cargo")
    eq(plan.keyInPocket, true, "key")
end)

test("fullType adds the Base module only when missing", function()
    eq(Plan.fullType("Car"), "Base.Car", "added")
    eq(Plan.fullType("Base.Car"), "Base.Car", "kept")
end)

test("every color preset has a translation-style key and 0..1 values", function()
    for _, c in ipairs(Plan.COLORS) do
        ok(c.h >= 0 and c.h <= 1 and c.s >= 0 and c.s <= 1 and c.v >= 0 and c.v <= 1, c.key)
    end
    eq(Plan.color("nope"), nil, "unknown")
end)

test("cargoParts picks the trunk and glove box from catalog parts", function()
    local roles = Plan.cargoParts({
        { id = "SeatFrontLeft", container = true, category = "seat", capacity = 30 },
        { id = "GloveBox", container = true, capacity = 5 },
        { id = "TruckBed", container = true, capacity = 80 },
        { id = "Engine" },
    })
    eq(roles.trunk, "TruckBed", "trunk")
    eq(roles.glovebox, "GloveBox", "glove box")
    eq(Plan.cargoParts({}).trunk, nil, "no containers")
end)
