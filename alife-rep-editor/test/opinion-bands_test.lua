require "ALifeRepEditor/opinion-bands"
local Bands = ALifeRepEditor.OpinionBands

local LABELS = {
    { -71, "Hates you" }, { -41, "Resents you" }, { -16, "Distrusts you" }, { 16, "Unsure of you" },
    { 41, "Likes you" }, { 71, "Trusts you" }, { 101, "Would stand by you" },
}

test("fromLabels turns A-Life's 'below' thresholds into band minimums", function()
    local bands = Bands.fromLabels(LABELS, -100)
    eq(#bands, 7)
    eq(bands[1].min, -100); eq(bands[1].label, "Hates you")
    eq(bands[2].min, -71); eq(bands[4].min, -16); eq(bands[7].min, 71)
    eq(#Bands.fromLabels(nil), 7, "falls back to the built-in labels")
end)

test("labelAt agrees with A-Life's own labelOf at every edge", function()
    local bands = Bands.fromLabels(LABELS, -100)
    local labelOf = function(value)
        for _, entry in ipairs(LABELS) do if value < entry[1] then return entry[2] end end
        return LABELS[#LABELS][2]
    end
    for value = -100, 100 do eq(Bands.labelAt(bands, value), labelOf(value), "value " .. value) end
end)

test("target is the middle of a band, and 0 for the band holding 0", function()
    local bands = Bands.fromLabels(LABELS, -100)
    eq(Bands.target(bands, 1, 100), -86)
    eq(Bands.target(bands, 4, 100), 0)
    eq(Bands.target(bands, 5, 100), 28)
    eq(Bands.target(bands, 7, 100), 86)
    for index = 1, 7 do eq(Bands.indexAt(bands, Bands.target(bands, index, 100)), index, "band " .. index) end
end)

test("nudged stays inside -100..100", function()
    eq(Bands.nudged(95, 25), 100)
    eq(Bands.nudged(-90, -25), -100)
    eq(Bands.nudged(10, -5), 5)
end)
