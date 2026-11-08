--- Turns one map square into what a blueprint says it should hold, with the
--- fewest edits: objects that already match stay untouched (with their
--- loot and state), the rest are removed or built.
local Capture = require("BaseBlueprints/capture")
local Build = require("BaseBlueprints/build")
local Diff = require("BaseBlueprints/diff")

local Apply = {}

--- Returns where to insert target object `ti`: right after the nearest
--- earlier target object already on the square, else at the start.
function Apply.insertIndex(live, ti, square)
    local size = square:getObjects():size()
    for tj = ti - 1, 1, -1 do
        local obj = live[tj]
        if obj then
            local index = obj:getObjectIndex()
            if index and index >= 0 then
                return math.min(index + 1, size)
            end
        end
    end
    return 0
end

--- Removes, replaces or adds the square's floor. Returns the floor object.
local function applyFloor(square, step, current, objects, target)
    if step.op == "remove" then
        square:RemoveTileObject(objects[step.current])
        return nil
    end
    local record = target[step.target]
    local floor
    if step.op == "add" then
        floor = square:addFloor(record.sprite)
    else
        floor = objects[step.current]
        floor:setSprite(getSprite(record.sprite))
        floor:clearAttachedAnimSprite()
        if current[step.current].overlay and not record.overlay then
            floor:setOverlaySprite(nil)
        end
    end
    if floor then
        Build.decorate(floor, record)
    end
    return floor
end

--- Applies target records to the square at x, y, z, creating the square if
--- the blueprint puts something where the map has none. Returns stats
--- { kept, removed, added, skipped, problems = { text... } }.
function Apply.square(x, y, z, target)
    local stats = { kept = 0, removed = 0, added = 0, skipped = 0, problems = {} }
    local cell = getCell()
    local square = cell:getGridSquare(x, y, z)
    if not square then
        if #target == 0 then
            return stats
        end
        square = cell:createNewGridSquare(x, y, z, true)
        if not square then
            stats.skipped = #target
            return stats
        end
    end
    local current, objects = Capture.square(square)
    local script = Diff.editScript(current, target)
    if Diff.isEmpty(script) then
        stats.kept = #current
        return stats
    end

    local removals = {}
    for i, ci in ipairs(script.remove) do
        removals[i] = ci
    end
    table.sort(removals, function(a, b) return a > b end)
    for _, ci in ipairs(removals) do
        square:RemoveTileObject(objects[ci])
        stats.removed = stats.removed + 1
    end

    local live = {}
    for ci, ti in pairs(script.keep) do
        live[ti] = objects[ci]
        stats.kept = stats.kept + 1
    end
    if script.floor then
        local floor = applyFloor(square, script.floor, current, objects, target)
        if script.floor.target then
            live[script.floor.target] = floor
        end
        if script.floor.op == "remove" then
            stats.removed = stats.removed + 1
        else
            stats.added = stats.added + 1
        end
    end

    local adds = {}
    for i, ti in ipairs(script.add) do
        adds[i] = ti
    end
    table.sort(adds)
    for _, ti in ipairs(adds) do
        local record = target[ti]
        local obj, placedByGame, why = Build.create(cell, square, record)
        if obj then
            if not placedByGame then
                square:AddSpecialObject(obj, Apply.insertIndex(live, ti, square))
                triggerEvent("OnObjectAdded", obj)
            end
            live[ti] = obj
            stats.added = stats.added + 1
        else
            stats.skipped = stats.skipped + 1
            stats.problems[#stats.problems + 1] = why or "?"
        end
    end

    square:RecalcProperties()
    square:RecalcAllWithNeighbours(true)
    return stats
end

return Apply
