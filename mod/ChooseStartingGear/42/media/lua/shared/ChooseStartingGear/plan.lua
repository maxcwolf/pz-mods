--- Turns a selection plus the facts known at spawn time into a concrete list
--- of operations, and records what had to be skipped and why. Pure.
local Plan = {}

--- Builds the spawn plan.
--- facts = {
---   slots = list of {type, name, def} from SlotLogic.availableSlots,
---   replacements = map from SlotLogic.replacements,
---   containers = list of {key, fullType} worn containers,
---   entryOf = function(fullType) -> catalog entry or nil,
--- }
function Plan.build(sel, facts)
    local plan = { hands = {}, attachments = {}, containers = {}, skipped = {} }
    local entryOf = facts.entryOf or function() return nil end

    for _, hand in ipairs({ "primary", "secondary" }) do
        local fullType = sel.hands[hand]
        if fullType then
            local entry = entryOf(fullType)
            if entry then
                table.insert(plan.hands, { hand = hand, fullType = fullType, twoHanded = entry.twoHanded })
            else
                table.insert(plan.skipped, { what = fullType, why = "unknown item" })
            end
        end
    end

    local slotByType = {}
    for _, slot in ipairs(facts.slots or {}) do
        slotByType[slot.type] = slot
    end
    for slotType, fullType in pairs(sel.attachments) do
        local slot = slotByType[slotType]
        local entry = entryOf(fullType)
        if not entry then
            table.insert(plan.skipped, { what = fullType, why = "unknown item" })
        elseif not slot then
            table.insert(plan.skipped, { what = fullType, why = "slot " .. slotType .. " not worn" })
        else
            local model = CSG_SlotLogic.attachModel(slot.def, entry.attachmentType, facts.replacements)
            if model then
                table.insert(plan.attachments, { slotType = slotType, fullType = fullType, model = model })
            else
                table.insert(plan.skipped, { what = fullType, why = "does not fit " .. slotType })
            end
        end
    end
    table.sort(plan.attachments, function(a, b) return a.slotType < b.slotType end)

    local wornKeys = {}
    for _, container in ipairs(facts.containers or {}) do
        wornKeys[container.key] = true
    end
    local keys = {}
    for key in pairs(sel.containers) do
        table.insert(keys, key)
    end
    table.sort(keys)
    for _, key in ipairs(keys) do
        for _, stack in ipairs(sel.containers[key]) do
            if not wornKeys[key] then
                table.insert(plan.skipped, { what = stack.fullType, why = "container " .. key .. " not worn" })
            elseif not entryOf(stack.fullType) then
                table.insert(plan.skipped, { what = stack.fullType, why = "unknown item" })
            else
                table.insert(plan.containers, { key = key, fullType = stack.fullType, count = stack.count })
            end
        end
    end
    return plan
end

CSG_Plan = Plan
return Plan
