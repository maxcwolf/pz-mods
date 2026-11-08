--- Pure view model for the faction list: what each faction thinks of you,
--- why, and the order to show them in (the ones angry at you first).
ALifeRepEditor = ALifeRepEditor or {}

local Rows = {}
ALifeRepEditor.FactionRows = Rows

Rows.STATUS_TEXT = { friendly = "Friendly", neutral = "Neutral", careful = "Wary", hostile = "Hostile" }

Rows.CAUSE_TEXT = {
    attack = "you attacked them",
    wound = "you hurt one of theirs",
    kill = "you killed one of theirs",
    provoked = "you provoked them",
    admin = "set in this editor",
}

Rows.COLOR = {
    friendly = { 0.45, 0.85, 0.45 },
    neutral = { 0.85, 0.85, 0.85 },
    careful = { 0.95, 0.8, 0.35 },
    hostile = { 0.95, 0.4, 0.35 },
}

--- Returns the display word for an attitude.
function Rows.statusText(status)
    return Rows.STATUS_TEXT[tostring(status or "")] or "Unknown"
end

--- Returns the reason shown under an attitude.
function Rows.reasonText(row)
    if row.recorded == nil then return "their usual attitude" end
    local cause = Rows.CAUSE_TEXT[tostring(row.cause or "")] or "something you did"
    if row.baseline ~= nil and row.baseline ~= row.status then
        return cause .. " (usually " .. string.lower(Rows.statusText(row.baseline)) .. ")"
    end
    return cause
end

--- Returns the RGB color for an attitude.
function Rows.color(status)
    return Rows.COLOR[tostring(status or "")] or Rows.COLOR.neutral
end

--- Returns true when a row has a grudge the Forgive button can clear.
function Rows.forgivable(row)
    return row.recorded ~= nil or (tonumber(row.grudges) or 0) > 0
end

--- Sorts faction rows: changed attitudes first, then by name.
function Rows.sort(rows)
    table.sort(rows, function(left, right)
        local leftChanged, rightChanged = Rows.forgivable(left), Rows.forgivable(right)
        if leftChanged ~= rightChanged then return leftChanged end
        return string.lower(tostring(left.name)) < string.lower(tostring(right.name))
    end)
    return rows
end

return Rows
