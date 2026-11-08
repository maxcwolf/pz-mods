local S = CSG_SlotLogic
local defs = {
    { type = "SmallBeltLeft", name = "Belt Left", attachments = { Wrench = "Wrench Left", Knife = "Belt Left Upside" } },
    { type = "Back", name = "Back", attachments = { Crowbar = "Back Crowbar", Rifle = "Back Rifle" } },
    { type = "AliceSling", name = "Sling", attachments = { Rifle = "AliceSlingRifle" } },
}
local replacementDefs = {
    { type = "Bag", replacement = { Rifle = "Bag Rifle", Crowbar = "null" } },
}

test("availableSlots puts Back first and dedupes", function()
    local slots = S.availableSlots({ { "SmallBeltLeft", "SmallBeltLeft" }, { "AliceSling" }, { "Unknown" } }, defs)
    eq(#slots, 3, "count")
    eq(slots[1].type, "Back")
    eq(slots[2].type, "SmallBeltLeft")
    eq(slots[3].type, "AliceSling")
end)

test("availableSlots with nothing worn still has Back", function()
    local slots = S.availableSlots({}, defs)
    eq(#slots, 1)
    eq(slots[1].name, "Back")
end)

test("replacements merges bag replacement maps", function()
    local r = S.replacements({ "Bag", "Nope" }, replacementDefs)
    eq(r.Rifle, "Bag Rifle")
    eq(r.Crowbar, "null")
end)

test("attachModel honors slot attachments", function()
    eq(S.attachModel(defs[1], "Wrench", {}), "Wrench Left")
    eq(S.attachModel(defs[1], "Rifle", {}), nil)
    eq(S.attachModel(defs[1], nil, {}), nil)
    eq(S.attachModel(nil, "Wrench", {}), nil)
end)

test("attachModel applies Back replacements and null blocks", function()
    local r = S.replacements({ "Bag" }, replacementDefs)
    eq(S.attachModel(defs[2], "Rifle", r), "Bag Rifle")
    eq(S.attachModel(defs[2], "Crowbar", r), nil)
    eq(S.attachModel(defs[3], "Rifle", r), "AliceSlingRifle", "non-Back slot ignores replacements")
end)

test("eligibleItems filters by attachment type", function()
    local entries = {
        { fullType = "Base.Wrench", attachmentType = "Wrench" },
        { fullType = "Base.Crowbar", attachmentType = "Crowbar" },
        { fullType = "Base.Pencil" },
    }
    local items = S.eligibleItems(entries, defs[1], {})
    eq(#items, 1)
    eq(items[1].fullType, "Base.Wrench")
end)
