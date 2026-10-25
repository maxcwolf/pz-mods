--- Pure model of what the player chose: hand items, one item per attachment
--- slot, and item stacks per worn container. Serializes to a tab-separated
--- text format so the last selection can be remembered between games.
local Selection = {}

--- Creates an empty selection.
function Selection.new()
    return { hands = {}, attachments = {}, containers = {} }
end

--- Builds the key used to address a worn container: its type plus the
--- ordinal among worn containers of that same type.
function Selection.containerKey(fullType, ordinal)
    return fullType .. "#" .. tostring(ordinal or 1)
end

--- Sets or clears (with nil) the item held in a hand slot.
function Selection.setHand(sel, hand, fullType)
    sel.hands[hand] = fullType
end

--- Sets or clears (with nil) the item attached to a hotbar slot type.
function Selection.setAttachment(sel, slotType, fullType)
    sel.attachments[slotType] = fullType
end

--- Returns the ordered list of {fullType, count} stacks chosen for a container.
function Selection.containerItems(sel, key)
    return sel.containers[key] or {}
end

--- Adds n of an item type to a container, merging into an existing stack.
function Selection.addToContainer(sel, key, fullType, n)
    n = n or 1
    local stacks = sel.containers[key]
    if not stacks then
        stacks = {}
        sel.containers[key] = stacks
    end
    for _, stack in ipairs(stacks) do
        if stack.fullType == fullType then
            stack.count = stack.count + n
            return stack
        end
    end
    local stack = { fullType = fullType, count = n }
    table.insert(stacks, stack)
    return stack
end

--- Removes n of an item type from a container, dropping the stack at zero.
function Selection.removeFromContainer(sel, key, fullType, n)
    n = n or 1
    local stacks = sel.containers[key]
    if not stacks then
        return
    end
    for i, stack in ipairs(stacks) do
        if stack.fullType == fullType then
            stack.count = stack.count - n
            if stack.count <= 0 then
                table.remove(stacks, i)
            end
            break
        end
    end
    if #stacks == 0 then
        sel.containers[key] = nil
    end
end

--- Empties one container.
function Selection.clearContainer(sel, key)
    sel.containers[key] = nil
end

--- Sums the weight of everything chosen for a container using a weight lookup.
function Selection.containerWeight(sel, key, weightOf)
    local total = 0
    for _, stack in ipairs(Selection.containerItems(sel, key)) do
        total = total + (weightOf(stack.fullType) or 0) * stack.count
    end
    return total
end

--- Returns true when nothing at all has been chosen.
function Selection.isEmpty(sel)
    if next(sel.hands) or next(sel.attachments) then
        return false
    end
    for _, stacks in pairs(sel.containers) do
        if #stacks > 0 then
            return false
        end
    end
    return true
end

--- Removes every reference to an item type the predicate does not recognize.
function Selection.pruneUnknown(sel, isKnown)
    for hand, fullType in pairs(sel.hands) do
        if not isKnown(fullType) then
            sel.hands[hand] = nil
        end
    end
    for slotType, fullType in pairs(sel.attachments) do
        if not isKnown(fullType) then
            sel.attachments[slotType] = nil
        end
    end
    for key, stacks in pairs(sel.containers) do
        local kept = {}
        for _, stack in ipairs(stacks) do
            if isKnown(stack.fullType) then
                table.insert(kept, stack)
            end
        end
        if #kept > 0 then
            sel.containers[key] = kept
        else
            sel.containers[key] = nil
        end
    end
    return sel
end

--- Returns the sorted keys of a table, for deterministic output.
local function sortedKeys(t)
    local keys = {}
    for k in pairs(t) do
        table.insert(keys, k)
    end
    table.sort(keys)
    return keys
end

--- Serializes a selection to one record per line, fields separated by tabs.
function Selection.serialize(sel)
    local lines = {}
    for _, hand in ipairs(sortedKeys(sel.hands)) do
        table.insert(lines, "hand\t" .. hand .. "\t" .. sel.hands[hand])
    end
    for _, slotType in ipairs(sortedKeys(sel.attachments)) do
        table.insert(lines, "attach\t" .. slotType .. "\t" .. sel.attachments[slotType])
    end
    for _, key in ipairs(sortedKeys(sel.containers)) do
        for _, stack in ipairs(sel.containers[key]) do
            table.insert(lines, "container\t" .. key .. "\t" .. stack.fullType .. "\t" .. tostring(stack.count))
        end
    end
    return table.concat(lines, "\n")
end

--- Splits one line on tabs.
local function fields(line)
    local out = {}
    for field in string.gmatch(line .. "\t", "([^\t]*)\t") do
        table.insert(out, field)
    end
    return out
end

--- Parses text produced by serialize, ignoring malformed lines.
function Selection.deserialize(text)
    local sel = Selection.new()
    for line in string.gmatch(text or "", "[^\r\n]+") do
        local f = fields(line)
        if f[1] == "hand" and f[2] ~= "" and f[3] and f[3] ~= "" then
            sel.hands[f[2]] = f[3]
        elseif f[1] == "attach" and f[2] ~= "" and f[3] and f[3] ~= "" then
            sel.attachments[f[2]] = f[3]
        elseif f[1] == "container" and f[2] ~= "" and f[3] and f[3] ~= "" then
            local count = tonumber(f[4]) or 1
            if count > 0 then
                Selection.addToContainer(sel, f[2], f[3], count)
            end
        end
    end
    return sel
end

CSG_Selection = Selection
return Selection
