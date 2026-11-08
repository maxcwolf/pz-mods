local Settings = require("ChooseStartingVehicle/settings")

test("defaults when the page is missing", function()
    local s = Settings.fromSandbox(nil)
    eq(s.enabled, true, "enabled")
    eq(s.partCondition, 100, "condition")
    eq(s.keyInPocket, true, "key")
    eq(s.searchRadius, 30, "radius")
end)

test("reads and clamps values, ignoring wrong types", function()
    local s = Settings.fromSandbox({ PartCondition = 0, FuelPercent = 250, SearchRadius = "far", KeyInPocket = false, AllowCargo = 1 })
    eq(s.partCondition, 1, "clamped low")
    eq(s.fuelPercent, 100, "clamped high")
    eq(s.searchRadius, 30, "wrong type")
    eq(s.keyInPocket, false, "bool")
    eq(s.allowCargo, true, "wrong type bool")
end)

test("the sandbox file declares every option fromSandbox reads", function()
    local f = assert(io.open(TEST_ROOT .. "/mod/ChooseStartingVehicle/42/media/sandbox-options.txt"))
    local text = f:read("*a")
    f:close()
    for _, key in ipairs({ "Enabled", "PartCondition", "FuelPercent", "BatteryPercent", "KeyInPocket", "SearchRadius", "AllowTrailer", "AllowCargo" }) do
        ok(string.find(text, "option ChooseStartingVehicle." .. key .. "\n", 1, true), key)
    end
end)
