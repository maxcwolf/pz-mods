--- Adds "Reputation editor" to the world right-click menu, "Edit relationship"
--- when an A-Life NPC is under the cursor, and "Show reputation button" when
--- the on-screen button has been hidden.
require "ALifeRepEditor/RepEditorWindow"
require "ALifeRepEditor/HudButton"

ALifeRepEditor = ALifeRepEditor or {}

local Menu = {}
ALifeRepEditor.ContextMenu = Menu

--- Returns an object's A-Life uid from its mod data, or nil.
function Menu.uidOf(object)
    if object == nil or type(object.getModData) ~= "function" then return nil end
    local ok, data = pcall(object.getModData, object)
    local uid = ok and type(data) == "table" and data.ProjectALifeUID or nil
    return type(uid) == "string" and uid or nil
end

--- Returns the uids of the moving objects on a square.
function Menu.movingUids(square)
    local result = {}
    if square == nil or type(square.getMovingObjects) ~= "function" then return result end
    local moving = square:getMovingObjects()
    if moving == nil then return result end
    for index = 0, moving:size() - 1 do
        local uid = Menu.uidOf(moving:get(index))
        if uid ~= nil then result[#result + 1] = uid end
    end
    return result
end

--- Returns the A-Life uid of an NPC that was clicked or stands on a clicked square, or nil.
function Menu.npcAt(worldObjects)
    local objects = type(worldObjects) == "table" and worldObjects or {}
    local builder = ProjectALife ~= nil and ProjectALife.MenuBuilder or nil
    if builder ~= nil and type(builder.ownedShell) == "function" and type(builder.clickedSquare) == "function" then
        local uid = Menu.uidOf(builder.ownedShell(objects, builder.clickedSquare(objects)))
        if uid ~= nil then return uid end
    end
    for _, object in ipairs(objects) do
        local uid = Menu.uidOf(object)
        if uid ~= nil then return uid end
    end
    for _, object in ipairs(objects) do
        local square = type(object.getSquare) == "function" and object:getSquare() or nil
        local uid = Menu.movingUids(square)[1]
        if uid ~= nil then return uid end
    end
    return nil
end

--- Returns an NPC's name when this game can read A-Life's records (single player), or nil.
function Menu.nameOf(uid)
    local registry = ProjectALife ~= nil and ProjectALife.ActorRegistry or nil
    local editor = ALifeRepEditor.Editor
    if registry == nil or editor == nil or type(registry.read) ~= "function" then return nil end
    local record = registry.read(uid)
    return type(record) == "table" and editor.nameOf(record) or nil
end

--- Adds the editor's options to a world right-click menu.
function Menu.fill(playerNum, context, worldObjects, test)
    if test then return true end
    if playerNum ~= 0 then return end
    context:addOption(getText("ContextMenu_ALifeRepEditor_Open"), nil, ARE_RepEditorWindow.open)
    local uid = Menu.npcAt(worldObjects)
    if uid ~= nil then
        local name = Menu.nameOf(uid)
        local title = name ~= nil and getText("ContextMenu_ALifeRepEditor_PersonNamed", name)
            or getText("ContextMenu_ALifeRepEditor_Person")
        context:addOption(title, { person = uid }, ARE_RepEditorWindow.open)
    end
    if ARE_HudButton.isHidden() then
        context:addOption(getText("ContextMenu_ALifeRepEditor_ShowButton"), true, ARE_HudButton.show)
    end
end

if type(Events) == "table" and Events.OnFillWorldObjectContextMenu ~= nil then
    Events.OnFillWorldObjectContextMenu.Add(Menu.fill)
end

return Menu
