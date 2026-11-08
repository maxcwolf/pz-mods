--- Decides, frame by frame, when the 3D view may switch to the build view and
--- when it must give up on it. The scene loads models in the background and
--- throws while drawing one that isn't ready; those errors stop by themselves
--- after a few frames. Each frame reports whether drawing got past the scene
--- ("reached"). A new vehicle waits for a run of clean frames (its models are
--- loaded) before the build view starts, and the build view is only dropped
--- after a long run of failed frames. Pure.
local PreviewWatch = {}

PreviewWatch.DEFAULTS = {
    cleanFrames = 10,
    warmupLimit = 600,
    maxMissed = 90,
}

--- Returns a fresh watch in the idle phase.
function PreviewWatch.new(opts)
    local o = {}
    for key, value in pairs(PreviewWatch.DEFAULTS) do
        o[key] = (opts and opts[key]) or value
    end
    o.phase = "idle"
    o.clean = 0
    o.missed = 0
    o.waited = 0
    return o
end

--- Starts waiting for a newly shown vehicle to draw cleanly.
function PreviewWatch.warmUp(watch)
    watch.phase = "warming"
    watch.clean = 0
    watch.missed = 0
    watch.waited = 0
end

--- Marks the build view as shown.
function PreviewWatch.composed(watch)
    watch.phase = "composed"
    watch.clean = 0
    watch.missed = 0
end

--- Stops watching (plain view or nothing shown).
function PreviewWatch.idle(watch)
    watch.phase = "idle"
end

--- Records one frame and returns what to do: "ready" (start the build view),
--- "fail" (give up on the build view) or nil.
function PreviewWatch.frame(watch, reached)
    if reached then
        watch.clean = watch.clean + 1
        watch.missed = 0
    else
        watch.clean = 0
        watch.missed = watch.missed + 1
    end
    if watch.phase == "warming" then
        watch.waited = watch.waited + 1
        if watch.clean >= watch.cleanFrames then
            return "ready"
        end
        if watch.waited >= watch.warmupLimit then
            return "fail"
        end
    elseif watch.phase == "composed" then
        if watch.missed >= watch.maxMissed then
            return "fail"
        end
    end
    return nil
end

-- Measured in game: at zoom 12 the scene draws about 220 pixels per unit of
-- a vehicle's extents, and each zoom step scales by e^0.2 (UI3DScene.zoomMult).
local PIXELS_AT_12 = 220

--- Returns the zoom that fits a vehicle of this length and width in a view of
--- this size with some margin, clamped to the scene's 1..maxZoom range.
function PreviewWatch.fitZoom(length, width, viewWidth, viewHeight, maxZoom)
    local size = math.max(length or 0, width or 0)
    if size <= 0 then
        return 7
    end
    local want = 0.7 * math.min(viewWidth, viewHeight * 1.2) / size
    local zoom = 12 + math.log(want / PIXELS_AT_12) / 0.2
    return math.max(1, math.min(maxZoom or 20, math.floor(zoom + 0.5)))
end

return PreviewWatch
