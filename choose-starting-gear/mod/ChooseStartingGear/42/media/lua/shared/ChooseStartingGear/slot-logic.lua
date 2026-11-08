--- Pure helpers that mirror how the vanilla hotbar decides which attachment
--- slots exist and which items fit them. No Project Zomboid globals are used
--- here so the module can be unit-tested outside the game.
local SlotLogic = {}

--- Finds the slot definition with the given type in a list of definitions.
function SlotLogic.findSlotDef(slotDefs, slotType)
    for _, def in ipairs(slotDefs) do
        if def.type == slotType then
            return def
        end
    end
    return nil
end

--- Builds the ordered, de-duplicated list of hotbar slots that a set of worn
--- items provides. The Back slot always comes first, as in ISHotbar:refresh.
function SlotLogic.availableSlots(wornProvided, slotDefs)
    local slots = {}
    local seen = {}
    local back = SlotLogic.findSlotDef(slotDefs, "Back")
    if back then
        table.insert(slots, { type = back.type, name = back.name, def = back })
        seen[back.type] = true
    end
    for _, provided in ipairs(wornProvided) do
        for _, slotType in ipairs(provided) do
            local def = SlotLogic.findSlotDef(slotDefs, slotType)
            if def and not seen[def.type] then
                table.insert(slots, { type = def.type, name = def.name, def = def })
                seen[def.type] = true
            end
        end
    end
    return slots
end

--- Merges the Back-slot model replacements contributed by worn items such as
--- backpacks, keyed by attachment type.
function SlotLogic.replacements(wornReplacements, replacementDefs)
    local merged = {}
    for _, replacementName in ipairs(wornReplacements) do
        for _, def in ipairs(replacementDefs) do
            if def.type == replacementName and def.replacement then
                for attachmentType, model in pairs(def.replacement) do
                    merged[attachmentType] = model
                end
            end
        end
    end
    return merged
end

--- Returns the model location an item of the given attachment type would be
--- attached to in a slot, or nil when the slot cannot hold it.
function SlotLogic.attachModel(slotDef, attachmentType, replacements)
    if not slotDef or not attachmentType then
        return nil
    end
    local model = slotDef.attachments and slotDef.attachments[attachmentType]
    if not model then
        return nil
    end
    if slotDef.name == "Back" and replacements and replacements[attachmentType] then
        model = replacements[attachmentType]
    end
    if model == "null" then
        return nil
    end
    return model
end

--- Filters catalog entries down to the ones that can be attached to a slot.
function SlotLogic.eligibleItems(entries, slotDef, replacements)
    local eligible = {}
    for _, entry in ipairs(entries) do
        if SlotLogic.attachModel(slotDef, entry.attachmentType, replacements) then
            table.insert(eligible, entry)
        end
    end
    return eligible
end

CSG_SlotLogic = SlotLogic
return SlotLogic
