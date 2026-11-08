--- Adds "Furnish this kitchen..." (or "Furnish by Room...") to the
--- right-click menu on the map, opening the mod on the clicked room.
local Rooms = require("FurnishByRoom/rooms")
local Controller = require("FurnishByRoom/controller")

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

--- Returns the mod room of the clicked square, or nil.
function Menu.clickedRoom(worldobjects)
    local square = Menu.clickedSquare(worldobjects)
    local room = square and square:getRoom()
    return room and Rooms.fromGameName(room:getName()) or nil
end

--- Opens the mod on a room.
function Menu.onOpen(room)
    Controller.open(room)
end

--- Adds the menu entry.
function Menu.onFill(playerNum, context, worldobjects, test)
    if test or playerNum ~= 0 then
        return
    end
    local room = Menu.clickedRoom(worldobjects)
    if room then
        context:addOption(getText("UI_FBR_MenuRoom", string.lower(getText(Rooms.labelKey(room)))), room, Menu.onOpen)
    else
        context:addOption(getText("UI_FBR_Menu"), nil, Menu.onOpen)
    end
end

return Menu
