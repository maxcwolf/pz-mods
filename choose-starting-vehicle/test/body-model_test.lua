local BodyModel = require("ChooseStartingVehicle/body-model")
local ScriptText = require("ChooseStartingVehicle/script-text")

local TROOPER = [[
model 89trooperBase
{
    mesh = vehicles/Vehicles_89trooper_Body|trooper_body,
    shader = damn_vehicle_shader,
    texture = Vehicles/Old,
    scale = 0.1,
    attachment roofrack
    {
        offset = 0 1 0,
    }
}
]]

test("body model: one safe script name per vehicle and paint", function()
    eq(BodyModel.scriptName("Base.89trooperOP", 2), "CSV_PreviewBody_Base_89trooperOP_2", "dots replaced, paint added")
    ok(BodyModel.scriptName("Base.A", 0) ~= BodyModel.scriptName("Base.A", 1), "one per paint")
    ok(BodyModel.scriptName("Base.A", 0) ~= BodyModel.scriptName("Base.B", 0), "one per vehicle")
end)

test("body model: module comes from the original's full name", function()
    eq(BodyModel.moduleOf("Base.89trooperBase"), "Base", "Base")
    eq(BodyModel.moduleOf("KI5.Body"), "KI5", "other module")
    eq(BodyModel.moduleOf(nil), "Base", "default")
end)

test("body model: the copy keeps the original and swaps in the paint", function()
    local text = BodyModel.copyText(TROOPER, "CSV_PreviewBody_X_0", "Vehicles/Shell_Green")
    local block = ScriptText.findBlock(ScriptText.parse(text), "model")
    eq(block.name, "CSV_PreviewBody_X_0", "renamed")
    eq(ScriptText.property(block, "shader"), "damn_vehicle_shader", "the vehicle shader is kept")
    eq(ScriptText.property(block, "mesh"), "vehicles/Vehicles_89trooper_Body|trooper_body", "mesh")
    eq(ScriptText.property(block, "scale"), "0.1", "scale")
    eq(ScriptText.property(block, "texture"), "Vehicles/Shell_Green", "the chosen paint")
    local textures = 0
    for _, item in ipairs(block.items) do
        if item.key == "texture" then textures = textures + 1 end
    end
    eq(textures, 1, "the old texture is dropped")
    local attachment = ScriptText.childBlocks(block, "attachment")[1]
    ok(attachment, "attachments kept for parts that hang off the body")
    eq(ScriptText.property(attachment, "offset"), "0 1 0", "attachment offset")
    eq(BodyModel.copyText("vehicle X { }", "Y", "Z"), nil, "no model block")
end)
