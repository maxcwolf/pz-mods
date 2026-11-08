local Overlay = require("ChooseStartingVehicle/overlay")

-- A slice of the game's tables: vanilla style (global boxes with per-prefix
-- overrides) and a KI5 style entry registered through damnlib.
local CAR_LIST = {
    ["Base.CarNormal"] = { imgPrefix = "4door_", x = 10, y = 0 },
    ["Base.89fordBronco"] = { imgPrefix = "89fordBronco_", x = 10, y = 30 },
    ["Base.Odd"] = { x = 1 },
}
local PART_LIST = {
    Battery = { img = "battery", x = 48, y = 64, x2 = 92, y2 = 99, vehicles = { ["4door_"] = { x = 72, y = 64, x2 = 118, y2 = 99 } } },
    DAMNBumperFront = { img = "armor_bull", vehicles = { ["89fordBronco_"] = { img = "armor_bull", x = 14, y = 587, x2 = 54, y2 = 625 } } },
    WindowRear = { img = { "window_rear_a", "window_rear_b" }, multipleImg = true, x = 0, y = 0, x2 = 5, y2 = 5 },
}

test("overlay: car props need an image prefix", function()
    ok(Overlay.carProps(CAR_LIST, "Base.CarNormal"), "vanilla")
    eq(Overlay.carProps(CAR_LIST, "Base.Odd"), nil, "no prefix")
    eq(Overlay.carProps(CAR_LIST, "Base.Ghost"), nil, "missing")
    eq(Overlay.baseImage(CAR_LIST["Base.CarNormal"]), "media/ui/vehicles/mechanic overlay/4door_base.png", "base path")
end)

test("overlay: per-vehicle boxes override the global one", function()
    local box = Overlay.partProps(PART_LIST, CAR_LIST["Base.CarNormal"], "Battery")
    eq(box.x, 72, "4door battery x")
    eq(box.img, "battery", "image kept")
    eq(Overlay.partProps(PART_LIST, CAR_LIST["Base.89fordBronco"], "Battery").x, 48, "global box")
end)

test("overlay: car-level PartList overrides the image", function()
    local props = { imgPrefix = "van_", PartList = { Battery = { img = "battery_van" } } }
    eq(Overlay.partProps(PART_LIST, props, "Battery").img, "battery_van", "override")
end)

test("overlay: images handle one or several files", function()
    local props = CAR_LIST["Base.CarNormal"]
    listEq(Overlay.partImages(props, { img = "battery" }), { "media/ui/vehicles/mechanic overlay/4door_battery.png" }, "one")
    eq(#Overlay.partImages(props, Overlay.partProps(PART_LIST, props, "WindowRear")), 2, "several")
    eq(#Overlay.partImages(props, nil), 0, "none")
end)

test("overlay: diagram lists known parts and hit-tests like vanilla", function()
    local d = Overlay.diagram(CAR_LIST, PART_LIST, "Base.89fordBronco", { "Battery", "DAMNBumperFront", "Engine" })
    eq(d.y, 30, "offset")
    eq(#d.parts, 2, "unknown parts skipped")
    eq(Overlay.hit(d, 20, 600), "DAMNBumperFront", "inside")
    eq(Overlay.hit(d, 20, 587), nil, "top edge is outside")
    eq(Overlay.diagram(CAR_LIST, PART_LIST, "Base.Ghost", {}), nil, "no overlay")
end)

test("overlay: state levels run from removed to fitted", function()
    eq(Overlay.stateLevel("none"), 0, "none")
    eq(Overlay.stateLevel("default"), 55, "game's choice")
    eq(Overlay.stateLevel("chosen"), 100, "chosen")
    eq(Overlay.stateLevel("fixed"), 100, "fixed")
end)

test("overlay: mix blends bad to good and clamps the level", function()
    local bad, good = { r = 1, g = 0, b = 0 }, { r = 0, g = 1, b = 0 }
    eq(Overlay.mix(bad, good, 0).r, 1, "bad")
    eq(Overlay.mix(bad, good, 100).g, 1, "good")
    eq(Overlay.mix(bad, good, 50).r, 0.5, "half")
    eq(Overlay.mix(bad, good, 250).g, 1, "clamped")
end)
