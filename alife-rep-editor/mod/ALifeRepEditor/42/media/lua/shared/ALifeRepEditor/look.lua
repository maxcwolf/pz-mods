--- Pure presentation helpers for the window: level colors, trimming text to
--- a width, and laying buttons out in wrapped rows.
ALifeRepEditor = ALifeRepEditor or {}

local Look = {}
ALifeRepEditor.Look = Look

Look.BAD = { 0.9, 0.3, 0.25 }
Look.NEUTRAL = { 0.75, 0.75, 0.75 }
Look.GOOD = { 0.35, 0.8, 0.4 }

--- Mixes two RGB colors; t = 0 gives the first, 1 the second.
function Look.mix(left, right, t)
    return { left[1] + (right[1] - left[1]) * t, left[2] + (right[2] - left[2]) * t, left[3] + (right[3] - left[3]) * t }
end

--- Returns the color of a level: grey at neutral, deeper red or green toward the ends.
function Look.levelColor(index, neutralIndex, count)
    if index == neutralIndex then return Look.NEUTRAL end
    if index < neutralIndex then
        local t = (neutralIndex - index) / math.max(1, neutralIndex - 1)
        return Look.mix(Look.NEUTRAL, Look.BAD, 0.45 + 0.55 * t)
    end
    local t = (index - neutralIndex) / math.max(1, count - neutralIndex)
    return Look.mix(Look.NEUTRAL, Look.GOOD, 0.45 + 0.55 * t)
end

--- Returns the index of the neutral level in a list of level rows.
function Look.neutralIndex(levels)
    for index, row in ipairs(levels) do
        if row.min <= 0 and (levels[index + 1] == nil or levels[index + 1].min > 0) then return index end
    end
    return math.max(1, math.floor((#levels + 1) / 2))
end

--- Trims text with "..." until measure(text) fits the width.
function Look.fit(text, width, measure)
    local value = tostring(text or "")
    if measure(value) <= width then return value end
    local cut = #value
    while cut > 0 and measure(string.sub(value, 1, cut) .. "...") > width do cut = cut - 1 end
    return string.sub(value, 1, cut) .. "..."
end

--- Places buttons of the given widths left to right, wrapping to a new row when one won't fit.
function Look.wrap(widths, maxWidth, gap)
    local places, x, row = {}, 0, 0
    for index, width in ipairs(widths) do
        if x > 0 and x + width > maxWidth then
            x, row = 0, row + 1
        end
        places[index] = { x = x, row = row }
        x = x + width + gap
    end
    return places, row + 1
end

return Look
