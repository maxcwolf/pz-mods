local Settings = require("VehicleStorageCapacity/settings")

test("settings: defaults when the sandbox page is missing", function()
    local s = Settings.fromSandbox(nil)
    eq(s.trunk, 100, "trunk"); eq(s.seat, 100, "seat"); eq(s.glovebox, 100, "glovebox"); eq(s.trailer, 100, "trailer")
    ok(Settings.isVanilla(s), "vanilla")
end)

test("settings: reads each option", function()
    local s = Settings.fromSandbox({ TrunkPercent = 250, SeatPercent = 50, GloveBoxPercent = 300, TrailerPercent = 150 })
    eq(s.trunk, 250, "trunk"); eq(s.seat, 50, "seat"); eq(s.glovebox, 300, "glovebox"); eq(s.trailer, 150, "trailer")
    ok(not Settings.isVanilla(s), "not vanilla")
end)

test("settings: clamps and rounds out-of-range values", function()
    local s = Settings.fromSandbox({ TrunkPercent = 0, SeatPercent = 5000, GloveBoxPercent = 149.6, TrailerPercent = "x" })
    eq(s.trunk, 1, "low clamp"); eq(s.seat, 1000, "high clamp"); eq(s.glovebox, 150, "rounded"); eq(s.trailer, 100, "non-number")
end)

test("settings: current reads SandboxVars", function()
    local saved = _G.SandboxVars
    _G.SandboxVars = { VehicleStorageCapacity = { TrunkPercent = 200 } }
    eq(Settings.current().trunk, 200, "trunk")
    _G.SandboxVars = nil
    eq(Settings.current().trunk, 100, "no SandboxVars")
    _G.SandboxVars = saved
end)

test("settings: describe names every category", function()
    local text = Settings.describe(Settings.fromSandbox({ TrunkPercent = 200 }))
    ok(string.find(text, "trunks 200", 1, true), text)
    ok(string.find(text, "trailers 100", 1, true), text)
end)
