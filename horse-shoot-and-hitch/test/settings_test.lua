local Settings = require("HorseShootAndHitch/settings")

test("missing sandbox options give the defaults", function()
    local s = Settings.fromSandbox(nil)
    eq(s.shooting, true)
    eq(s.penalties.stand, 0)
    eq(s.penalties.walk, 2)
    eq(s.penalties.trot, 5)
    eq(s.penalties.gallop, 20)
    eq(s.arc, 180)
    eq(s.radius, 2)
end)

test("sandbox options override the defaults", function()
    local s = Settings.fromSandbox({
        MountedShooting = false, WalkPenalty = 0, TrotPenalty = 8,
        GallopPenalty = 40, AimArc = 120, TieRadius = 4,
    })
    eq(s.shooting, false)
    eq(s.penalties.walk, 0)
    eq(s.penalties.trot, 8)
    eq(s.penalties.gallop, 40)
    eq(s.arc, 120)
    eq(s.radius, 4)
end)

test("non-number options fall back to defaults", function()
    local s = Settings.fromSandbox({ WalkPenalty = "lots", TieRadius = true })
    eq(s.penalties.walk, 2)
    eq(s.radius, 2)
end)
