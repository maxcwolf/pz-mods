--- A short text that identifies an object record for comparison. Two
--- records with the same signature count as the same object, so a square is
--- unchanged when its signatures match the recorded ones.
local Classify = require("BaseBlueprints/classify")

local Signature = {}

--- Returns the signature of one object record.
function Signature.of(record)
    local sprite = record.sprite or ""
    if Classify.STATEFUL[record.cls] then
        sprite = Classify.sheet(sprite) .. "_*"
    end
    local parts = { record.cls or "IsoObject", sprite }
    if record.north then
        parts[#parts + 1] = "N"
    end
    if record.floor then
        parts[#parts + 1] = "F"
    end
    if record.overlay then
        parts[#parts + 1] = "o:" .. record.overlay
    end
    if record.attached and #record.attached > 0 then
        local names = {}
        for i, name in ipairs(record.attached) do
            names[i] = name
        end
        table.sort(names)
        parts[#parts + 1] = "a:" .. table.concat(names, "+")
    end
    return table.concat(parts, "|")
end

--- Returns one text for a whole square: its sorted object signatures, or ""
--- when nothing is recorded there.
function Signature.ofList(records)
    if not records or #records == 0 then
        return ""
    end
    local sigs = {}
    for i, record in ipairs(records) do
        sigs[i] = Signature.of(record)
    end
    table.sort(sigs)
    return table.concat(sigs, "\n")
end

return Signature
