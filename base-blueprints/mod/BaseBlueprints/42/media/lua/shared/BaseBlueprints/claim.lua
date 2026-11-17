--- Changing the shape of a claim without losing what it remembers: squares
--- the old and new areas share keep how they looked when first claimed, so
--- changes already made stay highlighted; squares new to the claim are
--- recorded as they are now.
local Area = require("BaseBlueprints/area")
local Keys = require("BaseBlueprints/keys")

local Claim = {}

--- Returns the baseline (key -> signature) for `newArea` given the old
--- claim's area and baseline and the current signatures of the new area.
function Claim.reshape(oldArea, oldBaseline, newArea, current)
    local baseline = {}
    for _, key in ipairs(Area.keys(newArea)) do
        local x, y, z = Keys.parse(key)
        if oldArea and Area.contains(oldArea, x, y, z) then
            baseline[key] = oldBaseline[key]
        else
            baseline[key] = current[key]
        end
    end
    return baseline
end

return Claim
