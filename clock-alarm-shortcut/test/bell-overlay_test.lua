local Overlay = ClockAlarmShortcut_BellOverlay
local S = PZ_Stubs

--- Gives the only local player a worn digital watch and returns it.
local function wearWatch()
    local watch = S.alarm("AlarmClockClothing", true)
    S.players = { S.player(0, { watch }, {}) }
    return watch
end

--- Builds an overlay already synced to the fake clock.
local function newOverlay()
    local overlay = Overlay:new()
    overlay:prerender()
    return overlay
end

test("the overlay covers the small clock's bell in screen coordinates", function()
    local overlay = newOverlay()
    eq(overlay.x, 1061, "x")
    eq(overlay.y, 24, "y")
    eq(overlay.width, 19, "width")
    eq(overlay.height, 15, "height")
end)

test("the overlay follows the large clock option", function()
    S.clockSizeOption = 2
    local overlay = newOverlay()
    eq(overlay.x, 1121, "x")
    eq(overlay.width, 30, "width")
end)

test("live texture sizes win over the fallback sizes", function()
    S.textures["media/ui/ClockAssets/ClockAlarmMediumSet.png"] = { 25, 20 }
    local overlay = newOverlay()
    eq(overlay.width, 25, "width")
    eq(overlay.height, 20, "height")
end)

test("the overlay shrinks to nothing while the clock is hidden", function()
    S.clock.visible = false
    local overlay = newOverlay()
    eq(overlay.width, 0, "width")
    eq(overlay.height, 0, "height")
end)

test("left-clicks and mouse moves pass through to the clock", function()
    local overlay = newOverlay()
    eq(overlay:onMouseDown(1, 1), false, "down")
    eq(overlay:onMouseUp(1, 1), false, "up")
    eq(overlay:onMouseMove(1, 1), false, "move")
end)

test("right-clicking the bell opens the alarm dialog for the worn watch", function()
    local watch = wearWatch()
    local overlay = newOverlay()
    eq(overlay:onRightMouseDown(2, 2), true, "down consumed")
    eq(#S.dialogs, 0, "no dialog before release")
    eq(overlay:onRightMouseUp(2, 2), true, "up consumed")
    eq(#S.dialogs, 1, "dialogs")
    eq(S.dialogs[1].alarm, watch, "alarm")
    eq(S.dialogs[1].player, 0, "player")
    eq(S.dialogs[1].inUIManager, true, "shown")
end)

test("right-clicks pass through when no settable alarm is worn or held", function()
    S.players = { S.player(0, { S.alarm("AlarmClockClothing", false) }, {}) }
    local overlay = newOverlay()
    eq(overlay:onRightMouseDown(2, 2), false, "down")
    eq(overlay:onRightMouseUp(2, 2), false, "up")
    eq(#S.dialogs, 0, "dialogs")
end)

test("a right-click that started elsewhere does nothing on release", function()
    wearWatch()
    local overlay = newOverlay()
    eq(overlay:onRightMouseUp(2, 2), false, "up")
    eq(#S.dialogs, 0, "dialogs")
end)

test("a right-click dragged off the bell is forgotten", function()
    wearWatch()
    local overlay = newOverlay()
    overlay:onRightMouseDown(2, 2)
    overlay:onRightMouseUpOutside(50, 50)
    eq(overlay:onRightMouseUp(2, 2), false, "later up")
    eq(#S.dialogs, 0, "dialogs")
end)

test("a second right-click brings the open dialog forward instead of stacking another", function()
    wearWatch()
    local overlay = newOverlay()
    overlay:onRightMouseDown(2, 2)
    overlay:onRightMouseUp(2, 2)
    overlay:onRightMouseDown(2, 2)
    overlay:onRightMouseUp(2, 2)
    eq(#S.dialogs, 1, "dialogs")
    eq(S.dialogs[1].broughtToTop, 1, "brought to top")
end)

test("a closed dialog is replaced by a new one", function()
    wearWatch()
    local overlay = newOverlay()
    overlay:onRightMouseDown(2, 2)
    overlay:onRightMouseUp(2, 2)
    S.dialogs[1].visible = false
    overlay:onRightMouseDown(2, 2)
    overlay:onRightMouseUp(2, 2)
    eq(#S.dialogs, 2, "dialogs")
end)

test("a joypad player gets focus on the dialog", function()
    wearWatch()
    JoypadState.players[1] = {}
    local overlay = newOverlay()
    overlay:onRightMouseDown(2, 2)
    overlay:onRightMouseUp(2, 2)
    eq(S.joypadFocus[0], S.dialogs[1], "focus")
    eq(S.dialogs[1].prevFocus.inventoryOf, 0, "previous focus")
end)

test("install adds one overlay at the back of the UI on game start", function()
    eq(#S.handlers.OnGameStart, 1, "handlers")
    S.handlers.OnGameStart[1]()
    eq(Overlay.instance.inUIManager, true, "added")
    eq(Overlay.instance.atBack, true, "at back")
end)
