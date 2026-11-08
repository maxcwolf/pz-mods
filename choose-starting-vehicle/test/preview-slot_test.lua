local PreviewSlot = require("ChooseStartingVehicle/preview-slot")
local ScriptText = require("ChooseStartingVehicle/script-text")

local key = PreviewSlot.key

--- Builds slot parts from {id, {modelId...}} pairs.
local function parts(list)
    local out = {}
    for _, p in ipairs(list) do
        local models = {}
        for _, id in ipairs(p[2]) do
            models[#models + 1] = { id = id, offset = { 0, 0, 0 }, rotate = { 0, 0, 0 }, scale = 1 }
        end
        out[#out + 1] = { id = p[1], models = models }
    end
    return out
end

test("preview slot: hides unchosen models of managed parts only", function()
    local slot = parts({ { "Bumper", { "Stock", "Bullbar" } }, { "Seat", { "Seat" } }, { "Door", { "Door" } } })
    local wanted = { [key("Bumper", "Bullbar")] = true, [key("Door", "Door")] = true }
    local hidden = PreviewSlot.hidden(slot, { "Bumper", "Seat", "Door" }, { "Bumper", "Door" }, wanted)
    eq(#hidden, 1, "one model hidden")
    eq(hidden[1].partId, "Bumper", "bumper")
    eq(hidden[1].modelId, "Stock", "the unchosen stock bumper")
    eq(hidden[1].like.id, "Bullbar", "takes the shown bull bar's place")
end)

test("preview slot: parts left over from an earlier vehicle are hidden whole", function()
    local slot = parts({ { "Bumper", { "Stock" } }, { "OldRoofrack", { "Rack", "RackBig" } } })
    local hidden = PreviewSlot.hidden(slot, { "Bumper" }, { "Bumper" }, { [key("Bumper", "Stock")] = true })
    eq(#hidden, 2, "both leftover models")
    eq(hidden[1].partId, "OldRoofrack", "leftover part")
    eq(hidden[1].like, nil, "nothing shown there")
end)

test("preview slot: a part set to None hides all its models", function()
    local slot = parts({ { "Roofrack", { "Rack" } } })
    local hidden = PreviewSlot.hidden(slot, { "Roofrack" }, { "Roofrack" }, {})
    eq(#hidden, 1, "roof rack hidden")
end)

test("preview slot: wanted keys come from the planned models", function()
    local set = PreviewSlot.wantedSet({ { partId = "Door", modelId = "Door" }, { partId = "Hood", modelId = nil } })
    ok(set[key("Door", "Door")], "door")
    ok(set[key("Hood", nil)], "a model with no id")
    eq(key("Hood", nil), key("Hood", ""), "nil and empty ids match")
end)

test("preview slot: reads the vehicle's texture keys, later bodies winning", function()
    local textures = PreviewSlot.textures({
        "vehicle A { textureMask = Vehicles/A_Mask, textureRust = Vehicles/A_Rust, skin { texture = Vehicles/A_Shell, } }",
        "vehicle A { textureRust = Vehicles/A_Rust2, }",
    })
    eq(#textures, 2, "two keys, skin textures left out")
    eq(textures[1].key, "textureMask", "mask first")
    eq(textures[2].value, "Vehicles/A_Rust2", "override")
    ok(PreviewSlot.hasMask(textures), "has a mask")
    eq(PreviewSlot.hasMask(PreviewSlot.textures({ "vehicle B { mass = 1, }" })), false, "no mask")
end)

test("preview slot: the override text loads as one vehicle block", function()
    local text = PreviewSlot.overrideText(
        { file = "CSV_PreviewBody_X_1", scale = 0.9, offset = { 0, 0.4778, 0 }, rotate = { 0, 0, 0 } },
        { { key = "textureMask", value = "Vehicles/M" } },
        { { partId = "Roofrack", modelId = "Rack" }, { partId = "Hood", modelId = "" },
          { partId = "Bumper", modelId = "Stock",
            like = { id = "Bullbar", file = "TTBullbar1", offset = { 0, 0.1, 1.5 }, rotate = { 0, 90, 0 }, scale = 0.5, parent = "front" } } })
    local root = ScriptText.parse(text)
    local vehicle = ScriptText.findBlock(root, "vehicle")
    eq(vehicle.name, PreviewSlot.NAME, "the slot's name")
    local body = ScriptText.childBlocks(vehicle, "model")[1]
    eq(ScriptText.property(body, "file"), "CSV_PreviewBody_X_1", "body copy")
    eq(ScriptText.property(body, "scale"), "0.9", "scale")
    eq(ScriptText.property(body, "offset"), "0 0.4778 0", "offset")
    eq(ScriptText.property(vehicle, "textureMask"), "Vehicles/M", "mask")
    local parts = ScriptText.childBlocks(vehicle, "part")
    eq(#parts, 3, "three hidden models")
    local rack = ScriptText.childBlocks(parts[1], "model")[1]
    eq(rack.name, "Rack", "model id")
    eq(ScriptText.property(rack, "file"), PreviewSlot.HIDDEN_FILE, "missing file")
    eq(ScriptText.childBlocks(parts[2], "model")[1].name, nil, "a model with no id")
    eq(ScriptText.property(rack, "offset"), nil, "nothing shown: no transform to copy")
    local stock = ScriptText.childBlocks(parts[3], "model")[1]
    eq(ScriptText.property(stock, "file"), "TTBullbar1",
        "takes the bull bar's file: the scene reads each entry's model-script scale from its own file")
    eq(ScriptText.property(stock, "offset"), "0 0.1 1.5", "takes the bull bar's offset")
    eq(ScriptText.property(stock, "rotate"), "0 90 0", "rotation")
    eq(ScriptText.property(stock, "scale"), "0.5", "scale")
    eq(ScriptText.property(stock, "attachmentParent"), "front", "attachment")
    eq(ScriptText.property(stock, "attachmentSelf"), "", "cleared when the shown one has none")
end)

test("preview slot: the signature changes with vehicle, paint and choices", function()
    local a = PreviewSlot.signature("Base.A", 0, { [key("P", "M")] = true })
    eq(a, PreviewSlot.signature("Base.A", 0, { [key("P", "M")] = true }), "stable")
    ok(a ~= PreviewSlot.signature("Base.A", 1, { [key("P", "M")] = true }), "paint")
    ok(a ~= PreviewSlot.signature("Base.A", 0, {}), "choices")
    ok(a ~= PreviewSlot.signature("Base.B", 0, { [key("P", "M")] = true }), "vehicle")
end)
