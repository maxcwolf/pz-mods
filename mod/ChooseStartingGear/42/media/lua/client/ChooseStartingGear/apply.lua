--- Executes a spawn plan against a live IsoPlayer: fills worn bags, attaches
--- items to hotbar slots and equips hand items.
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

--- Gives the player everything in the selection and returns the plan, whose
--- `skipped` list names anything that could not be placed.
function Apply.toPlayer(player, selection)
    if not CSG_State.catalogReady() then
        CSG_State.finishCatalog()
    end
    local facts = CSG_Runtime.facts(player)
    local plan = CSG_Plan.build(selection, facts)

    local containerByKey = {}
    for _, container in ipairs(facts.containers) do
        containerByKey[container.key] = container
    end
    for _, op in ipairs(plan.containers) do
        local inventory = containerByKey[op.key].item:getInventory()
        for _ = 1, op.count do
            inventory:AddItem(op.fullType)
        end
    end

    local hotbar = getPlayerHotbar(player:getPlayerNum())
    if hotbar then
        hotbar:refresh()
    end
    local inventory = player:getInventory()
    for _, op in ipairs(plan.attachments) do
        local item = inventory:AddItem(op.fullType)
        if item then
            attach(player, hotbar, op, item)
        end
    end

    for _, op in ipairs(plan.hands) do
        local item = inventory:AddItem(op.fullType)
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
