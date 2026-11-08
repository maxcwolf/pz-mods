--- Pure score math for A-Life's personal reputation: clamping, finding the
--- level a score sits in, and picking a score for "jump to level".
ALifeRepEditor = ALifeRepEditor or {}

local Score = {}
ALifeRepEditor.Score = Score

--- Clamps a score into [low, high] and rounds it to a whole number.
function Score.clamp(score, low, high)
    local value = math.floor((tonumber(score) or 0) + 0.5)
    if value < low then value = low end
    if value > high then value = high end
    return value
end

--- Returns the index of the level row whose band holds the score (rows sorted by min).
function Score.levelIndexAt(rows, score)
    local value = tonumber(score) or 0
    local found = 1
    for index = 1, #rows do
        if value >= rows[index].min then found = index end
    end
    return found
end

--- Returns the lowest and highest score of a level row.
function Score.rangeOf(rows, index, high)
    local row = rows[index]
    if row == nil then return nil, nil end
    local nextRow = rows[index + 1]
    return row.min, nextRow ~= nil and nextRow.min - 1 or high
end

--- Returns the score to set when jumping to a level: the middle of its band.
function Score.levelTarget(rows, index, high)
    local low, top = Score.rangeOf(rows, index, high)
    if low == nil then return nil end
    if low <= 0 and top >= 0 then return 0 end
    return math.floor((low + top) / 2 + 0.5)
end

--- Returns the score after a nudge, kept inside the score range.
function Score.nudged(score, delta, low, high)
    return Score.clamp((tonumber(score) or 0) + (tonumber(delta) or 0), low, high)
end

--- Returns where a score sits along the range as a 0..1 fraction.
function Score.fraction(score, low, high)
    if high <= low then return 0 end
    local value = Score.clamp(score, low, high)
    return (value - low) / (high - low)
end

--- Formats a score change with an explicit sign, using ASCII so every font shows it.
function Score.signed(delta)
    local value = math.floor((tonumber(delta) or 0) + 0.5)
    if value > 0 then return "+" .. tostring(value) end
    return tostring(value)
end

return Score
