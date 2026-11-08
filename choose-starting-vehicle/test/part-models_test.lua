local PartModels = require("ChooseStartingVehicle/part-models")

--- Builds a part with item types and model ids.
local function part(items, models)
    local list = {}
    for i, id in ipairs(models) do
        list[i] = { id = id, file = id .. "File" }
    end
    return { itemTypes = items, models = list }
end

--- Returns the ids of a model list joined by commas.
local function ids(models)
    local out = {}
    for i, m in ipairs(models) do
        out[i] = m.id
    end
    return table.concat(out, ",")
end

test("part models: one model per item maps by position", function()
    local bumper = part({ "Base.Bumper", "Base.Bull1", "Base.Bull2" }, { "FrontBumper", "FrontBullbar1", "FrontBullbar2" })
    eq(ids(PartModels.forItem(bumper, "Base.Bull1")), "FrontBullbar1", "second item")
    eq(ids(PartModels.forItem(bumper, nil)), "", "empty slot shows nothing")
end)

test("part models: a leading stock model shows when empty and shifts the rest", function()
    local rear = part({ "Base.Rear1", "Base.Rear2" }, { "RearBumper0", "RearBumper1", "RearBumper2" })
    eq(ids(PartModels.forItem(rear, "Base.Rear2")), "RearBumper2", "shifted")
    eq(ids(PartModels.forItem(rear, nil)), "RearBumper0", "stock")
end)

test("part models: a single item or a part with no item list shows every model", function()
    eq(ids(PartModels.forItem(part({ "Base.Armor" }, { "L", "R" }), "Base.Armor")), "L,R", "single item")
    eq(ids(PartModels.forItem(part({}, { "Door" }), nil)), "Door", "fixed part")
    eq(ids(PartModels.forItem(part({ "Base.A" }, {}), "Base.A")), "", "no models")
end)

test("part models: choices map to an item, none, or the first item", function()
    local p = part({ "Base.A", "Base.B" }, { "MA", "MB" })
    eq(ids(PartModels.forChoice(p, "Base.B")), "MB", "chosen")
    eq(ids(PartModels.forChoice(p, "none")), "", "none")
    eq(ids(PartModels.forChoice(p, nil)), "MA", "game's choice")
    eq(ids(PartModels.forChoice(p, "Base.Gone")), "MA", "unknown item falls back")
end)
