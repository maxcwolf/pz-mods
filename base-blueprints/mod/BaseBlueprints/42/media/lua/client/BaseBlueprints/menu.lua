--- Adds "Base Blueprints" to the right-click menu on the map: claim the
--- building you clicked, show or hide changes, and open the window.
local Area = require("BaseBlueprints/area")
local Runtime = require("BaseBlueprints/runtime")
local Overlay = require("BaseBlueprints/overlay")

local Menu = {}

--- Returns the square of the first clicked object, or nil.
function Menu.clickedSquare(worldobjects)
    for _, obj in ipairs(worldobjects or {}) do
        local square = obj and obj.getSquare and obj:getSquare()
        if square then
            return square
        end
    end
    return nil
end

--- Shows a short message over the player's head.
local function say(text)
    local player = getPlayer()
    if player then
        player:setHaloNote(text, 220, 220, 120, 300)
    end
end

--- Claims the clicked building.
function Menu.onClaim(square, margin)
    local okay, message = Runtime.claimBuilding(square, margin)
    say(message)
    if okay then
        Overlay.setEnabled(true)
    end
    if BBP_BlueprintWindow and BBP_BlueprintWindow.instance then
        BBP_BlueprintWindow.instance:refresh()
    end
end

--- Turns the change highlight on or off.
function Menu.onToggle()
    Overlay.setEnabled(not Overlay.enabled)
end

--- Opens the window.
function Menu.onOpen()
    BBP_BlueprintWindow.open()
end

--- Fills the submenu.
function Menu.onFill(playerNum, context, worldobjects, test)
    if test then
        return
    end
    local square = Menu.clickedSquare(worldobjects)
    local option = context:addOption(getText("UI_BBP_Menu"), worldobjects, nil)
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(option, sub)
    local claim = Runtime.claim()
    if claim then
        sub:addOption(getText(Overlay.enabled and "UI_BBP_HideChanges" or "UI_BBP_ShowChanges"), nil, Menu.onToggle)
    elseif square and Runtime.buildingAt(square) then
        sub:addOption(getText("UI_BBP_ClaimHouse"), square, Menu.onClaim, Area.HOUSE_MARGIN)
        sub:addOption(getText("UI_BBP_ClaimYard", Runtime.int(Area.YARD_MARGIN)), square, Menu.onClaim, Area.YARD_MARGIN)
    end
    sub:addOption(getText("UI_BBP_Open"), nil, Menu.onOpen)
end

return Menu
