--- End to end through the right-click menu, the highlight and the window,
--- the way a player uses the mod: claim, remodel, see the highlight, save,
--- then apply the blueprint in a new game.
local Fake = require("fake-game")
local FakeUI = require("fake-ui")

--- Builds a fresh world with the same small house and loads the mod's UI.
local function world(keepFiles)
    local w = Fake.newWorld({ keepFiles = keepFiles })
    Fake.building(w, 10, 10, 3, 3, 0)
    for x = 0, 25 do
        for y = 0, 25 do
            w.setLoaded(x, y, true)
        end
    end
    for x = 9, 13 do
        for y = 9, 13 do
            w.put(x, y, 0, "IsoObject", "floors_interior_tilesandwood_01_0", { floor = true })
        end
    end
    w.put(11, 11, 0, "IsoObject", "furniture_seating_indoor_01_0")
    FakeUI.install()
    freshModules()
    local main = require("BaseBlueprints/main")
    return w, main
end

--- Fires the right-click menu on a square and returns the mod's submenu.
local function rightClick(w, x, y)
    local context = FakeUI.menu()
    local Menu = require("BaseBlueprints/menu")
    Menu.onFill(0, context, { w.square(x, y, 0).objects[1] }, false)
    return context:find("UI_BBP_Menu").sub
end

--- Picks a menu option.
local function pick(option)
    option.fn(option.target, option.a, option.b)
end

test("window: claim from the menu, see changes, save, apply in a new game", function()
    local w, main = world()
    main.onGameStart()
    local sub = rightClick(w, 11, 11)
    pick(sub:find("UI_BBP_ClaimHouse"))
    eq(w.notes[1], "UI_BBP_Claimed")

    local Overlay = require("BaseBlueprints/overlay")
    ok(Overlay.enabled, "highlight on after claiming")
    Overlay.onRenderTick()
    eq(#w.highlights, 4, "only the claim edge")

    -- Move the couch one tile east.
    local sq = w.square(11, 11, 0)
    sq:RemoveTileObject(sq.objects[2])
    w.put(12, 11, 0, "IsoObject", "furniture_seating_indoor_01_0")
    Overlay.rescan()
    w.highlights = {}
    Overlay.onRenderTick()
    local gold = 0
    for _, h in ipairs(w.highlights) do
        if h.r == Overlay.CHANGED[1] then gold = gold + (h.x2 - h.x1) * (h.y2 - h.y1) end
    end
    eq(gold, 2, "two changed tiles highlighted")
    eq(rightClick(w, 11, 11):find("UI_BBP_HideChanges") ~= nil, true)

    local window = BBP_BlueprintWindow.open()
    eq(window.statusLabel.name, "UI_BBP_StatusClaimed(5|5|11, 11|2)")
    window.nameEntry:setText("Couch moved")
    window.saveButton:click()
    eq(window.messageLabel.name, "UI_BBP_Saved(Couch moved|2)")
    eq(#window.list.items, 1)
    window.saveButton:click()
    eq(FakeUI.modals[1].text, "UI_BBP_ConfirmReplace(Couch moved)", "same name asks first")
    FakeUI.answer(false)
    window.list:click(1)
    window.autoTick:click()
    ok(window:selectedEntry().auto, "marked for new games")
    window.useContentsTick:click()
    eq(window.messageLabel.name, "UI_BBP_NoContentsSaved")

    -- New game: the blueprint applies by itself.
    local fresh, main2 = world(true)
    main2.onGameStart()
    main2.onNewGame()
    eq(#fresh.square(11, 11, 0).objects, 1, "couch gone from the old tile")
    eq(fresh.square(12, 11, 0).objects[2].sprite.name, "furniture_seating_indoor_01_0")
    local Runtime2 = require("BaseBlueprints/runtime")
    eq(Runtime2.claim(), nil, "a new game starts unclaimed")

    -- And can be applied again from the window after confirming.
    local window2 = BBP_BlueprintWindow.open()
    window2.list:click(1)
    window2.applyButton:click()
    FakeUI.answer(true)
    eq(window2.messageLabel.name, "UI_BBP_Applied(Couch moved|2)")

    -- Delete asks first; "No" keeps it.
    window2.deleteButton:click()
    FakeUI.answer(false)
    eq(#window2.list.items, 1)
    window2.deleteButton:click()
    FakeUI.answer(true)
    eq(#window2.list.items, 0)
    eq(window2.applyButton.enable, false)
end)

test("window: menu offers claiming only on buildings, unclaim asks first", function()
    local w, main = world()
    main.onGameStart()
    eq(rightClick(w, 13, 13):find("UI_BBP_ClaimHouse"), nil, "yard square has no building")
    pick(rightClick(w, 10, 10):find("UI_BBP_ClaimYard"))
    local Runtime = require("BaseBlueprints/runtime")
    eq(Runtime.claim().area.x1, 4, "building at 10 minus 6 tiles of yard")
    local window = BBP_BlueprintWindow.open()
    window.unclaimButton:click()
    FakeUI.answer(true)
    eq(Runtime.claim(), nil)
    eq(window.saveButton.enable, false)
    eq(window.statusLabel.name, "UI_BBP_StatusNone")
end)

test("window: drag out an area with the cursor, cancel brings the window back", function()
    local w, main = world()
    main.onGameStart()
    local window = BBP_BlueprintWindow.open()
    window.dragButton:click()
    eq(window.visible, false, "window hidden while dragging")
    local cursor = w.drag
    ok(cursor, "drag cursor set")
    eq(w.notes[#w.notes], "UI_BBP_DragHint")

    -- Hover: one square highlighted.
    w.mouse = { x = 9, y = 9 }
    w.highlights = {}
    cursor:render(9, 9, 0)
    eq(w.highlights[1].x2 - w.highlights[1].x1, 1)
    -- Press on 9,9 and drag to 13,12: the game keeps passing the pressed square.
    cursor.isLeftDown = true
    w.mouse = { x = 13, y = 12 }
    w.highlights = {}
    cursor:render(9, 9, 0)
    eq(w.highlights[1].x1, 9)
    eq(w.highlights[1].x2, 14, "exclusive edge")
    eq(w.highlights[1].y2, 13)
    -- Too big turns red.
    w.mouse = { x = 400, y = 400 }
    w.highlights = {}
    cursor:render(9, 9, 0)
    eq(w.highlights[1].r, 1.0)
    -- Let go on 13,12.
    w.mouse = { x = 13, y = 12 }
    cursor:create(9, 9, 0)
    eq(w.drag, nil, "cursor put away")
    eq(window.visible, true)
    eq(window.messageLabel.name, "UI_BBP_Claimed")
    local Runtime = require("BaseBlueprints/runtime")
    local area = Runtime.claim().area
    eq(area.x1 .. "," .. area.y1 .. "," .. area.x2 .. "," .. area.y2, "9,9,13,12")
    eq(window.statusLabel.name, "UI_BBP_StatusClaimed(5|4|11, 10|0)")

    -- The menu now offers a redraw; picking it and cancelling changes nothing.
    pick(rightClick(w, 11, 11):find("UI_BBP_RedrawArea"))
    ok(w.drag, "cursor up again")
    w.drag:deactivate()
    eq(Runtime.claim().area.x2, 13)
end)
