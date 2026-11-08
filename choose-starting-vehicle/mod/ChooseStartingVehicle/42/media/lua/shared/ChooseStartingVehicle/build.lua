--- A vehicle build: which vehicle, its paint, the item chosen for each part
--- (or "none"), an optional trailer with its own paint and parts, and the items
--- packed in the trunk and glove box. Also the text format saved builds use.
--- Pure Lua.
local Build = {}

Build.NONE = "none"
Build.FORMAT_VERSION = 1

--- Returns an empty build for a vehicle (nil for "no vehicle").
function Build.new(vehicle)
    return { vehicle = vehicle, skin = nil, color = nil, parts = {}, trailer = nil, trunk = {}, glovebox = {} }
end

--- Returns an empty trailer section.
function Build.newTrailer(vehicle)
    return { vehicle = vehicle, skin = nil, parts = {}, cargo = {} }
end

--- Deep-copies a list of {type, count} stacks.
local function copyStacks(stacks)
    local out = {}
    for _, stack in ipairs(stacks or {}) do
        out[#out + 1] = { type = stack.type, count = stack.count }
    end
    return out
end

--- Copies a map of partId -> choice.
local function copyParts(parts)
    local out = {}
    for id, choice in pairs(parts or {}) do
        out[id] = choice
    end
    return out
end

--- Returns an independent copy of a build.
function Build.clone(build)
    if not build then
        return nil
    end
    local copy = Build.new(build.vehicle)
    copy.name = build.name
    copy.skin = build.skin
    copy.color = build.color
    copy.parts = copyParts(build.parts)
    copy.trunk = copyStacks(build.trunk)
    copy.glovebox = copyStacks(build.glovebox)
    if build.trailer then
        copy.trailer = Build.newTrailer(build.trailer.vehicle)
        copy.trailer.skin = build.trailer.skin
        copy.trailer.parts = copyParts(build.trailer.parts)
        copy.trailer.cargo = copyStacks(build.trailer.cargo)
    end
    return copy
end

--- True when no vehicle is chosen.
function Build.isEmpty(build)
    return not build or not build.vehicle or build.vehicle == ""
end

--- Returns the choice stored for a slot: the choice of its first part, or nil
--- for "leave it to the game".
function Build.slotChoice(section, slot)
    return section.parts[slot.partIds[1]]
end

--- Sets (or with nil clears) the choice for every part a slot controls.
function Build.setSlotChoice(section, slot, choice)
    for _, id in ipairs(slot.partIds) do
        section.parts[id] = choice
    end
end

--- Returns the choice stored for one part, or nil for "leave it to the game".
function Build.partChoice(section, partId)
    return section.parts[partId]
end

--- Sets (or with nil clears) the choice for one part, or for every part of its
--- slot when `wholeSlot` is set (all four tires at once).
function Build.setPartChoice(section, partId, choice, slot, wholeSlot)
    if wholeSlot and slot then
        Build.setSlotChoice(section, slot, choice)
    else
        section.parts[partId] = choice
    end
end

--- Adds `count` of an item type to a stack list, merging with an existing stack.
function Build.addStack(stacks, itemType, count)
    count = math.floor(tonumber(count) or 1)
    if count < 1 then
        return stacks
    end
    for _, stack in ipairs(stacks) do
        if stack.type == itemType then
            stack.count = stack.count + count
            return stacks
        end
    end
    stacks[#stacks + 1] = { type = itemType, count = count }
    return stacks
end

--- Sets a stack's count, removing it at zero or below.
function Build.setStackCount(stacks, itemType, count)
    count = math.floor(tonumber(count) or 0)
    for i, stack in ipairs(stacks) do
        if stack.type == itemType then
            if count <= 0 then
                table.remove(stacks, i)
            else
                stack.count = count
            end
            return stacks
        end
    end
    if count > 0 then
        stacks[#stacks + 1] = { type = itemType, count = count }
    end
    return stacks
end

--- Returns the total number of items in a stack list.
function Build.stackTotal(stacks)
    local total = 0
    for _, stack in ipairs(stacks or {}) do
        total = total + stack.count
    end
    return total
end

--- Keeps only the part choices a catalog entry still offers, the skin when it is
--- in range, and stacks whose item exists. Returns the cleaned section and a
--- list of human-readable notes about what was dropped.
function Build.sanitizeSection(section, entry, itemExists, notes)
    local clean = { vehicle = section.vehicle, skin = nil, color = section.color, parts = {} }
    if section.skin and entry.skinCount and section.skin >= 0 and section.skin < entry.skinCount then
        clean.skin = section.skin
    elseif section.skin then
        notes[#notes + 1] = "paint " .. tostring(section.skin)
    end
    local allowed = {}
    for _, slot in ipairs(entry.slots or {}) do
        local options = {}
        if slot.allowNone then
            options[Build.NONE] = true
        end
        for _, option in ipairs(slot.options) do
            options[option.itemType] = true
        end
        for _, id in ipairs(slot.partIds) do
            allowed[id] = options
        end
    end
    for id, choice in pairs(section.parts or {}) do
        if allowed[id] and allowed[id][choice] then
            clean.parts[id] = choice
        else
            notes[#notes + 1] = id .. "=" .. tostring(choice)
        end
    end
    return clean
end

--- Drops stacks whose item no longer exists.
function Build.sanitizeStacks(stacks, itemExists, notes)
    local clean = {}
    for _, stack in ipairs(stacks or {}) do
        if itemExists(stack.type) and stack.count > 0 then
            clean[#clean + 1] = { type = stack.type, count = stack.count }
        else
            notes[#notes + 1] = stack.type
        end
    end
    return clean
end

--- Checks a build against the installed vehicles. `findEntry(name)` returns a
--- catalog entry or nil. Returns the cleaned build (nil when its vehicle is
--- gone) and the notes about what was dropped.
function Build.sanitize(build, findEntry, itemExists)
    local notes = {}
    if Build.isEmpty(build) then
        return nil, notes
    end
    local entry = findEntry(build.vehicle)
    if not entry then
        notes[#notes + 1] = build.vehicle
        return nil, notes
    end
    local main = Build.sanitizeSection(build, entry, itemExists, notes)
    local clean = Build.new(build.vehicle)
    clean.name = build.name
    clean.skin = main.skin
    clean.color = build.color
    clean.parts = main.parts
    clean.trunk = Build.sanitizeStacks(build.trunk, itemExists, notes)
    clean.glovebox = Build.sanitizeStacks(build.glovebox, itemExists, notes)
    if build.trailer and build.trailer.vehicle then
        local trailerEntry = findEntry(build.trailer.vehicle)
        if trailerEntry and trailerEntry.isTrailer then
            local trailer = Build.sanitizeSection(build.trailer, trailerEntry, itemExists, notes)
            clean.trailer = Build.newTrailer(build.trailer.vehicle)
            clean.trailer.skin = trailer.skin
            clean.trailer.parts = trailer.parts
            clean.trailer.cargo = Build.sanitizeStacks(build.trailer.cargo, itemExists, notes)
        else
            notes[#notes + 1] = build.trailer.vehicle
        end
    end
    return clean, notes
end

--- Returns the keys of a table sorted, so saved files are stable.
local function sortedKeys(map)
    local keys = {}
    for key in pairs(map or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

--- Appends the lines that describe one build.
local function writeBuild(lines, build)
    lines[#lines + 1] = "build=" .. (build.name or "")
    lines[#lines + 1] = "vehicle=" .. build.vehicle
    if build.skin then
        lines[#lines + 1] = "skin=" .. tostring(build.skin)
    end
    if build.color then
        lines[#lines + 1] = "color=" .. build.color
    end
    for _, id in ipairs(sortedKeys(build.parts)) do
        lines[#lines + 1] = "part=" .. id .. ":" .. build.parts[id]
    end
    for _, stack in ipairs(build.trunk or {}) do
        lines[#lines + 1] = "trunk=" .. stack.type .. "*" .. tostring(stack.count)
    end
    for _, stack in ipairs(build.glovebox or {}) do
        lines[#lines + 1] = "glovebox=" .. stack.type .. "*" .. tostring(stack.count)
    end
    if build.trailer and build.trailer.vehicle then
        lines[#lines + 1] = "trailer=" .. build.trailer.vehicle
        if build.trailer.skin then
            lines[#lines + 1] = "trailerskin=" .. tostring(build.trailer.skin)
        end
        for _, id in ipairs(sortedKeys(build.trailer.parts)) do
            lines[#lines + 1] = "trailerpart=" .. id .. ":" .. build.trailer.parts[id]
        end
        for _, stack in ipairs(build.trailer.cargo or {}) do
            lines[#lines + 1] = "trailercargo=" .. stack.type .. "*" .. tostring(stack.count)
        end
    end
    lines[#lines + 1] = "end"
end

--- Serializes a list of builds to file lines.
function Build.serialize(builds)
    local lines = { "version=" .. tostring(Build.FORMAT_VERSION) }
    for _, build in ipairs(builds) do
        if not Build.isEmpty(build) then
            writeBuild(lines, build)
        end
    end
    return lines
end

--- Parses "Type*count" into a stack, or nil.
local function parseStack(value)
    local itemType, count = string.match(value, "^(.-)%*(%d+)$")
    if not itemType or itemType == "" then
        return nil
    end
    return { type = itemType, count = tonumber(count) }
end

--- Parses "partId:choice" into its two halves, or nil.
local function parsePart(value)
    local colon = string.find(value, ":", 1, true)
    if not colon then
        return nil
    end
    return string.sub(value, 1, colon - 1), string.sub(value, colon + 1)
end

--- Applies one "key=value" line to the build being read.
local function readLine(build, key, value)
    if key == "vehicle" then
        build.vehicle = value
    elseif key == "skin" then
        build.skin = tonumber(value)
    elseif key == "color" then
        build.color = value
    elseif key == "part" or key == "trailerpart" then
        local id, choice = parsePart(value)
        if id then
            local section = key == "part" and build or build.trailer
            if section then
                section.parts[id] = choice
            end
        end
    elseif key == "trunk" or key == "glovebox" or key == "trailercargo" then
        local stack = parseStack(value)
        local list = (key == "trunk" and build.trunk) or (key == "glovebox" and build.glovebox) or (build.trailer and build.trailer.cargo)
        if stack and list then
            Build.addStack(list, stack.type, stack.count)
        end
    elseif key == "trailer" then
        build.trailer = Build.newTrailer(value)
    elseif key == "trailerskin" and build.trailer then
        build.trailer.skin = tonumber(value)
    end
end

--- Parses file lines back into a list of builds, skipping anything malformed.
function Build.parse(lines)
    local builds = {}
    local current = nil
    for _, raw in ipairs(lines or {}) do
        local line = string.gsub(raw, "\r$", "")
        local eq = string.find(line, "=", 1, true)
        if line == "end" then
            if current and not Build.isEmpty(current) then
                builds[#builds + 1] = current
            end
            current = nil
        elseif eq then
            local key = string.sub(line, 1, eq - 1)
            local value = string.sub(line, eq + 1)
            if key == "build" then
                current = Build.new(nil)
                current.name = value
            elseif current then
                readLine(current, key, value)
            end
        end
    end
    return builds
end

--- Returns the index of the build with this name, or nil.
function Build.indexOf(builds, name)
    for i, build in ipairs(builds) do
        if build.name == name then
            return i
        end
    end
    return nil
end

--- Saves a copy of `build` under `name`, replacing a build with the same name.
function Build.upsert(builds, name, build)
    local copy = Build.clone(build)
    copy.name = name
    local index = Build.indexOf(builds, name)
    if index then
        builds[index] = copy
    else
        builds[#builds + 1] = copy
        table.sort(builds, function(a, b)
            return string.lower(a.name) < string.lower(b.name)
        end)
    end
    return builds
end

--- Removes the build with this name.
function Build.remove(builds, name)
    local index = Build.indexOf(builds, name)
    if index then
        table.remove(builds, index)
    end
    return builds
end

return Build
