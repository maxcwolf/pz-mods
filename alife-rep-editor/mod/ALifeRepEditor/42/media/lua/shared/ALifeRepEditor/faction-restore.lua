--- Pure rules for putting a faction's attitude back after an undone kill.
--- A-Life turns a faction hostile on the first hit, before the kill, so the
--- editor remembers what the attitude was before that first hit.
ALifeRepEditor = ALifeRepEditor or {}

local Restore = { windowHours = 24 }
ALifeRepEditor.FactionRestore = Restore

--- Returns a shallow copy of a faction attitude entry, or nil.
function Restore.copy(entry)
    if type(entry) ~= "table" then return nil end
    local result = {}
    for field, value in pairs(entry) do result[field] = value end
    return result
end

--- Records the attitude before a hostile escalation, keeping the earliest one inside the window.
function Restore.noteOrigin(origins, factionId, before, nowHours, windowHours)
    local window = tonumber(windowHours) or Restore.windowHours
    local now = tonumber(nowHours) or 0
    local existing = origins[factionId]
    if type(existing) == "table" and now - (tonumber(existing.atHours) or -math.huge) <= window then
        return existing
    end
    local origin = { atHours = now, before = Restore.copy(before) }
    origins[factionId] = origin
    return origin
end

--- Returns true when an escalation began at or before the kill and inside the window.
function Restore.isRecent(origin, killAtHours, windowHours)
    if type(origin) ~= "table" then return false end
    local window = tonumber(windowHours) or Restore.windowHours
    local killAt = tonumber(killAtHours) or 0
    local at = tonumber(origin.atHours)
    return at ~= nil and at <= killAt + 0.01 and killAt - at <= window
end

--- Picks the attitude to restore: the pre-escalation one if it started near the kill, else the pre-kill one.
function Restore.pick(origin, preKill, killAtHours, windowHours)
    if Restore.isRecent(origin, killAtHours, windowHours) then return Restore.copy(origin.before) end
    return Restore.copy(preKill)
end

return Restore
