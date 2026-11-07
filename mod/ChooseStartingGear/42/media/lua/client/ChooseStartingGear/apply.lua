--- Executes a spawn plan against a live IsoPlayer: fills worn bags, attaches
--- items to hotbar slots, equips hand items and loads firearms and magazines.
require "ChooseStartingGear/state"

CSG_Apply = CSG_Apply or {}
local Apply = CSG_Apply

--- Attaches an item to a hotbar slot without an animation, falling back to a
--- raw model attachment when the hotbar is not available.
local function attach(player, hotbar, op, item)
    if hotbar then
        local slotIndex = hotbar:getThisSlotIndex(op.slotType)
        local slot = slotIndex and hotbar.availableSlot[slotIndex]
        if slot then
            if hotbar.attachedItems[slotIndex] then
                hotbar:removeItem(hotbar.attachedItems[slotIndex], false)
            end
            hotbar.attachedItems[slotIndex] = item
            hotbar:attachItem(item, slot.def.attachments[item:getAttachmentType()], slotIndex, slot.def, false)
            return
        end
    end
    player:setAttachedItem(op.model, item)
end

--- Returns the worn item types of a desc or player as one printable string.
local function wornSummary(owner)
    local parts = {}
    for _, worn in ipairs(CSG_Runtime.wornItems(owner)) do
        table.insert(parts, worn.item:getFullType())
    end
    return table.concat(parts, ", ")
end

--- Fills a firearm or magazine to its maximum; returns true when it did.
function Apply.loadAmmo(item)
    local max = item:getMaxAmmo()
    if not max or max <= 0 then
        return false
    end
    if instanceof(item, "HandWeapon") then
        if not item:isRanged() then
            return false
        end
        if item:usesExternalMagazine() then
            item:setContainsClip(true)
        end
        item:setCurrentAmmoCount(max)
        if item:haveChamber() then
            item:setRoundChambered(true)
        end
        return true
    end
    item:setCurrentAmmoCount(max)
    return true
end

--- Adds an item to an inventory and loads it when the selection asks for it.
local function addItem(inventory, fullType, selection)
    local item = inventory:AddItem(fullType)
    if item and selection.options and selection.options.loaded then
        Apply.loadAmmo(item)
    end
    return item
end

--- Puts on the player any item type in `wornTypes` (what the character wore
--- on the creation screen) that the player is missing, so modded clothing and
--- bags are there before gear is attached. Returns how many items were added.
function Apply.ensureWorn(player, wornTypes)
    if not wornTypes then
        return 0
    end
    local have = {}
    for _, worn in ipairs(CSG_Runtime.wornItems(player)) do
        local fullType = worn.item:getFullType()
        have[fullType] = (have[fullType] or 0) + 1
    end
    local added = 0
    for _, fullType in ipairs(wornTypes) do
        if (have[fullType] or 0) > 0 then
            have[fullType] = have[fullType] - 1
        else
            local item = player:getInventory():AddItem(fullType)
            if item then
                local location = item:IsClothing() and item:getBodyLocation() or item:canBeEquipped()
                if location then
                    player:setWornItem(location, item)
                    added = added + 1
                    print("[ChooseStartingGear] wore missing " .. fullType)
                end
            end
        end
    end
    return added
end

--- Gives the player everything in the selection and returns the plan, whose
--- `skipped` list names anything that could not be placed. `wornTypes` is
--- what the character wore on the creation screen, when known.
function Apply.toPlayer(player, selection, wornTypes)
    if not CSG_State.catalogReady() then
        CSG_State.finishCatalog()
    end
    if wornTypes then
        print("[ChooseStartingGear] screen wore: " .. table.concat(wornTypes, ", "))
    end
    print("[ChooseStartingGear] player wears: " .. wornSummary(player))
    Apply.ensureWorn(player, wornTypes)
    local facts = CSG_Runtime.facts(player)
    local plan = CSG_Plan.build(selection, facts)

    local containerByKey = {}
    for _, container in ipairs(facts.containers) do
        containerByKey[container.key] = container
    end
    for _, op in ipairs(plan.containers) do
        local inventory = containerByKey[op.key].item:getInventory()
        for _ = 1, op.count do
            addItem(inventory, op.fullType, selection)
        end
    end

    local hotbar = getPlayerHotbar(player:getPlayerNum())
    if hotbar then
        hotbar:refresh()
    end
    local inventory = player:getInventory()
    for _, op in ipairs(plan.attachments) do
        local item = addItem(inventory, op.fullType, selection)
        if item then
            attach(player, hotbar, op, item)
        end
    end

    for _, op in ipairs(plan.hands) do
        local item = addItem(inventory, op.fullType, selection)
        if item then
            if op.hand == "primary" then
                player:setPrimaryHandItem(item)
                if op.twoHanded then
                    player:setSecondaryHandItem(item)
                end
            else
                player:setSecondaryHandItem(item)
            end
        end
    end

    for _, skipped in ipairs(plan.skipped) do
        print("[ChooseStartingGear] skipped " .. tostring(skipped.what) .. ": " .. tostring(skipped.why))
    end
    return plan
end
