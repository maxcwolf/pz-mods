local Factory = require("BaseBlueprints/factory")

test("factory: picks the constructor kind per class", function()
    eq(Factory.kind({ cls = "IsoObject", floor = true }), "floor")
    eq(Factory.kind({ cls = "IsoDoor" }), "door")
    eq(Factory.kind({ cls = "IsoWindow" }), "window")
    eq(Factory.kind({ cls = "IsoWindowFrame" }), "frame")
    eq(Factory.kind({ cls = "IsoCurtain" }), "curtain")
    eq(Factory.kind({ cls = "IsoLightSwitch" }), "light")
    eq(Factory.kind({ cls = "IsoThumpable" }), "thumpable")
    eq(Factory.kind({ cls = "IsoStove" }), "appliance")
    eq(Factory.kind({ cls = "IsoObject" }), "plain")
    eq(Factory.kind({ cls = "IsoMultiMedia" }), "brush", "unexposed classes use the game's placer")
end)

test("factory: max health is restored before health", function()
    local maxAt, healthAt
    for i, entry in ipairs(Factory.THUMPABLE_NUMBERS) do
        if entry[1] == "maxHealth" then maxAt = i end
        if entry[1] == "health" then healthAt = i end
    end
    ok(maxAt < healthAt)
end)
