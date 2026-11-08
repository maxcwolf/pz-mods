--- The capacity rule. Pure: given what the part shows now and what this mod
--- remembered about it, decides the capacity to set and what to remember.
---
--- The game computes a part's capacity itself (from the installed item, its
--- condition, or the vehicle script) and saves it with the vehicle. This mod
--- never edits scripts or items; it scales that computed value. To stay
--- idempotent it remembers the game's value (base), the value it set
--- (applied) and the installed item's id. When the part still shows the
--- applied value for the same item, the base is reused; anything else means
--- the game recomputed (part installed, removed, or repaired), so the shown
--- value becomes the new base.
local Capacity = {}

--- The engine caps every vehicle container at this capacity.
Capacity.ENGINE_MAX = 1000

--- The item id this mod remembers for parts with nothing installed.
Capacity.NO_ITEM = -1

--- Returns base scaled by percent, rounded, at least 1 and at most the engine cap.
function Capacity.scale(base, percent)
    local value = math.floor(base * percent / 100 + 0.5)
    return math.max(1, math.min(Capacity.ENGINE_MAX, value))
end

--- Returns true when the remembered record still describes the part as it is.
local function recordMatches(record, raw, itemId)
    return record ~= nil and record.applied == raw and record.item == itemId
end

--- Decides one part. `input` holds raw (capacity shown now), percent,
--- occupiedSeat, needsItem (the part takes an installable item),
--- itemId (nil when nothing is installed) and record (nil or
--- {base, applied, item}). Returns {capacity = number or nil to leave it,
--- record = table, or nil to forget}, plus keep = true when the record must
--- be left untouched.
function Capacity.decide(input)
    -- The game divides an occupied seat's capacity by 4 when read, so the
    -- shown value is not the stored one; check again once the seat is free.
    if input.occupiedSeat then
        return { keep = true }
    end
    local itemId = input.itemId or Capacity.NO_ITEM
    -- A part whose item is missing (no trunk lid, no roof rack) keeps the
    -- game's value; vanilla also copies this value into newly spawned part
    -- items, so scaling it here would compound.
    if input.needsItem and input.itemId == nil then
        return {}
    end
    local record = input.record
    local base = input.raw
    if recordMatches(record, input.raw, itemId) then
        base = record.base
    end
    if base == nil or base <= 0 then
        return {}
    end
    if input.percent == 100 then
        return { capacity = base ~= input.raw and base or nil }
    end
    local target = Capacity.scale(base, input.percent)
    return {
        capacity = target ~= input.raw and target or nil,
        record = { base = base, applied = target, item = itemId },
    }
end

return Capacity
