--- Plans the preview slot: a vehicle script this mod ships
--- (media/scripts/vehicles/CSV_PreviewVehicle.txt) that is never spawned.
--- The 3D view rebuilds it from the vehicle being chosen and lets the game's
--- 3D scene draw it like any vehicle, with its own shaders, paint and
--- bone-rigged doors. The slot gets the chosen vehicle's final parts and
--- wheels (copyPartsFrom/copyWheelsFrom). It then loads an override that
--- points every unchosen part model at a file that doesn't exist, which the
--- scene skips, and uses a body model whose texture is the chosen paint.
--- Parts left over from a vehicle shown earlier are hidden the same way.
--- The scene draws, for every model entry of a part, the part's first loaded
--- model at that entry's offset, rotation and scale (42.21
--- VehicleRenderData.initPartModel). So a hidden entry in a part that still
--- shows a model also takes that model's file, transform and attachments: its
--- extra draw lands exactly on the shown one instead of showing a ghost copy.
--- The file matters too: the scene reads each entry's model-script scale and
--- invertX from the entry's own file, so a missing file draws the shown mesh
--- unscaled (a KI5 spare tire at scale 0.098 came out ten times too big).
--- Lua can't register new vehicle scripts, so the one slot is reused.
--- ADR 0009. Pure.
local ScriptText = require("ChooseStartingVehicle/script-text")

local PreviewSlot = {}

PreviewSlot.NAME = "CSV_PreviewVehicle"
PreviewSlot.FULL_NAME = "Base.CSV_PreviewVehicle"
PreviewSlot.HIDDEN_FILE = "CSV_PreviewHidden"

--- Returns the lookup key of one part model; a model with no id uses "".
function PreviewSlot.key(partId, modelId)
    return tostring(partId) .. "\n" .. tostring(modelId or "")
end

--- Returns a set holding each value of a list.
local function setOf(list)
    local set = {}
    for _, value in ipairs(list or {}) do
        set[value] = true
    end
    return set
end

--- Lists the slot's part models to hide as {partId, modelId, like}.
--- `slotParts` is what the slot holds after the copy: {id, models = {{id,
--- file, offset, rotate, scale, parent, self}...}}. A part the chosen vehicle
--- doesn't have is left over from an earlier vehicle, so all of it is hidden.
--- A part the build manages (`managedIds`) keeps only the models in `wanted`
--- (a set of keys). Other parts are left as they are. `like` is the part's
--- first shown model, whose transform a hidden entry takes, or nil.
function PreviewSlot.hidden(slotParts, originalIds, managedIds, wanted)
    local original, managed = setOf(originalIds), setOf(managedIds)
    local list = {}
    for _, part in ipairs(slotParts or {}) do
        local leftover = not original[part.id]
        if leftover or managed[part.id] then
            local shown, hide = nil, {}
            for _, model in ipairs(part.models or {}) do
                if leftover or not wanted[PreviewSlot.key(part.id, model.id)] then
                    hide[#hide + 1] = model
                elseif not shown then
                    shown = model
                end
            end
            for _, model in ipairs(hide) do
                list[#list + 1] = { partId = part.id, modelId = model.id, like = shown }
            end
        end
    end
    return list
end

--- Returns the set of wanted keys for a list of planned part models.
function PreviewSlot.wantedSet(models)
    local set = {}
    for _, model in ipairs(models or {}) do
        set[PreviewSlot.key(model.partId, model.modelId)] = true
    end
    return set
end

--- Reads the vehicle-level texture keys (textureMask, textureRust, ...) from
--- a vehicle's kept text bodies as an ordered list of {key, value}; later
--- bodies override earlier ones.
function PreviewSlot.textures(bodies)
    local order, values = {}, {}
    for _, body in ipairs(bodies or {}) do
        local block = ScriptText.findBlock(ScriptText.parse(body), "vehicle")
        for _, item in ipairs(block and block.items or {}) do
            if item.key and string.match(item.key, "^texture%u") then
                if values[item.key] == nil then
                    order[#order + 1] = item.key
                end
                values[item.key] = ScriptText.trim(item.value)
            end
        end
    end
    local list = {}
    for _, key in ipairs(order) do
        list[#list + 1] = { key = key, value = values[key] }
    end
    return list
end

--- True when a texture list names the paint mask the vehicle shader needs.
function PreviewSlot.hasMask(textures)
    for _, t in ipairs(textures or {}) do
        if t.key == "textureMask" and t.value ~= "" then
            return true
        end
    end
    return false
end

--- Formats a number for script text without float noise.
local function number(value)
    return string.format("%.6g", value or 0)
end

--- Formats a vector {x, y, z} for script text.
local function vector(v)
    v = v or {}
    return number(v[1]) .. " " .. number(v[2]) .. " " .. number(v[3])
end

--- Returns the override script text: the body model (file, scale, offset,
--- rotate), the vehicle's texture keys, and every hidden part model pointed
--- at the missing file.
function PreviewSlot.overrideText(body, textures, hidden)
    local lines = {
        "vehicle " .. PreviewSlot.NAME,
        "{",
        "\tmodel",
        "\t{",
        "\t\tfile = " .. body.file .. ",",
        "\t\tscale = " .. number(body.scale) .. ",",
        "\t\toffset = " .. vector(body.offset) .. ",",
        "\t\trotate = " .. vector(body.rotate) .. ",",
        "\t}",
    }
    for _, t in ipairs(textures or {}) do
        lines[#lines + 1] = "\t" .. t.key .. " = " .. t.value .. ","
    end
    for _, model in ipairs(hidden or {}) do
        local header = model.modelId and model.modelId ~= "" and ("model " .. model.modelId) or "model"
        lines[#lines + 1] = "\tpart " .. model.partId
        lines[#lines + 1] = "\t{"
        lines[#lines + 1] = "\t\t" .. header
        lines[#lines + 1] = "\t\t{"
        local like = model.like
        lines[#lines + 1] = "\t\t\tfile = " .. ((like and like.file) or PreviewSlot.HIDDEN_FILE) .. ","
        if like then
            lines[#lines + 1] = "\t\t\toffset = " .. vector(like.offset) .. ","
            lines[#lines + 1] = "\t\t\trotate = " .. vector(like.rotate) .. ","
            lines[#lines + 1] = "\t\t\tscale = " .. number(like.scale) .. ","
            lines[#lines + 1] = "\t\t\tattachmentParent = " .. (like.parent or "") .. ","
            lines[#lines + 1] = "\t\t\tattachmentSelf = " .. (like.self or "") .. ","
        end
        lines[#lines + 1] = "\t\t}"
        lines[#lines + 1] = "\t}"
    end
    lines[#lines + 1] = "}"
    return table.concat(lines, "\n")
end

--- Returns a string that changes whenever what the slot should show changes.
function PreviewSlot.signature(vehicleName, skinIndex, wanted)
    local keys = {}
    for key in pairs(wanted or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return tostring(vehicleName) .. "|" .. tostring(skinIndex) .. "|" .. table.concat(keys, ";")
end

return PreviewSlot
