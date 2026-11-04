local P, S, L = CSG_Plan, CSG_Selection, CSG_SlotLogic
local defs = {
    { type = "SmallBeltLeft", name = "Belt Left", attachments = { Wrench = "Wrench Left" } },
    { type = "Back", name = "Back", attachments = { Crowbar = "Back Crowbar" } },
}
local entries = {
    ["Base.Wrench"] = { fullType = "Base.Wrench", attachmentType = "Wrench" },
    ["Base.Crowbar"] = { fullType = "Base.Crowbar", attachmentType = "Crowbar" },
    ["Base.Axe"] = { fullType = "Base.Axe", twoHanded = true },
    ["Base.Pop"] = { fullType = "Base.Pop" },
}
local function facts(wornProvided, wornReplacements, containers)
    return {
        slots = L.availableSlots(wornProvided, defs),
        replacements = L.replacements(wornReplacements, { { type = "Bag", replacement = { Crowbar = "null" } } }),
        containers = containers,
        entryOf = function(t) return entries[t] end,
    }
end

test("plan places everything that fits", function()
    local sel = S.new()
    S.setHand(sel, "primary", "Base.Axe")
    S.setAttachment(sel, "SmallBeltLeft", "Base.Wrench")
    S.setAttachment(sel, "Back", "Base.Crowbar")
    S.addToContainer(sel, "Base.Bag#1", "Base.Pop", 2)
    local plan = P.build(sel, facts({ { "SmallBeltLeft" } }, {}, { { key = "Base.Bag#1" } }))
    eq(#plan.hands, 1)
    eq(plan.hands[1].twoHanded, true)
    eq(#plan.attachments, 2)
    eq(plan.attachments[1].slotType, "Back")
    eq(plan.attachments[1].model, "Back Crowbar")
    eq(plan.attachments[2].model, "Wrench Left")
    eq(#plan.containers, 1)
    eq(plan.containers[1].count, 2)
    eq(#plan.skipped, 0)
end)

test("plan skips missing slots, blocked back items, unworn bags and unknown items", function()
    local sel = S.new()
    S.setAttachment(sel, "SmallBeltLeft", "Base.Wrench")
    S.setAttachment(sel, "Back", "Base.Crowbar")
    S.setHand(sel, "secondary", "Gone.Thing")
    S.addToContainer(sel, "Base.Bag#2", "Base.Pop", 1)
    local plan = P.build(sel, facts({}, { "Bag" }, { { key = "Base.Bag#1" } }))
    eq(#plan.attachments, 0)
    eq(#plan.hands, 0)
    eq(#plan.containers, 0)
    eq(#plan.skipped, 4)
end)

test("retrySelection keeps only the not-worn skips", function()
    local sel = S.new()
    S.setAttachment(sel, "SmallBeltLeft", "Base.Wrench")
    S.setAttachment(sel, "Back", "Base.Crowbar")
    S.setHand(sel, "secondary", "Gone.Thing")
    S.addToContainer(sel, "Base.Bag#2", "Base.Pop", 3)
    local plan = P.build(sel, facts({}, { "Bag" }, { { key = "Base.Bag#1" } }))
    local retry = P.retrySelection(plan)
    eq(retry.attachments.SmallBeltLeft, "Base.Wrench", "slot not worn is retried")
    eq(retry.attachments.Back, nil, "blocked back item is not retried")
    eq(retry.hands.secondary, nil)
    eq(S.containerItems(retry, "Base.Bag#2")[1].count, 3, "unworn bag contents are retried")
end)
