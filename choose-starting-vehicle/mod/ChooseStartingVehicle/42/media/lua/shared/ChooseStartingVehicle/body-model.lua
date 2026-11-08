--- Describes the copy of a vehicle's body model script that the preview slot
--- draws (preview-slot.lua). The game's 3D scene paints a vehicle body with
--- the vehicle's first skin, and the slot has no skins, so the scene falls
--- back to the body model's own texture. The copy is the original model
--- script (same mesh, shader, scale, attachments and bone weights) under a new
--- name with the chosen paint as its texture, registered once per vehicle and
--- paint per session. ADR 0009. Pure.
local ScriptText = require("ChooseStartingVehicle/script-text")

local BodyModel = {}

BodyModel.PREFIX = "CSV_PreviewBody_"

--- Returns the model script name of a vehicle's body copy in one paint.
function BodyModel.scriptName(vehicleName, skinIndex)
    return BodyModel.PREFIX .. string.gsub(tostring(vehicleName or ""), "[^%w]", "_") .. "_" .. tostring(skinIndex or 0)
end

--- Returns the module part of a full script name ("Base.X" gives "Base").
function BodyModel.moduleOf(fullType)
    return string.match(tostring(fullType or ""), "^(.+)%.[^%.]+$") or "Base"
end

--- Writes a parsed block back out as script text.
local function write(block, header, lines, indent)
    lines[#lines + 1] = indent .. header
    lines[#lines + 1] = indent .. "{"
    for _, item in ipairs(block.items) do
        if item.block then
            write(item.block, item.block.header, lines, indent .. "\t")
        else
            lines[#lines + 1] = indent .. "\t" .. item.key .. " = " .. item.value .. ","
        end
    end
    lines[#lines + 1] = indent .. "}"
end

--- Returns the copy's script text: the original model block from `body`
--- renamed to `name`, with `texture` in place of any texture it had, or nil
--- when the text holds no model block.
function BodyModel.copyText(body, name, texture)
    local block = ScriptText.findBlock(ScriptText.parse(body or ""), "model")
    if not block then
        return nil
    end
    local copy = { items = { { key = "texture", value = texture } } }
    for _, item in ipairs(block.items) do
        if item.block or string.lower(item.key) ~= "texture" then
            copy.items[#copy.items + 1] = item
        end
    end
    local lines = {}
    write(copy, "model " .. name, lines, "")
    return table.concat(lines, "\n")
end

return BodyModel
