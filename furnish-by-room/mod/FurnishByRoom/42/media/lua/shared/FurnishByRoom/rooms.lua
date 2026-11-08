--- The six room types in tab order, and how the game's own room names
--- (kitchen, livingroom, garagestorage, ww_bar...) map onto them.
local Rooms = {}

Rooms.ORDER = { "kitchen", "bedroom", "living", "dining", "bar", "garage" }

--- Substrings of a game room name, checked in order. A nil room means the
--- name is a shop or business that only looks like a home room.
local RULES = {
    { "kitchenwares", nil },
    { "kitchen", "kitchen" },
    { "dining", "dining" },
    { "livingroom", "living" },
    { "lounge", "living" },
    { "bedroom", "bedroom" },
    { "motelroom", "bedroom" },
    { "barber", nil },
    { "barcounter", "bar" },
    { "beergarden", "bar" },
    { "garage", "garage" },
    { "shed", "garage" },
    { "storage", "garage" },
}

--- Returns true when id is one of the six rooms.
function Rooms.isRoom(id)
    for _, room in ipairs(Rooms.ORDER) do
        if room == id then
            return true
        end
    end
    return false
end

--- Returns the mod room for a game room name, or nil when none fits.
function Rooms.fromGameName(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end
    local n = string.lower(name)
    if n == "bar" or string.sub(n, -4) == "_bar" then
        return "bar"
    end
    for _, rule in ipairs(RULES) do
        if string.find(n, rule[1], 1, true) then
            return rule[2]
        end
    end
    return nil
end

--- Picks the room to open on: the one the player stands in, else the last
--- one used, else the kitchen.
function Rooms.pick(detected, last)
    if Rooms.isRoom(detected) then
        return detected
    end
    if Rooms.isRoom(last) then
        return last
    end
    return Rooms.ORDER[1]
end

--- Returns the translation key for a room's tab label.
function Rooms.labelKey(id)
    return "UI_FBR_Room_" .. tostring(id)
end

return Rooms
