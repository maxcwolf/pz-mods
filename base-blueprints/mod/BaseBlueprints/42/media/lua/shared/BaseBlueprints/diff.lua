--- Compares squares: which squares changed since they were recorded, and the
--- smallest set of edits that turns a square's objects into a blueprint's.
local Signature = require("BaseBlueprints/signature")
local Keys = require("BaseBlueprints/keys")

local Diff = {}

--- Returns the sorted keys whose current signature differs from the recorded
--- one. Both maps hold key -> square signature; a missing key means empty.
--- Keys listed in `unknown` (squares not loaded right now) are skipped.
function Diff.changedKeys(baseline, current, keys, unknown)
    local changed = {}
    for _, key in ipairs(keys) do
        if not (unknown and unknown[key]) then
            if (baseline[key] or "") ~= (current[key] or "") then
                changed[#changed + 1] = key
            end
        end
    end
    table.sort(changed, Keys.less)
    return changed
end

--- Returns the index of the floor record in a list, or nil.
local function floorIndex(records)
    for i, record in ipairs(records) do
        if record.floor then
            return i
        end
    end
    return nil
end

--- Works out the edits that turn `current` records into `target` records.
--- Objects with equal signatures are kept as they are (so their loot,
--- open state and damage survive), in target order. Returns
--- { keep = { [currentIndex] = targetIndex }, remove = { currentIndex... },
---   add = { targetIndex... }, floor = nil | { op = "add"|"set"|"remove", target = index } }.
function Diff.editScript(current, target)
    local script = { keep = {}, remove = {}, add = {}, floor = nil }
    local cf, tf = floorIndex(current), floorIndex(target)
    if tf and not cf then
        script.floor = { op = "add", target = tf }
    elseif cf and not tf then
        script.floor = { op = "remove", current = cf }
    elseif cf and tf then
        if Signature.of(current[cf]) == Signature.of(target[tf]) then
            script.keep[cf] = tf
        else
            script.floor = { op = "set", current = cf, target = tf }
        end
    end

    local bySig = {}
    for ci, record in ipairs(current) do
        if ci ~= cf then
            local sig = Signature.of(record)
            bySig[sig] = bySig[sig] or {}
            local list = bySig[sig]
            list[#list + 1] = ci
        end
    end
    local used = {}
    for ti, record in ipairs(target) do
        if ti ~= tf then
            local list = bySig[Signature.of(record)]
            local match = nil
            if list then
                for _, ci in ipairs(list) do
                    if not used[ci] then
                        match = ci
                        break
                    end
                end
            end
            if match then
                used[match] = true
                script.keep[match] = ti
            else
                script.add[#script.add + 1] = ti
            end
        end
    end
    for ci = 1, #current do
        if ci ~= cf and not used[ci] then
            script.remove[#script.remove + 1] = ci
        end
    end
    return script
end

--- Returns true when an edit script changes nothing.
function Diff.isEmpty(script)
    return #script.add == 0 and #script.remove == 0 and script.floor == nil
end

return Diff
