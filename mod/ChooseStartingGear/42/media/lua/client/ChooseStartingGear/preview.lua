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

--- Builds a fresh preview character from the desc (which copies its look and
--- clothing) and attaches the chosen gear to it.
local function sync(desc, selection)
    local avatar = IsoSurvivor.new(desc, nil, 0, 0, 0)
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
    return avatar
end

--- Renders the gear on the avatar panel's 3D model; returns false when the
--- vanilla desc-only preview should be used instead.
function Preview.apply(avatarPanel, desc)
    if not Preview.enabled or not desc or not CSG_State.catalogReady() then
        return false
    end
    local model = avatarPanel and avatarPanel.avatarPanel
    if not model or not MainScreen.instance or CSG_Selection.isEmpty(CSG_State.selection) then
        return false
    end
    local ok, avatar = pcall(sync, desc, CSG_State.selection)
    if not ok or not avatar then
        Preview.enabled = false
        print("[ChooseStartingGear] gear preview disabled: " .. tostring(avatar))
        return false
    end
    Preview.avatar = avatar
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
