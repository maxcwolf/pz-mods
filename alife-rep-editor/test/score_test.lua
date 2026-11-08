require "ALifeRepEditor/score"
local Score = ALifeRepEditor.Score
local rows = {
    { id = "rep_n1", min = -1000 }, { id = "rep_0", min = -59 }, { id = "rep_p1", min = 60 }, { id = "rep_p2", min = 175 },
}

test("clamp keeps scores in range and rounds", function()
    eq(Score.clamp(1200, -1000, 1000), 1000)
    eq(Score.clamp(-5000, -1000, 1000), -1000)
    eq(Score.clamp(12.6, -1000, 1000), 13)
    eq(Score.clamp("x", -1000, 1000), 0)
end)

test("levelIndexAt finds the band a score sits in", function()
    eq(Score.levelIndexAt(rows, -1000), 1)
    eq(Score.levelIndexAt(rows, -60), 1)
    eq(Score.levelIndexAt(rows, -59), 2)
    eq(Score.levelIndexAt(rows, 59), 2)
    eq(Score.levelIndexAt(rows, 60), 3)
    eq(Score.levelIndexAt(rows, 999), 4)
end)

test("rangeOf ends each band one below the next", function()
    local low, high = Score.rangeOf(rows, 3, 1000)
    eq(low, 60); eq(high, 174)
    low, high = Score.rangeOf(rows, 4, 1000)
    eq(low, 175); eq(high, 1000)
    eq(Score.rangeOf(rows, 9, 1000), nil)
end)

test("levelTarget is the middle of a band, and zero for the band holding zero", function()
    eq(Score.levelTarget(rows, 2, 1000), 0)
    eq(Score.levelTarget(rows, 3, 1000), 117)
    eq(Score.levelTarget(rows, 1, 1000), -530)
    eq(Score.levelTarget(rows, 4, 1000), 588)
end)

test("nudged adds and clamps", function()
    eq(Score.nudged(990, 25, -1000, 1000), 1000)
    eq(Score.nudged(-40, 40, -1000, 1000), 0)
end)

test("fraction maps the range onto 0..1", function()
    eq(Score.fraction(-1000, -1000, 1000), 0)
    eq(Score.fraction(0, -1000, 1000), 0.5)
    eq(Score.fraction(2000, -1000, 1000), 1)
    eq(Score.fraction(5, 10, 10), 0)
end)

test("signed shows an explicit plus sign", function()
    eq(Score.signed(40), "+40"); eq(Score.signed(-40), "-40"); eq(Score.signed(0), "0"); eq(Score.signed(nil), "0")
end)
