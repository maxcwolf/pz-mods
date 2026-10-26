--- Shows the chosen gear on the character preview. The vanilla screen renders
--- the SurvivorDesc directly, which only knows about clothing; to show attached
--- and held items the preview character is synced from the desc and rendered
--- as a live character instead.
require "ChooseStartingGear/state"

CSG_Preview = CSG_Preview or {}
local Preview = CSG_Preview
Preview.enabled = true

--- Gives the preview character one item and returns it.
local function giveItem(avatar, fullType)
    return avatar:getInventory():AddItem(fullType)
end

--- Copies the desc onto the preview character and attaches the chosen gear.
local function sync(avatar, desc, selection)
    avatar:setFemale(desc:isFemale())
    avatar:getHumanVisual():copyFrom(desc:getHumanVisual())
    avatar:setWornItems(desc:getWornItems())
    avatar:clearAttachedItems()
    avatar:setPrimaryHandItem(nil)
    avatar:setSecondaryHandItem(nil)
    local plan = CSG_Plan.build(selection, CSG_Runtime.facts(desc))
    for _, op in ipairs(plan.attachments) do
        local item = giveItem(avatar, op.fullType)
        if item then
            avatar:setAttachedItem(op.model, item)
        end
    end
    for _, op in ipairs(plan.hands) do
        local item = giveItem(avatar, op.fullType)
        if item then
            if op.hand == "primary" then
                avatar:setPrimaryHandItem(item)
                if op.twoHanded then
                    avatar:setSecondaryHandItem(item)
                end
            else
                avatar:setSecondaryHandItem(item)
            end
        end
    end
    avatar:resetModelNextFrame()
end

--- Renders the gear on the avatar panel's 3D model; returns false when the
--- vanilla desc-only preview should be used instead.
function Preview.apply(avatarPanel, desc)
    if not Preview.enabled or not desc or not CSG_State.catalogReady() then
        return false
    end
    local avatar = MainScreen.instance and MainScreen.instance.avatar
    local model = avatarPanel and avatarPanel.avatarPanel
    if not avatar or not model or CSG_Selection.isEmpty(CSG_State.selection) then
        return false
    end
    local ok, err = pcall(sync, avatar, desc, CSG_State.selection)
    if not ok then
        Preview.enabled = false
        print("[ChooseStartingGear] gear preview disabled: " .. tostring(err))
        return false
    end
    model:setCharacter(avatar)
    return true
end

--- Re-renders the preview for the given character creation screen.
function Preview.refresh(screen)
    local desc = MainScreen.instance and MainScreen.instance.desc
    if screen and screen.avatarPanel and desc then
        screen.avatarPanel:setSurvivorDesc(desc)
    end
end
