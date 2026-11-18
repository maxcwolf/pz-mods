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

--- Finds a People tab button by its title.
local function peopleButton(window, title)
    for _, child in ipairs(window.peopleView.children) do
        if child.title == title then return child end
    end
    error("no people button " .. title)
end

--- Returns the person with a uid from the window's last state.
local function personIn(window, uid)
    for _, entry in ipairs(window.state.people or {}) do
        if entry.uid == uid then return entry end
    end
    return nil
end

test("the People tab lists who you've met and edits the one you pick", function()
    local world = fresh()
    ProjectALife.NpcOpinion.note("gift", World.addNpc("u1", "ash", "gu1", "Uma"), world.player)
    ProjectALife.NpcOpinion.note("gift", World.addNpc("u2", "civ", "gu2", "Vic"), world.player)
    local window = ARE_RepEditorWindow.open()
    eq(window.tab, "reputation")
    ok(not window.peopleView:getIsVisible(), "people hidden on the reputation tab")
    button(window, "UI_ALifeRepEditor_TabPeople"):click()
    eq(window.tab, "people")
    ok(window.peopleView:getIsVisible(), "people shown")
    ok(not window.factionList:getIsVisible(), "factions hidden")
    ok(not window.nudgeButtons[1]:getIsVisible(), "score nudges hidden")
    eq(#window.peopleView.list.items, 2)
    ok(not window.peopleView.nudgeButtons[1].enabled, "nothing picked yet")

    local list = window.peopleView.list
    local row = nil
    for index, item in ipairs(list.items) do if item.item.uid == "u1" then row = index end end
    list:onMouseDown(10, list:topOfItem(row) + 5)
    eq(window.peopleView.selectedUid, "u1")
    ok(window.peopleView.nudgeButtons[1].enabled, "picked")
    local before = personIn(window, "u1").value
    peopleButton(window, "+25"):click()
    eq(personIn(window, "u1").value, before + 25, "nudged")
    eq(window.peopleView.selectedUid, "u1", "still picked after the server answers")
    eq(window.state.people[1].uid, "u1", "the edited person moves to the top")
    peopleButton(window, "Hates you"):click()
    eq(personIn(window, "u1").label, "Hates you")
    eq(World.opinion(world, "u1").v, -86)
    ok(personIn(window, "u1").why ~= nil, "has a reason to draw")
    window.peopleView:render()
    ok(peopleButton(window, "UI_ALifeRepEditor_Hostile").enabled)
    peopleButton(window, "UI_ALifeRepEditor_Hostile"):click()
    ok(personIn(window, "u1").hostile)
    ok(not peopleButton(window, "UI_ALifeRepEditor_Hostile").enabled, "already hostile")
    peopleButton(window, "UI_ALifeRepEditor_Calm"):click()
    ok(not personIn(window, "u1").hostile)
    peopleButton(window, "UI_ALifeRepEditor_Forget"):click()
    eq(World.opinion(world, "u1"), nil, "forgotten")

    window.peopleView.searchBox:type("towns")
    eq(#window.peopleView.list.items, 1, "search narrows the list")
    eq(window.peopleView.list.items[1].item.uid, "u2")
    window.peopleView.searchBox:type("")
    window:render()
    window.peopleView:render()
    for index, item in ipairs(window.peopleView.list.items) do
        ARE_PeopleView.drawPersonRow(window.peopleView.list, (index - 1) * 40, item, index % 2 == 0)
    end
    ok(window.height <= 1080, "people tab fits: " .. window.height)
    button(window, "UI_ALifeRepEditor_TabReputation"):click()
    ok(window.factionList:getIsVisible(), "factions back")
    ok(not window.peopleView:getIsVisible())
    window:close()
end)

test("the People tab's crew button brings someone into your crew and lets them go", function()
    local world = fresh()
    function world.player:getX() return 10 end
    function world.player:getY() return 10 end
    function world.player:getZ() return 0 end
    ProjectALife.NpcOpinion.note("gift", World.addNpc("k1", "ash", "gk1", "Kit"), world.player)
    local shell = { getX = function() return 11 end, getY = function() return 10 end, getZ = function() return 0 end,
        isDead = function() return false end, getModData = function() return {} end }
    ProjectALife.Watchdog = { bindings = { k1 = { shell = shell } } }
    local window = ARE_RepEditorWindow.open({ person = "k1" })
    local crew = window.peopleView.crewButton
    eq(crew.title, "UI_ALifeRepEditor_JoinCrew")
    ok(crew.enabled, "can ask them to join")
    crew:click()
    eq(personIn(window, "k1").crew, "yours")
    eq(window.state.crewSize, 1)
    eq(crew.title, "UI_ALifeRepEditor_LeaveCrew", "the button turns into Leave my crew")
    window.peopleView:render()
    crew:click()
    eq(personIn(window, "k1").crew, nil, "left")
    eq(crew.title, "UI_ALifeRepEditor_JoinCrew")
    SandboxVars.ALife.Companions_Enabled = false
    window:send("refresh")
    SandboxVars.ALife.Companions_Enabled = nil
    ok(not crew.enabled, "off when A-Life's companions are off")
    ok(crew.y >= window.peopleView.hostileButton.y, "laid out with the other actions")
    window:close()
    ProjectALife.Watchdog = nil
end)

test("right-clicking an NPC opens their relationship, even a stranger", function()
    fresh()
    World.addNpc("s1", "blk", "gs1", "Sid")
    local body = { getModData = function() return { ProjectALifeUID = "s1", ProjectALifeOwned = true } end }
    local square = { getMovingObjects = function()
        return { size = function() return 1 end, get = function() return body end }
    end }
    local floor = { getSquare = function() return square end }
    local menu = UI.menu()
    ALifeRepEditor.ContextMenu.fill(0, menu, { floor }, false)
    local option = nil
    for _, entry in ipairs(menu.options) do
        if string.find(entry.name, "ContextMenu_ALifeRepEditor_PersonNamed", 1, true) == 1 then option = entry end
    end
    ok(option ~= nil, "Edit relationship offered")
    ok(string.find(option.name, "Sid Doe", 1, true) ~= nil, option.name)
    option.fn(option.target)
    local window = ARE_RepEditorWindow.instance
    eq(window.tab, "people")
    eq(window.peopleView.selectedUid, "s1")
    eq(window.state.people[1].uid, "s1", "stranger listed first")
    ok(not window.state.people[1].met)
    eq(window.peopleView.list.visibleIndex, 1, "scrolled to them")
    window.peopleView:render()
    window:close()

    menu = UI.menu()
    ALifeRepEditor.ContextMenu.fill(0, menu, { { getSquare = function() return nil end } }, false)
    for _, entry in ipairs(menu.options) do
        ok(string.find(entry.name, "Person", 1, true) == nil, "no NPC, no relationship option")
    end
end)

test("the right-click uses A-Life's own NPC finder when it is there", function()
    fresh()
    World.addNpc("s2", "ash", "gs2", "Tia")
    ProjectALife.MenuBuilder = {
        clickedSquare = function() return "sq" end,
        ownedShell = function(_, square)
            if square ~= "sq" then return nil end
            return { getModData = function() return { ProjectALifeUID = "s2" } end }
        end,
    }
    eq(ALifeRepEditor.ContextMenu.npcAt({}), "s2")
    ProjectALife.MenuBuilder = nil
    eq(ALifeRepEditor.ContextMenu.npcAt({}), nil)
end)

--- Finds a Crew tab button by its title.
local function crewButton(window, title)
    for _, child in ipairs(window.crewView.children) do
        if child.title == title and child.visible ~= false then return child end
    end
    error("no crew button " .. title)
end

--- Clicks a row's drawn button in one of the Crew tab's lists.
local function clickRow(list, match, label)
    for index, item in ipairs(list.items) do
        if match(item.item) then
            for _, rect in ipairs((ARE_CrewView.rowButtons(list, item.item))) do
                if rect.label == label then
                    list:onMouseDown(rect.x + 1, list:topOfItem(index) + rect.y + 1)
                    return
                end
            end
        end
    end
    error("no row button " .. label)
end

test("the Crew tab sets skills and stats and hands over weapons, items and clothing", function()
    local world = fresh()
    local Bodies = ARE_Bodies
    local savedManager = getScriptManager
    getScriptManager = Bodies.scriptManager
    ALifeRepEditor.ItemInfo.cache = nil
    ProjectALife.Watchdog = { bindings = {} }
    Bodies.stand(world.player, 10, 10)
    World.addNpc("c1", "ash", "gc1", "Cy")
    local shell = Bodies.body("c1", 11, 10)
    local hydrator = ProjectALife.ProfileHydrator
    local redress = hydrator.redress
    hydrator.redress = function() return true end

    local window = ARE_RepEditorWindow.open()
    button(window, "UI_ALifeRepEditor_TabCrew"):click()
    eq(window.tab, "crew")
    ok(window.crewView:getIsVisible() and not window.peopleView:getIsVisible() and not window.factionList:getIsVisible())
    eq(#window.crewView.memberButtons, 0, "nobody in the crew yet")
    window.crewView:render()

    window = ARE_RepEditorWindow.open({ person = "c1" })
    eq(window.tab, "people"); eq(window.peopleView.selectedUid, "c1")
    ok(not window.peopleView.gearButton.enabled, "skills and gear only for crew")
    window.peopleView.crewButton:click()
    ok(window.peopleView.gearButton.enabled)
    window.peopleView.gearButton:click()
    eq(window.tab, "crew"); eq(window.crewView.selectedUid, "c1")
    eq(#window.crewView.memberButtons, 1); eq(window.crewView.memberButtons[1].title, "Cy Doe")

    local view = window.crewView
    view.plusButtons[3]:click()
    eq(window.state.crewMember.skills.firstAid, 1, "first aid up one")
    ok(view.minusButtons[3].enabled)
    view.plusButtons[#view.plusButtons]:click()
    eq(window.state.crewMember.ratings.aiming, ALifeRepEditor.Crew.ratingFallback + 1)
    eq(shell.data.ProjectALifeAiming, ALifeRepEditor.Crew.ratingFallback + 1)
    crewButton(window, "UI_ALifeRepEditor_MaxAll"):click()
    ok(not view.plusButtons[1].enabled, "at the top")
    ok(not view.ammoButtons[1].enabled, "no gun yet")

    view.searchBox:type("s")
    eq(#view.resultList.items, 0, "needs two letters")
    view.searchBox:type("shot")
    eq(#view.resultList.items, 1)
    clickRow(view.resultList, function(row) return row.type == "Base.Shotgun" end, "UI_ALifeRepEditor_Hold")
    eq(window.state.crewMember.weapon.name, "Shotgun")
    ok(view.ammoButtons[1].enabled)
    view.ammoButtons[1]:click()
    eq(window.state.crewMember.weapon.spare, 90)
    view.searchBox:type("band")
    clickRow(view.resultList, function(row) return row.type == "Base.Bandage" end, "UI_ALifeRepEditor_GiveTen")
    eq(#shell.inventory.items.list, 11)
    clickRow(view.carryList, function(row) return row.type == "Base.Bandage" end, "UI_ALifeRepEditor_Remove")
    eq(#shell.inventory.items.list, 1)
    view.searchBox:type("beret")
    clickRow(view.resultList, function(row) return row.type == "Base.Beret" end, "UI_ALifeRepEditor_Wear")
    eq(window.state.message, "Cy Doe is wearing the Beret.")

    window:render()
    view:render()
    for index, item in ipairs(view.carryList.items) do ARE_CrewView.drawCarryRow(view.carryList, (index - 1) * 30, item, index % 2 == 0) end
    for index, item in ipairs(view.resultList.items) do ARE_CrewView.drawResultRow(view.resultList, (index - 1) * 30, item, index % 2 == 0) end
    ok(window.height <= 1080, "crew tab fits: " .. window.height)
    for _, entry in ipairs(view.cells) do ok(entry.right > entry.x, "each level has room for its label") end

    ProjectALife.Watchdog.bindings["c1"] = nil
    window:send("refresh")
    ok(not window.state.crewMember.loaded)
    view:render()
    local before = #shell.inventory.items.list
    clickRow(view.resultList, function(row) return row.type == "Base.Beret" end, "UI_ALifeRepEditor_Wear")
    eq(#shell.inventory.items.list, before, "nothing handed over while they're away")

    window:close()
    hydrator.redress = redress
    getScriptManager = savedManager
    ALifeRepEditor.ItemInfo.cache = nil
    ALifeRepEditor.Editor.storage = nil
    ProjectALife.Watchdog = nil
end)
