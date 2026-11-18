--- Pure helpers for one NPC's opinion of you (-100..100). A-Life names
--- opinions with labels like "Distrusts you" and "Likes you"; this turns that
--- label table into bands with a lowest value each, so the same math as the
--- personal level bar can place, color and jump between them.
require "ALifeRepEditor/score"

ALifeRepEditor = ALifeRepEditor or {}

local Score = ALifeRepEditor.Score
local Bands = { MIN = -100, MAX = 100 }
ALifeRepEditor.OpinionBands = Bands

-- A-Life 1.5's labels, used when its table isn't available.
Bands.FALLBACK = {
    { -71, "Hates you" }, { -41, "Resents you" }, { -16, "Distrusts you" }, { 16, "Unsure of you" },
    { 41, "Likes you" }, { 71, "Trusts you" }, { 101, "Would stand by you" },
}

--- Turns A-Life's { below, label } list into bands { min, label } sorted low to high.
function Bands.fromLabels(labels, minimum)
    local source = type(labels) == "table" and #labels > 0 and labels or Bands.FALLBACK
    local bands, low = {}, tonumber(minimum) or Bands.MIN
    for index, entry in ipairs(source) do
        bands[index] = { min = index == 1 and low or tonumber(source[index - 1][1]), label = tostring(entry[2]) }
    end
    return bands
end

--- Returns the index of the band that holds a value.
function Bands.indexAt(bands, value)
    return Score.levelIndexAt(bands, value)
end

--- Returns the label for a value.
function Bands.labelAt(bands, value)
    local band = bands[Bands.indexAt(bands, value)]
    return band ~= nil and band.label or ""
end

--- Returns the value to set when jumping to a band: its middle, or 0 for the band holding 0.
function Bands.target(bands, index, maximum)
    return Score.levelTarget(bands, index, tonumber(maximum) or Bands.MAX)
end

--- Returns the lowest and highest value of a band.
function Bands.rangeOf(bands, index, maximum)
    return Score.rangeOf(bands, index, tonumber(maximum) or Bands.MAX)
end

--- Returns a value moved by delta and kept inside the opinion range.
function Bands.nudged(value, delta, minimum, maximum)
    return Score.nudged(value, delta, tonumber(minimum) or Bands.MIN, tonumber(maximum) or Bands.MAX)
end

return Bands
