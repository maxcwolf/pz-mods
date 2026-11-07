--- Adapters that read Project Zomboid Java objects (SurvivorDesc, IsoPlayer,
--- script items) into the plain tables the pure modules work with.
require "ChooseStartingGear/slot-logic"
require "ChooseStartingGear/catalog"
require "ChooseStartingGear/selection"
require "ChooseStartingGear/plan"

CSG_Runtime = CSG_Runtime or {}
local Runtime = CSG_Runtime

--- Converts a Java list of strings into a Lua list.
local function javaListToTable(javaList)
    local out = {}
    if javaList then
        for i = 0, javaList:size() - 1 do
            table.insert(out, javaList:get(i))
        end
    end
    return out
end

--- Returns the worn items of a SurvivorDesc or character in wear order, each
--- with its body location when the game exposes one.
function Runtime.wornItems(owner)
    local out = {}
    local worn = owner and owner:getWornItems()
    if not worn then
        return out
    end
    for i = 0, worn:size() - 1 do
        local item = worn:getItemByIndex(i)
        if item then
            local wornItem = worn:get(i)
            table.insert(out, { item = item, location = wornItem and wornItem:getLocation() or nil })
        end
    end
    return out
end

--- Returns the translated name of a worn-item location. Build 42 hands Lua a
--- plain string here; anything else is shown as-is, and no Java call is probed
--- because the game logs errors even when pcall catches them.
function Runtime.locationName(location)
    if location == nil then
        return nil
    end
    local name = tostring(location)
    local short = string.match(name, "[:/]([^:/]+)$") or name
    return getTextOrNull("UI_ClothingType_" .. name) or getTextOrNull("UI_ClothingType_" .. short) or short
end

--- Lists the hotbar slot types each worn item provides, in wear order.
function Runtime.wornProvided(owner)
    local out = {}
    for _, worn in ipairs(Runtime.wornItems(owner)) do
        local provided = worn.item:getAttachmentsProvided()
        if provided then
            table.insert(out, javaListToTable(provided))
        end
    end
    return out
end

--- Lists the Back-slot replacement names of worn items such as backpacks.
function Runtime.wornReplacements(owner)
    local out = {}
    for _, worn in ipairs(Runtime.wornItems(owner)) do
        local replacement = worn.item:getAttachmentReplacement()
        if replacement then
            table.insert(out, replacement)
        end
    end
    return out
end

--- Lists the worn containers with a stable key, label, capacity and item.
function Runtime.wornContainers(owner)
    local out = {}
    local ordinals = {}
    for _, worn in ipairs(Runtime.wornItems(owner)) do
        local item = worn.item
        if instanceof(item, "InventoryContainer") then
            local fullType = item:getFullType()
            ordinals[fullType] = (ordinals[fullType] or 0) + 1
            table.insert(out, {
                key = CSG_Selection.containerKey(fullType, ordinals[fullType]),
                fullType = fullType,
                item = item,
                name = item:getDisplayName(),
                locationName = Runtime.locationName(worn.location),
                capacity = item:getCapacity(),
            })
        end
    end
    return out
end

--- Returns the facts Plan.build needs, for a desc (preview) or a player (spawn).
function Runtime.facts(owner)
    return {
        slots = CSG_SlotLogic.availableSlots(Runtime.wornProvided(owner), ISHotbarAttachDefinition),
        replacements = CSG_SlotLogic.replacements(Runtime.wornReplacements(owner), ISHotbarAttachDefinition.replacements or {}),
        containers = Runtime.wornContainers(owner),
        entryOf = function(fullType) return CSG_State.entry(fullType) end,
    }
end

--- Returns the full types of everything a desc or player wears, in order.
function Runtime.wornTypes(owner)
    local types = {}
    for _, worn in ipairs(Runtime.wornItems(owner)) do
        table.insert(types, worn.item:getFullType())
    end
    return types
end

--- Builds a cheap string that changes whenever the worn items change.
function Runtime.wornSignature(owner)
    local parts = {}
    for _, worn in ipairs(Runtime.wornItems(owner)) do
        table.insert(parts, worn.item:getFullType())
    end
    return table.concat(parts, "|")
end

--- Reads one script item into plain facts, instancing it to learn the
--- attachment type that script items do not expose directly.
function Runtime.rawItem(script)
    local fullType = script:getFullName()
    local raw = {
        fullType = fullType,
        displayName = script:getDisplayName(),
        hidden = script:isHidden(),
        obsolete = script:getObsolete(),
        weight = script:getActualWeight(),
        category = script:getDisplayCategory(),
        icon = script:getNormalTexture(),
    }
    if CSG_Catalog.isExcluded(raw) then
        return raw
    end
    local ok, inst = pcall(instanceItem, fullType)
    if ok and inst then
        raw.attachmentType = inst:getAttachmentType()
        raw.maxAmmo = inst:getMaxAmmo()
        if instanceof(inst, "InventoryContainer") then
            raw.isContainer = true
            raw.capacity = inst:getCapacity()
            local location = inst:canBeEquipped()
            if location then
                raw.equipLocation = location:getTranslationName()
            end
        end
        if instanceof(inst, "HandWeapon") then
            raw.isWeapon = true
            raw.twoHanded = inst:isTwoHandWeapon() or inst:isRequiresEquippedBothHands()
            raw.isFirearm = inst:isRanged()
        end
    end
    return raw
end
