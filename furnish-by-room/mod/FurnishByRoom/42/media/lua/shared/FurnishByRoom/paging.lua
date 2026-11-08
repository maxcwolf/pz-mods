--- Paging and scrolling sums for the two item lists: the catalog grid
--- (rows that scroll) and the bottom strip (pages of a fixed size).
local Paging = {}

--- Returns the slice of list from first, count long.
function Paging.slice(list, first, count)
    local out = {}
    for i = first, math.min(#list, first + count - 1) do
        out[#out + 1] = list[i]
    end
    return out
end

--- Moves a strip's first index by step pages, staying within the list.
function Paging.step(first, total, size, step)
    if total <= size then
        return 1
    end
    local last = total - size + 1
    local moved = first + step * size
    if moved < 1 then
        return 1
    end
    if moved > last then
        return last
    end
    return moved
end

--- Moves a strip's first index by delta items, staying within the list.
function Paging.scrollBy(first, total, size, delta)
    local last = math.max(1, total - size + 1)
    return math.max(1, math.min(last, first + delta))
end

--- Returns the strip's first index that keeps item index visible.
function Paging.reveal(first, index, total, size)
    if index < first then
        first = index
    elseif index > first + size - 1 then
        first = index - size + 1
    end
    return Paging.step(first, total, size, 0)
end

--- Returns the grid's total content height for n cards.
function Paging.gridHeight(n, columns, cardH, gap)
    local rows = math.ceil(n / columns)
    if rows == 0 then
        return 0
    end
    return rows * cardH + (rows - 1) * gap
end

--- Clamps a scroll offset so content never scrolls past its end.
function Paging.clampScroll(offset, contentH, viewH)
    local max = math.max(0, contentH - viewH)
    if offset < 0 then
        return 0
    end
    if offset > max then
        return max
    end
    return offset
end

--- Returns the card index (1-based) under a point in the grid, or nil.
function Paging.cardAt(x, y, scroll, columns, cardW, cardH, gap, n)
    local cy = y + scroll
    if x < 0 or cy < 0 then
        return nil
    end
    local col = math.floor(x / (cardW + gap))
    local row = math.floor(cy / (cardH + gap))
    if col >= columns then
        return nil
    end
    if x - col * (cardW + gap) > cardW or cy - row * (cardH + gap) > cardH then
        return nil
    end
    local index = row * columns + col + 1
    if index > n then
        return nil
    end
    return index
end

return Paging
