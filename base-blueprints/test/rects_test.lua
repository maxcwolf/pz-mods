local Rects = require("BaseBlueprints/rects")

local function cells(list)
    local out = {}
    for _, p in ipairs(list) do
        out[#out + 1] = { x = p[1], y = p[2] }
    end
    return out
end

test("rects: a filled block becomes one rectangle", function()
    local r = Rects.merge(cells({ { 1, 1 }, { 2, 1 }, { 1, 2 }, { 2, 2 } }))
    eq(#r, 1)
    eq(r[1].x1, 1)
    eq(r[1].x2, 2)
    eq(r[1].y1, 1)
    eq(r[1].y2, 2)
end)

test("rects: gaps split runs and rows", function()
    local r = Rects.merge(cells({ { 1, 1 }, { 3, 1 }, { 1, 2 }, { 1, 4 } }))
    eq(#r, 3)
    -- covered squares add up to the input
    local total = 0
    for _, rect in ipairs(r) do
        total = total + (rect.x2 - rect.x1 + 1) * (rect.y2 - rect.y1 + 1)
    end
    eq(total, 4)
end)

test("rects: border strips cover the edge once", function()
    local strips = Rects.border({ x1 = 0, y1 = 0, x2 = 4, y2 = 3 })
    local total = 0
    for _, rect in ipairs(strips) do
        total = total + (rect.x2 - rect.x1 + 1) * (rect.y2 - rect.y1 + 1)
    end
    eq(total, 5 * 2 + 2 * 2)
end)
