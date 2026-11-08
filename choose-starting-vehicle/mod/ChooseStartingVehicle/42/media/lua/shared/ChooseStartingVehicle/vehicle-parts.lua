--- Reads a vehicle's parts from a real vehicle object (the game keeps no
--- script text for templates, so the final part list only exists once the
--- engine has built a vehicle from its script; ADR 0006), and its paints from
--- the vehicle script's own stored text. Pure: works on whatever object it is
--- handed, so tests can pass fakes.
local ScriptText = require("ChooseStartingVehicle/script-text")

local VehicleParts = {}

--- Turns a Java list (or nil) into a Lua list.
function VehicleParts.toList(javaList)
    local list = {}
    if not javaList then
        return list
    end
    for i = 0, javaList:size() - 1 do
        list[#list + 1] = javaList:get(i)
    end
    return list
end

--- Returns the model ids and files of an engine part's script part.
function VehicleParts.modelsOf(scriptPart)
    local models = {}
    if not scriptPart then
        return models
    end
    for i = 0, scriptPart:getModelCount() - 1 do
        local model = scriptPart:getModel(i)
        if model then
            models[#models + 1] = { id = model:getId(), file = model:getFile() }
        end
    end
    return models
end

--- Reads the facts this mod needs from one engine VehiclePart.
function VehicleParts.readPart(part)
    local container = part:isContainer() == true
    return {
        id = part:getId(),
        itemTypes = VehicleParts.toList(part:getItemType()),
        category = part:getCategory(),
        wheel = part:getWheelIndex() >= 0,
        door = part:getDoor() ~= nil,
        window = part:getWindow() ~= nil,
        container = container,
        capacity = container and part:getContainerCapacity() or 0,
        specificItem = part:isSpecificItem() == true,
        models = VehicleParts.modelsOf(part:getScriptPart()),
    }
end

--- Reads every part of a vehicle object into { order = {ids}, byId = {id = part} }.
function VehicleParts.fromVehicle(vehicle)
    local state = { order = {}, byId = {} }
    for i = 0, vehicle:getPartCount() - 1 do
        local part = VehicleParts.readPart(vehicle:getPartByIndex(i))
        if not state.byId[part.id] then
            state.order[#state.order + 1] = part.id
        end
        state.byId[part.id] = part
    end
    return state
end

--- Returns a part's item types as the engine lists them; the mechanic type
--- suffix of specific items is already part of each name.
function VehicleParts.itemTypes(part)
    return part.itemTypes or {}
end

--- Returns the skin textures of the vehicle blocks in skin index order; the
--- game only counts skins that name a texture.
function VehicleParts.skinTextures(vehicleBlocks)
    local textures = {}
    for _, block in ipairs(vehicleBlocks) do
        for _, skin in ipairs(ScriptText.childBlocks(block, "skin")) do
            local texture = ScriptText.property(skin, "texture")
            if texture and texture ~= "" then
                textures[#textures + 1] = texture
            end
        end
    end
    return textures
end

--- Returns the names of every template the vehicle blocks reference directly.
function VehicleParts.templateNames(vehicleBlocks)
    local names = {}
    for _, block in ipairs(vehicleBlocks) do
        for _, item in ipairs(block.items) do
            if item.key == "template" or item.key == "template!" then
                local value = ScriptText.trim(item.value)
                names[#names + 1] = ScriptText.trim(string.match(value, "^([^/]+)") or value)
            end
        end
    end
    return names
end

return VehicleParts
