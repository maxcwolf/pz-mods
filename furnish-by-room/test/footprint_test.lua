--- Multi-tile footprints and floor rectangles.
local Footprint = require("FurnishByRoom/footprint")

test("footprint: grid cells land relative to the hovered tile", function()
    local cells = { ["0,0"] = "a", ["0,1"] = "b" }
    local parts = Footprint.parts(5, 5, 1, 0, 0, 1, 2, function(x, y) return cells[x .. "," .. y] end)
    eq(#parts, 2)
    eq(parts[2].x .. "," .. parts[2].y .. "," .. parts[2].z .. "," .. parts[2].sprite, "5,6,1,b")
    local fromSecond = Footprint.parts(5, 5, 0, 0, 1, 1, 2, function(x, y) return cells[x .. "," .. y] end)
    eq(fromSecond[1].y, 4, "hovering the foot puts the head above")
end)

test("footprint: empty grid cells are skipped; single is one part", function()
    local parts = Footprint.parts(0, 0, 0, 0, 0, 2, 2, function(x, y) return (x == y) and "d" or nil end)
    eq(#parts, 2)
    eq(#Footprint.single(1, 2, 0, "s"), 1)
end)

test("footprint: rectangles normalize and cap", function()
    local cells = Footprint.rect(3, 3, 1, 2)
    eq(#cells, 6)
    eq(cells[1].x .. "," .. cells[1].y, "1,2")
    eq(Footprint.rect(0, 0, 100, 100), nil, "too big")
    eq(#Footprint.rect(0, 0, 0, 0), 1)
end)
