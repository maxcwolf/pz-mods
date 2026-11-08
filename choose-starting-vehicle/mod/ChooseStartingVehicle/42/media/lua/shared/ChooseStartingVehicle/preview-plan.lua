--- Decides what the 3D preview shows for a build section: the body in the
--- chosen paint plus the models of the parts as chosen, and what to add and
--- remove when a choice changes so the scene isn't rebuilt each time. Pure.
local PartModels = require("ChooseStartingVehicle/part-models")

local PreviewPlan = {}

--- Returns a part's state for display: "chosen", "none", "default" (left to
--- the game) or "fixed" (nothing to choose).
function PreviewPlan.partState(part, choice)
    if not part.slot then
        return "fixed"
    end
    if choice == "none" then
        return "none"
    end
    if choice then
        return "chosen"
    end
    return "default"
end

--- Returns the scene id of one part model.
function PreviewPlan.objectId(partId, modelId)
    return "part:" .. partId .. ":" .. tostring(modelId)
end

--- Lists the part models to draw for a section: {id, partId, modelId, file}.
--- Models with no file, or whose model script `modelExists(file)` says is
--- missing, are left out: the scene can't draw them and pinning one breaks it.
function PreviewPlan.models(parts, choices, modelExists)
    local list = {}
    for _, part in ipairs(parts or {}) do
        local choice = choices and choices[part.id]
        for _, model in ipairs(PartModels.forChoice(part, choice)) do
            if model.file and model.file ~= "" and (not modelExists or modelExists(model.file)) then
                list[#list + 1] = {
                    id = PreviewPlan.objectId(part.id, model.id),
                    partId = part.id,
                    modelId = model.id,
                    file = model.file,
                }
            end
        end
    end
    return list
end

--- Returns the models to add and the ids to remove to go from `old` to `new`.
function PreviewPlan.diff(old, new)
    local before, after = {}, {}
    for _, model in ipairs(old or {}) do
        before[model.id] = model
    end
    for _, model in ipairs(new or {}) do
        after[model.id] = model
    end
    local add, remove = {}, {}
    for _, model in ipairs(new or {}) do
        local was = before[model.id]
        if not was or was.file ~= model.file then
            add[#add + 1] = model
        end
    end
    for _, model in ipairs(old or {}) do
        local now = after[model.id]
        if not now or now.file ~= model.file then
            remove[#remove + 1] = model.id
        end
    end
    return add, remove
end

--- Returns the skin texture to paint the body with: the chosen skin, else the
--- first one, or nil when the script's text names none.
function PreviewPlan.bodyTexture(skinTextures, skinIndex)
    if not skinTextures or #skinTextures == 0 then
        return nil
    end
    return skinTextures[(skinIndex or 0) + 1] or skinTextures[1]
end

return PreviewPlan
