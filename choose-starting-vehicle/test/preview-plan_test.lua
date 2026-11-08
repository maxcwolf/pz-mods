local PreviewPlan = require("ChooseStartingVehicle/preview-plan")

local PARTS = {
    { id = "DAMNBumperFront", slot = {}, itemTypes = { "Base.Bumper", "Base.Bull" },
      models = { { id = "Bumper", file = "B0" }, { id = "Bull", file = "B1" } } },
    { id = "DoorFrontLeft", itemTypes = {}, models = { { id = "Door", file = "D0" } } },
    { id = "Engine", itemTypes = { "Base.Engine" }, models = {} },
}

--- Returns the ids of a model list.
local function ids(list)
    local out = {}
    for i, m in ipairs(list) do out[i] = m.id end
    return out
end

test("preview: part states", function()
    eq(PreviewPlan.partState(PARTS[2], nil), "fixed", "nothing to choose")
    eq(PreviewPlan.partState(PARTS[1], nil), "default", "game's choice")
    eq(PreviewPlan.partState(PARTS[1], "none"), "none", "removed")
    eq(PreviewPlan.partState(PARTS[1], "Base.Bull"), "chosen", "chosen")
end)

test("preview: models follow the choices", function()
    listEq(ids(PreviewPlan.models(PARTS, { DAMNBumperFront = "Base.Bull" })),
        { "part:DAMNBumperFront:Bull", "part:DoorFrontLeft:Door" }, "bull bar and door")
    listEq(ids(PreviewPlan.models(PARTS, { DAMNBumperFront = "none" })), { "part:DoorFrontLeft:Door" }, "bumper removed")
end)

test("preview: diff adds and removes only what changed", function()
    local old = PreviewPlan.models(PARTS, {})
    local new = PreviewPlan.models(PARTS, { DAMNBumperFront = "Base.Bull" })
    local add, remove = PreviewPlan.diff(old, new)
    listEq(ids(add), { "part:DAMNBumperFront:Bull" }, "add")
    listEq(remove, { "part:DAMNBumperFront:Bumper" }, "remove")
    local add2, remove2 = PreviewPlan.diff(new, new)
    eq(#add2 + #remove2, 0, "no change")
end)

test("preview: body texture follows the paint", function()
    eq(PreviewPlan.bodyTexture({ "V/a", "V/b" }, 1), "V/b", "second paint")
    eq(PreviewPlan.bodyTexture({ "V/a" }, nil), "V/a", "game's choice shows the first")
    eq(PreviewPlan.bodyTexture({ "V/a" }, 5), "V/a", "out of range")
    eq(PreviewPlan.bodyTexture({}, 0), nil, "unknown")
end)

test("preview: models with no file or no model script are left out", function()
    local parts = { { id = "Door", itemTypes = {}, models = { { id = "A", file = "Real" }, { id = "B", file = "" }, { id = "C", file = "Gone" } } } }
    listEq(ids(PreviewPlan.models(parts, {}, function(file) return file ~= "Gone" end)), { "part:Door:A" }, "only the real one")
    eq(#PreviewPlan.models(parts, {}), 2, "no lookup still drops the empty file")
end)
