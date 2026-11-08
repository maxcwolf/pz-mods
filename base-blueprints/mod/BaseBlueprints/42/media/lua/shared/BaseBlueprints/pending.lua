--- Blueprint squares waiting to be applied, kept in the save's mod data. The
--- map only exists around the player, so each square is applied once its map
--- column has loaded, and then crossed off so it never applies twice.
local Keys = require("BaseBlueprints/keys")

local Pending = {}

--- Makes sure the save state has its tables and returns it.
function Pending.init(root)
    root.columns = root.columns or {}
    root.runs = root.runs or {}
    return root
end

--- Removes any waiting squares of one blueprint.
function Pending.cancel(root, id)
    Pending.init(root)
    local emptied = {}
    for col, entries in pairs(root.columns) do
        local kept = {}
        for _, entry in ipairs(entries) do
            if entry.bp ~= id then
                kept[#kept + 1] = entry
            end
        end
        if #kept == 0 then
            emptied[#emptied + 1] = col
        else
            root.columns[col] = kept
        end
    end
    for _, col in ipairs(emptied) do
        root.columns[col] = nil
    end
    root.runs[id] = nil
end

--- Queues every square of a blueprint (key -> records). A blueprint queued
--- again replaces its earlier queue. Returns the number of squares queued.
function Pending.schedule(root, id, name, squares)
    Pending.cancel(root, id)
    local total = 0
    for _, key in ipairs(Keys.sorted(squares)) do
        local x, y, z = Keys.parse(key)
        if x then
            local col = Keys.column(x, y)
            root.columns[col] = root.columns[col] or {}
            local list = root.columns[col]
            list[#list + 1] = { bp = id, z = z, objects = squares[key] }
            total = total + 1
        end
    end
    root.runs[id] = { name = name, total = total, done = 0, removed = 0, added = 0, skipped = 0 }
    return total
end

--- Takes and returns the waiting entries of one column (nil when none).
function Pending.take(root, col)
    Pending.init(root)
    local entries = root.columns[col]
    root.columns[col] = nil
    return entries
end

--- Returns every column key that still has waiting squares, sorted.
function Pending.columns(root)
    Pending.init(root)
    local cols = {}
    for col in pairs(root.columns) do
        cols[#cols + 1] = col
    end
    table.sort(cols)
    return cols
end

--- Adds one applied square's results to its blueprint's totals.
function Pending.record(root, id, stats)
    Pending.init(root)
    local run = root.runs[id]
    if not run then
        return
    end
    run.done = run.done + 1
    run.removed = run.removed + (stats.removed or 0)
    run.added = run.added + (stats.added or 0)
    run.skipped = run.skipped + (stats.skipped or 0)
end

--- Returns how many squares of a blueprint are still waiting.
function Pending.left(root, id)
    local run = root.runs and root.runs[id]
    if not run then
        return 0
    end
    return run.total - run.done
end

return Pending
