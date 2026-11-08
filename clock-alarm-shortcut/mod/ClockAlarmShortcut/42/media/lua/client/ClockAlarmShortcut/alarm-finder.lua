--- Finds the alarm the HUD clock is showing. It follows the search in
--- zombie.ui.Clock.resize: for each local player, worn items first, then
--- inventory items that are worn or held. Only digital alarms count, because
--- vanilla only offers "Set Alarm" on digital ones.
local AlarmFinder = {}

--- Tells whether an item is an alarm clock or a wearable alarm (a watch).
function AlarmFinder.isAlarm(item)
    return item ~= nil and (instanceof(item, "AlarmClock") or instanceof(item, "AlarmClockClothing"))
end

--- Tells whether an item is an alarm whose time the player can set.
function AlarmFinder.isSettable(item)
    return AlarmFinder.isAlarm(item) and item:isDigital() == true
end

--- Returns the first settable alarm the player wears, or worn or holds in
--- their main inventory.
function AlarmFinder.findForPlayer(player)
    if player == nil or player:isDead() then return nil end
    local worn = player:getWornItems()
    for i = 0, worn:size() - 1 do
        local item = worn:getItemByIndex(i)
        if AlarmFinder.isSettable(item) then return item end
    end
    local items = player:getInventory():getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if AlarmFinder.isSettable(item) and (item:isWorn() or item:isEquipped()) then return item end
    end
    return nil
end

--- Returns the first local player's settable alarm and that player's number.
function AlarmFinder.find()
    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        local alarm = AlarmFinder.findForPlayer(player)
        if alarm then return alarm, player:getPlayerNum() end
    end
    return nil, nil
end

ClockAlarmShortcut_AlarmFinder = AlarmFinder
return AlarmFinder
