--- Test-only model of how the game resolves a vehicle script's parts from its
--- text: templates and part blocks apply in source order, "Template/part/Id"
--- copies one part, "Prefix*" part blocks change every part already defined
--- with that prefix, and specific items get the vehicle's mechanic type
--- appended. The mod reads parts from a real vehicle object instead (ADR 0006),
--- because the game keeps no text for templates; the fidelity tests use this
--- resolver to check the catalog rules against the real script files.
local ScriptText = require("ChooseStartingVehicle/script-text")

local Resolver = {}
local MAX_TEMPLATE_DEPTH = 8

--- Splits an itemType value ("Base.A;Base.B") into a list of trimmed names.
function Resolver.splitItemTypes(value)
    local list = {}
    for piece in string.gmatch(value or "", "[^;]+") do
        local name = ScriptText.trim(piece)
        if name ~= "" then
            list[#list + 1] = name
        end
    end
    return list
end

--- Returns the part record for `id`, creating it in source order when new.
local function ensurePart(state, id)
    local part = state.byId[id]
    if not part then
        part = { id = id, itemTypes = {}, specificItem = true }
        state.byId[id] = part
        state.order[#state.order + 1] = id
    end
    return part
end

--- Copies the facts this mod needs from a part block onto a part record.
local function mergePart(part, block)
    for _, item in ipairs(block.items) do
        if item.key == "itemType" then
            part.itemTypes = Resolver.splitItemTypes(item.value)
        elseif item.key == "specificItem" then
            part.specificItem = string.lower(item.value) ~= "false"
        elseif item.key == "category" then
            part.category = item.value
        elseif item.key == "wheel" then
            part.wheel = item.value
        elseif item.key == "area" then
            part.area = item.value
        elseif item.block then
            local kind = item.block.kind
            if kind == "container" then
                part.container = true
            elseif kind == "door" then
                part.door = true
            elseif kind == "window" then
                part.window = true
            elseif kind == "model" then
                part.models = part.models or {}
                local model = { id = item.block.name, file = ScriptText.property(item.block, "file") }
                local replaced = false
                for i, existing in ipairs(part.models) do
                    if existing.id == model.id then
                        part.models[i] = model
                        replaced = true
                    end
                end
                if not replaced then
                    part.models[#part.models + 1] = model
                end
            end
        end
    end
end

--- Applies one "part Name { ... }" block; a trailing * targets every existing
--- part whose id starts with the prefix.
local function applyPartBlock(state, block)
    local name = block.name
    if not name then
        return
    end
    if string.sub(name, -1) == "*" then
        local prefix = string.sub(name, 1, -2)
        for _, id in ipairs(state.order) do
            if string.sub(id, 1, #prefix) == prefix then
                mergePart(state.byId[id], block)
            end
        end
    else
        mergePart(ensurePart(state, name), block)
    end
end

local processBlock

--- Splits a template value into its name and what it copies: "Name" copies
--- everything, "Name/part/Id" one part, and "Name/passenger/Id" (or any other
--- kind) something that is not a part. Returns name, kind, id.
function Resolver.templateRef(value)
    local slash = string.find(value, "/", 1, true)
    if not slash then
        return ScriptText.trim(value), nil, nil
    end
    local name = ScriptText.trim(string.sub(value, 1, slash - 1))
    local rest = string.sub(value, slash + 1)
    local kind, id = string.match(rest, "^([^/]+)/(.+)$")
    return name, kind or rest, id
end

--- Applies a "template = Name" or "template = Name/part/Id" value.
local function applyTemplate(state, value, findTemplate, depth)
    if depth > MAX_TEMPLATE_DEPTH then
        return
    end
    local name, kind, partId = Resolver.templateRef(value)
    if kind and kind ~= "part" then
        return
    end
    local template = findTemplate(name)
    if not template then
        state.missingTemplates[#state.missingTemplates + 1] = name
        return
    end
    if partId then
        for _, block in ipairs(ScriptText.childBlocks(template, "part")) do
            if block.name == partId then
                applyPartBlock(state, block)
            end
        end
    else
        processBlock(state, template, findTemplate, depth + 1)
    end
end

--- Walks a vehicle or template block in source order.
processBlock = function(state, block, findTemplate, depth)
    for _, item in ipairs(block.items) do
        if item.key == "template" or item.key == "template!" then
            applyTemplate(state, item.value, findTemplate, depth)
        elseif item.block and item.block.kind == "part" then
            applyPartBlock(state, item.block)
        end
    end
end

--- Resolves every part of a vehicle. `vehicleBlocks` is the list of parsed
--- vehicle blocks (a later mod's override comes after the original);
--- `findTemplate(name)` returns a parsed template block or nil.
function Resolver.resolve(vehicleBlocks, findTemplate)
    local state = { order = {}, byId = {}, missingTemplates = {} }
    for _, block in ipairs(vehicleBlocks) do
        processBlock(state, block, findTemplate, 0)
    end
    return state
end

--- Returns the item types a part can hold once the mechanic type suffix the
--- game adds to specific items is applied.
function Resolver.installableTypes(part, mechanicType)
    local list = {}
    for _, name in ipairs(part.itemTypes or {}) do
        if part.specificItem and mechanicType then
            list[#list + 1] = name .. tostring(mechanicType)
        else
            list[#list + 1] = name
        end
    end
    return list
end

return Resolver
