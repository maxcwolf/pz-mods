local ScriptText = require("ChooseStartingVehicle/script-text")

test("parse reads a vehicle block with properties and nested parts", function()
    local root = ScriptText.parse([[
module Base
{
    vehicle Car
    {
        mechanicType = 2,
        part Engine
        {
            itemType = Base.Engine,
            table install { time = 5, }
        }
    }
}]])
    local vehicle = ScriptText.findBlock(root, "vehicle")
    eq(vehicle.name, "Car", "name")
    eq(ScriptText.property(vehicle, "mechanicType"), "2", "mechanicType")
    local part = ScriptText.childBlocks(vehicle, "part")[1]
    eq(part.name, "Engine", "part name")
    eq(ScriptText.property(part, "itemType"), "Base.Engine", "itemType")
    eq(#ScriptText.childBlocks(part, "table"), 1, "nested table")
end)

test("parse handles a header on the line before its brace", function()
    local root = ScriptText.parse("template vehicle Bumpers\n{\n part DAMNBumperFront\n {\n itemType = A.B;A.C,\n }\n}")
    local template = ScriptText.findBlock(root, "template")
    eq(template.name, "Bumpers", "template name")
    eq(template.words[2], "vehicle", "second word")
    eq(ScriptText.childBlocks(template, "part")[1].name, "DAMNBumperFront", "part")
end)

test("parse keeps the last property before a closing brace without a comma", function()
    local root = ScriptText.parse("vehicle X { part P { itemType = Base.A } }")
    local part = ScriptText.childBlocks(ScriptText.findBlock(root, "vehicle"), "part")[1]
    eq(ScriptText.property(part, "itemType"), "Base.A", "itemType")
end)

test("parse strips block and line comments", function()
    local root = ScriptText.parse("vehicle X {\n /* part Hidden { itemType = Base.H, } */\n // mechanicType = 9,\n mechanicType = 1,\n}")
    local vehicle = ScriptText.findBlock(root, "vehicle")
    eq(#ScriptText.childBlocks(vehicle, "part"), 0, "commented part")
    eq(ScriptText.property(vehicle, "mechanicType"), "1", "mechanicType")
end)

test("parse keeps values that contain spaces and colons", function()
    local root = ScriptText.parse("vehicle X { offset = 0.0 0.43 -0.07, skills = Mechanics:3, }")
    local vehicle = ScriptText.findBlock(root, "vehicle")
    eq(ScriptText.property(vehicle, "offset"), "0.0 0.43 -0.07", "offset")
    eq(ScriptText.property(vehicle, "skills"), "Mechanics:3", "skills")
end)

test("parse keeps template! keys and source order", function()
    local root = ScriptText.parse("vehicle X { template = A, template! = B, part P { }, template = C/part/D, }")
    local vehicle = ScriptText.findBlock(root, "vehicle")
    local keys = {}
    for _, item in ipairs(vehicle.items) do
        keys[#keys + 1] = item.key or ("block:" .. item.block.name)
    end
    listEq(keys, { "template", "template!", "block:P", "template" }, "order")
end)

test("parse ignores stray words such as imports lists", function()
    local root = ScriptText.parse("module Base { imports { Base } vehicle X { } }")
    eq(ScriptText.findBlock(root, "vehicle").name, "X", "vehicle after imports")
end)

test("words splits on whitespace", function()
    listEq(ScriptText.words("  template   vehicle  X "), { "template", "vehicle", "X" }, "words")
end)
