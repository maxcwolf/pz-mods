require "ALifeRepEditor/look"
local Look = ALifeRepEditor.Look

test("levelColor is grey at neutral and leans red or green toward the ends", function()
    local neutral = Look.levelColor(6, 6, 11)
    eq(neutral, Look.NEUTRAL)
    local worst, best = Look.levelColor(1, 6, 11), Look.levelColor(11, 6, 11)
    ok(math.abs(worst[1] - Look.BAD[1]) < 1e-9, "worst is fully red")
    ok(math.abs(best[2] - Look.GOOD[2]) < 1e-9, "best is fully green")
    ok(Look.levelColor(5, 6, 11)[2] > worst[2], "a mild bad level is less red")
end)

test("neutralIndex finds the band holding zero", function()
    eq(Look.neutralIndex({ { min = -1000 }, { min = -59 }, { min = 60 } }), 2)
end)

test("fit trims with an ellipsis only when needed", function()
    local measure = function(text) return #text end
    eq(Look.fit("short", 10, measure), "short")
    eq(Look.fit("a much longer line", 10, measure), "a much ...")
end)

test("wrap moves a button that won't fit to the next row", function()
    local places, rows = Look.wrap({ 40, 40, 40 }, 100, 5)
    eq(places[1].x, 0); eq(places[2].x, 45); eq(places[3].row, 1); eq(places[3].x, 0); eq(rows, 2)
end)
