--- Turns sets of squares into as few rectangles as practical, so the
--- highlight draws a handful of areas instead of one per tile.
local Rects = {}

--- Merges cells ({ x, y } pairs) into rectangles { x1, y1, x2, y2 }
--- (inclusive). Rows are split into runs, then equal runs on consecutive
--- rows are joined.
function Rects.merge(cells)
    local rows = {}
    local ys = {}
    for _, cell in ipairs(cells) do
        if not rows[cell.y] then
            rows[cell.y] = {}
            ys[#ys + 1] = cell.y
        end
        rows[cell.y][cell.x] = true
    end
    table.sort(ys)

    local rects = {}
    local open = {}
    for _, y in ipairs(ys) do
        local xs = {}
        for x in pairs(rows[y]) do
            xs[#xs + 1] = x
        end
        table.sort(xs)
        local runs = {}
        local i = 1
        while i <= #xs do
            local x1 = xs[i]
            local x2 = x1
            while xs[i + 1] == x2 + 1 do
                i = i + 1
                x2 = xs[i]
            end
            runs[#runs + 1] = { x1 = x1, x2 = x2 }
            i = i + 1
        end
        local nextOpen = {}
        for _, run in ipairs(runs) do
            local id = run.x1 .. ":" .. run.x2
            local rect = open[id]
            if rect and rect.y2 == y - 1 then
                rect.y2 = y
            else
                rect = { x1 = run.x1, y1 = y, x2 = run.x2, y2 = y }
                rects[#rects + 1] = rect
            end
            nextOpen[id] = rect
        end
        open = nextOpen
    end
    return rects
end

--- Returns the four one-tile strips along the edge of an area's footprint.
function Rects.border(area)
    return {
        { x1 = area.x1, y1 = area.y1, x2 = area.x2, y2 = area.y1 },
        { x1 = area.x1, y1 = area.y2, x2 = area.x2, y2 = area.y2 },
        { x1 = area.x1, y1 = area.y1 + 1, x2 = area.x1, y2 = area.y2 - 1 },
        { x1 = area.x2, y1 = area.y1 + 1, x2 = area.x2, y2 = area.y2 - 1 },
    }
end

return Rects
