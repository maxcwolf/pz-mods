--- Drives the window, on-screen button and context menu through stubbed UI classes.
local World = ARE_World
local UI = ARE_UI
require "ALifeRepEditor/context-menu"

--- Starts a fresh world with the window closed and the game running.
local function fresh()
    local world = World.new()
    UI.player = world.player
    UI.speed, UI.multiplier, UI.files = 1, 1, {}
    if ARE_RepEditorWindow.instance ~= nil and ARE_RepEditorWindow.instance.managed then
        ARE_RepEditorWindow.instance:close()
    end
    ARE_RepEditorWindow.instance = nil
    ARE_HudButton.instance = nil
    return world
end

--- Finds a window button by its title.
local function button(window, title)
    for _, child in ipairs(window.children) do
        if child.title == title then return child end
    end
    error("no button " .. title)
end

--- Clicks a faction row's drawn button by name ("forgive" or "hostile").
local function clickFaction(window, factionId, which)
    local list = window.factionList
    for index, item in ipairs(list.items) do
        if item.item.id == factionId then
            local forgive, hostile = ARE_RepEditorWindow.factionButtons(list)
            local rect = which == "forgive" and forgive or hostile
            list:onMouseDown(rect.x + 1, list:topOfItem(index) + rect.y + 1)
            return
        end
    end
    error("no faction row " .. factionId)
end

test("opening pauses the game and loads the state; closing resumes at the old speed", function()
    fresh()
    UI.speed, UI.multiplier = 2, 5
    local window = ARE_RepEditorWindow.open()
    eq(UI.speed, 0, "paused")
    ok(window.state ~= nil and window.state.ok, "state loaded")
    window:close()
    eq(UI.speed, 2, "speed back"); eq(UI.multiplier, 5, "multiplier back")
end)

test("a game the player had paused stays paused after closing", function()
    fresh()
    UI.speed = 0
    ARE_RepEditorWindow.open():close()
    eq(UI.speed, 0)
end)

test("the nudge and set-level buttons change reputation", function()
    local world = fresh()
    local window = ARE_RepEditorWindow.open()
    button(window, "+25"):click()
    eq(World.row(world).score, 25)
    eq(window.state.personal.score, 25, "window refreshed")
    window.levelButtons[1]:click()
    eq(World.row(world).level, "rep_n5")
    window:close()
end)

test("faction rows forgive and make hostile", function()
    local world = fresh()
    local window = ARE_RepEditorWindow.open()
    clickFaction(window, "civ", "hostile")
    eq(ProjectALife.Reputation.statusFor(world.player, "civ"), "hostile")
    clickFaction(window, "civ", "forgive")
    eq(ProjectALife.Reputation.statusFor(world.player, "civ"), "friendly")
    window:close()
end)

test("the faction buttons ignore clicks when they have nothing to do", function()
    local world = fresh()
    local window = ARE_RepEditorWindow.open()
    clickFaction(window, "blk", "hostile")
    eq(ProjectALife.Reputation.recordedStatus(world.player, "blk"), nil, "already hostile by default")
    window:close()
end)

test("a kill shows an Undo button that undoes it and then hides", function()
    local world = fresh()
    World.kill(world, World.addNpc("k1", "ash", "gk", "Kim"))
    local window = ARE_RepEditorWindow.open()
    ok(window.killButtons[1].visible, "undo shown")
    ok(not window.killButtons[2].visible, "spare slot hidden")
    window.killButtons[1]:click()
    eq(World.row(world).score, 0)
    ok(not window.killButtons[1].visible, "undo hidden once undone")
    window:close()
end)

test("the window fits a 1080p screen with six kills", function()
    local world = fresh()
    for i = 1, 6 do World.kill(world, World.addNpc("f" .. i, "ash", "gf" .. i, "F" .. i)) end
    local window = ARE_RepEditorWindow.open()
    ok(window.height <= 1080, "height " .. window.height)
    ok(window.y >= 0 and window.y + window.height <= 1080, "on screen")
    window:close()
end)

test("the right-click menu opens the editor and offers the button back when hidden", function()
    fresh()
    local menu = UI.menu()
    ALifeRepEditor.ContextMenu.fill(0, menu, {}, false)
    eq(#menu.options, 2, "open + show button (button not created yet)")
    menu.options[1].fn(menu.options[1].target)
    ok(ARE_RepEditorWindow.instance.managed, "window opened")
    ARE_RepEditorWindow.instance:close()
    ok(ALifeRepEditor.ContextMenu.fill(0, UI.menu(), {}, true), "test pass answers true")
end)

test("the on-screen button toggles the editor, drags, hides and comes back", function()
    fresh()
    local hud = ARE_HudButton.show(false)
    ok(hud ~= nil and hud.managed, "shown")
    eq(hud.y, 78, "default spot is just below the clock")
    eq(hud.x + hud.width, 1910, "right edge lined up with the clock's")
    local wider = ARE_HudButton.label
    ARE_HudButton.label = function() return "Rep: a much longer level name", nil end
    hud:fitWidth()
    eq(hud.x + hud.width, 1910, "a longer label grows to the left")
    ARE_HudButton.label = wider
    hud:fitWidth()
    hud:onMouseDown(0, 0); hud:onMouseUp(0, 0)
    ok(ARE_RepEditorWindow.instance.managed, "click opened the window")
    hud:onMouseDown(0, 0); hud:onMouseUp(0, 0)
    ok(not ARE_RepEditorWindow.instance.managed, "second click closed it")
    UI.mouseX, UI.mouseY = 0, 0
    hud:onMouseDown(0, 0)
    UI.mouseX, UI.mouseY = 100, 300
    hud:onMouseMove(100, 300)
    hud:onMouseUp(0, 0)
    eq(hud.y, 378, "dragged 300px down")
    ok(not ARE_RepEditorWindow.instance.managed, "a drag does not open the window")
    eq(UI.files["ALifeRepEditor_hud.txt"], string.format("%d,378,0", hud.x), "spot saved")
    local draggedX, label = hud.x, ARE_HudButton.label
    ARE_HudButton.label = function() return "Rep: a much longer level name", nil end
    hud:fitWidth()
    eq(hud.x, draggedX, "a dragged button keeps its left edge when the label grows")
    ARE_HudButton.label = label
    hud:fitWidth()
    hud:hide()
    ok(ARE_HudButton.isHidden(), "hidden")
    ARE_HudButton.instance = nil
    eq(ARE_HudButton.show(false), nil, "stays hidden next game")
    local back = ARE_HudButton.show(true)
    ok(back.managed, "shown again from the menu"); eq(back.y, 378, "at its saved spot")
    UI.mouseX, UI.mouseY = 0, 0
end)

test("the on-screen button names the current level from A-Life's status", function()
    local world = fresh()
    ProjectALife.StatusStore = { reputation = { personal = { level = "rep_p2" } } }
    local text, level = ARE_HudButton.label()
    eq(level, "rep_p2")
    ok(string.find(text, "UI_ALifeRepEditor_Hud", 1, true) == 1, text)
    ProjectALife.StatusStore = nil
    text = ARE_HudButton.label()
    eq(text, "UI_ALifeRepEditor_HudPlain")
end)

test("every draw function runs without errors, in loading, normal and personal-off states", function()
    local world = fresh()
    World.kill(world, World.addNpc("d1", "ash", "gd", "Dot"))
    local window = ARE_RepEditorWindow.new(ARE_RepEditorWindow, 0, 0, 700, 400)
    window:initialise()
    window:render()
    window = ARE_RepEditorWindow.open()
    window:render()
    for index, item in ipairs(window.factionList.items) do
        window.factionList:doDrawItem((index - 1) * 40, item, index % 2 == 0)
    end
    window.state.failed = true
    window:render()
    ProjectALife.PersonalRep.enabled = false
    ALifeRepEditor.Transport.send("refresh", {})
    window:render()
    ProjectALife.PersonalRep.enabled = true
    ok(not window.nudgeButtons[1].enabled, "nudges disabled with personal reputation off")
    local snapshot = ALifeRepEditor.Editor.snapshot
    ALifeRepEditor.Editor.snapshot = function() error("boom") end
    ALifeRepEditor.Transport.send("refresh", {})
    ALifeRepEditor.Editor.snapshot = snapshot
    ok(window.state ~= nil and window.state.unavailable, "a failed refresh still reaches the window")
    window:render()
    ok(not window.nudgeButtons[1].enabled, "nudges disabled when the state couldn't load")
    window:close()
    ProjectALife.StatusStore = { reputation = { personal = { level = "rep_n3" } } }
    ARE_HudButton.show(true):render()
    ProjectALife.StatusStore = nil
end)
