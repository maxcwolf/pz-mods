--- Text keys for map squares ("x,y,z") and square columns ("x,y").
local Keys = {}

--- Returns the key for a square.
function Keys.square(x, y, z)
    return x .. "," .. y .. "," .. z
end

--- Returns the key for every level of one map column.
function Keys.column(x, y)
    return x .. "," .. y
end

--- Splits a square key into numbers x, y, z (nil when malformed).
function Keys.parse(key)
    local x, y, z = string.match(key or "", "^(%-?%d+),(%-?%d+),(%-?%d+)$")
    if not x then
        return nil
    end
    return tonumber(x), tonumber(y), tonumber(z)
end

--- Splits a column key into numbers x, y (nil when malformed).
function Keys.parseColumn(key)
    local x, y = string.match(key or "", "^(%-?%d+),(%-?%d+)$")
    if not x then
        return nil
    end
    return tonumber(x), tonumber(y)
end

--- Returns the column key of a square key.
function Keys.columnOf(key)
    local x, y = Keys.parse(key)
    if not x then
        return nil
    end
    return Keys.column(x, y)
end

--- Orders square keys by level, then row, then column.
function Keys.less(a, b)
    local ax, ay, az = Keys.parse(a)
    local bx, by, bz = Keys.parse(b)
    if az ~= bz then
        return az < bz
    end
    if ay ~= by then
        return ay < by
    end
    return ax < bx
end

--- Returns the keys of a map table, sorted with Keys.less.
function Keys.sorted(map)
    local list = {}
    for key in pairs(map) do
        list[#list + 1] = key
    end
    table.sort(list, Keys.less)
    return list
end

return Keys
