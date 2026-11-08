--- Adds "Reputation editor" to the world right-click menu, plus "Show
--- reputation button" when the on-screen button has been hidden.
require "ALifeRepEditor/RepEditorWindow"
require "ALifeRepEditor/HudButton"

ALifeRepEditor = ALifeRepEditor or {}

local Menu = {}
ALifeRepEditor.ContextMenu = Menu

--- Adds the editor's options to a world right-click menu.
function Menu.fill(playerNum, context, worldObjects, test)
    if test then return true end
    if playerNum ~= 0 then return end
    context:addOption(getText("ContextMenu_ALifeRepEditor_Open"), nil, ARE_RepEditorWindow.open)
    if ARE_HudButton.isHidden() then
        context:addOption(getText("ContextMenu_ALifeRepEditor_ShowButton"), true, ARE_HudButton.show)
    end
end

if type(Events) == "table" and Events.OnFillWorldObjectContextMenu ~= nil then
    Events.OnFillWorldObjectContextMenu.Add(Menu.fill)
end

return Menu
