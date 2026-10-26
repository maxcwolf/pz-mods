--- Shows the chosen gear on the character preview. The vanilla screen renders
--- the SurvivorDesc directly, which only knows about clothing; to show attached
--- items a preview character is built from the desc and rendered as a live
--- character instead. The vanilla screen re-renders on every mouse move, so
--- the character is only rebuilt when the look, clothing or gear changed.
require "ChooseStartingGear/state"

CSG_Preview = CSG_Preview or {}
local Preview = CSG_Preview
Preview.enabled = true
Preview.avatar = nil
Preview.key = nil

--- Returns a string that changes whenever the desc's look changes.
local function lookKey(desc)
    local visual = desc:getHumanVisual()
    return table.concat({
        tostring(desc:isFemale()),
        tostring(visual:getHairModel()),
        tostring(visual:getBeardModel()),
        tostring(visual:getSkinTextureIndex()),
        tostring(visual:getBodyHairIndex()),
        tostring(visual:getHairColor()),
        tostring(visual:getBeardColor()),
        tostring(visual:getSkinColor()),
    }, "|")
end

--- Returns the cache key for the current desc and selection.
local function previewKey(desc, selection)
    return lookKey(desc) .. "#" .. CSG_Runtime.wornSignature(desc) .. "#" .. CSG_Selection.serialize(selection)
end

--- Builds a fresh preview character from the desc (which copies its clothing),
--- copies the look onto it and attaches the chosen gear. Hand items are not
--- shown: equipping them fires game events that assume a real, in-world player.
local function build(desc, selection)
    local avatar = IsoSurvivor.new(desc, nil, 0, 0, 0)
    avatar:getVisual():copyFrom(desc:getHumanVisual())
    local plan = CSG_Plan.build(selection, CSG_Runtime.facts(desc))
    for _, op in ipairs(plan.attachments) do
        local item = avatar:getInventory():AddItem(op.fullType)
        if item then
            avatar:setAttachedItem(op.model, item)
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
        Preview.key = nil
        return false
    end
    local ok, key = pcall(previewKey, desc, CSG_State.selection)
    if not ok then
        Preview.enabled = false
        print("[ChooseStartingGear] gear preview disabled: " .. tostring(key))
        return false
    end
    if key ~= Preview.key or not Preview.avatar then
        local built, avatar = pcall(build, desc, CSG_State.selection)
        if not built or not avatar then
            Preview.enabled = false
            print("[ChooseStartingGear] gear preview disabled: " .. tostring(avatar))
            return false
        end
        Preview.avatar = avatar
        Preview.key = key
    end
    model:setCharacter(Preview.avatar)
    return true
end

--- Re-renders the preview for the given character creation screen.
function Preview.refresh(screen)
    local desc = MainScreen.instance and MainScreen.instance.desc
    if screen and screen.avatarPanel and desc then
        screen.avatarPanel:setSurvivorDesc(desc)
    end
end
