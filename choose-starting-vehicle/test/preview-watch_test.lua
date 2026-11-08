local PreviewWatch = require("ChooseStartingVehicle/preview-watch")

--- Feeds a run of frames and returns the last non-nil action.
local function run(watch, reached, count)
    local last
    for _ = 1, count do
        last = PreviewWatch.frame(watch, reached) or last
    end
    return last
end

test("preview watch: a new vehicle waits for a run of clean frames", function()
    local w = PreviewWatch.new({ cleanFrames = 3 })
    PreviewWatch.warmUp(w)
    eq(run(w, false, 15), nil, "models still loading")
    eq(PreviewWatch.frame(w, true), nil, "one clean frame")
    eq(PreviewWatch.frame(w, true), nil, "two")
    eq(PreviewWatch.frame(w, true), "ready", "three in a row")
end)

test("preview watch: a vehicle that never draws cleanly gives up", function()
    local w = PreviewWatch.new({ warmupLimit = 20 })
    PreviewWatch.warmUp(w)
    eq(run(w, false, 20), "fail", "gave up")
end)

test("preview watch: the build view rides out a few failed frames", function()
    local w = PreviewWatch.new({ maxMissed = 10 })
    PreviewWatch.composed(w)
    eq(run(w, false, 5), nil, "models loading")
    eq(run(w, true, 3), nil, "recovered")
    eq(run(w, false, 9), nil, "the count restarts after a clean frame")
    eq(PreviewWatch.frame(w, false), "fail", "ten in a row")
end)

test("preview watch: idle never asks for anything", function()
    local w = PreviewWatch.new()
    eq(run(w, false, 1000), nil, "idle")
end)

test("preview watch: zoom fits the vehicle to the view", function()
    local trooper = PreviewWatch.fitZoom(4.58, 1.8, 560, 600)
    ok(trooper >= 6 and trooper <= 8, "trooper in a 560 view: " .. trooper)
    ok(PreviewWatch.fitZoom(12, 2.5, 560, 600) < trooper, "a long trailer zooms out more")
    eq(PreviewWatch.fitZoom(0, 0, 560, 600), 7, "unknown size")
    eq(PreviewWatch.fitZoom(0.01, 0.01, 560, 600, 20), 20, "clamped")
end)
