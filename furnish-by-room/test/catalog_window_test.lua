--- End to end through layout A, the catalog window, the way a player uses
--- it: open with F7 in the kitchen, switch rooms and filters, search, pick
--- an item, place it from the chip, undo, Esc out, and the right-click menu.
local Fake = require("fake-game")
local FakeUI = require("fake-ui")

--- Builds a fresh world and loads the mod's UI.
local function world()
    local w = Fake.newWorld()
    Fake.furniture(w)
    FakeUI.install()
    freshModules()
    require("FurnishByRoom/main")
    return w, require("FurnishByRoom/controller")
end

--- Returns the labels of the grid's items, joined.
local function labels(win)
    local out = {}
    for _, e in ipairs(win.grid.items) do out[#out + 1] = e.label end
    return table.concat(out, ",")
end

--- Returns the titles of the category chips, joined.
local function chips(win)
    local out = {}
    for _, c in ipairs(win.chips) do out[#out + 1] = c.title end
    return table.concat(out, ",")
end

test("catalog window: F7 in the kitchen opens the window on the kitchen", function()
    local w, C = world()
    w.fire("OnKeyPressed", Keyboard.KEY_F7)
    local win = C.view
    ok(FakeUI.showing(win), "window on screen")
    eq(win.layout, "catalog", "catalog is the default layout")
    eq(C.browse().room, "kitchen")
    ok(string.find(FakeUI.draw(win), "UI_FBR_YouAreIn(ui_fbr_room_kitchen)", 1, true), "says where you are")
    eq(labels(win), "White Fridge,Oak Counter,White Tiles")
    eq(chips(win), "UI_FBR_Cat_all,UI_FBR_Cat_appliances,UI_FBR_Cat_counters,UI_FBR_Cat_floors")
    local Theme = require("FurnishByRoom/theme")
    eq(win.tabs.kitchen.borderColor.r, Theme.ACCENT.r, "kitchen tab selected")
    eq(win.tabs.bar.borderColor.r, Theme.BORDER.r)
    eq(win.tabs.kitchen.title, "UI_FBR_Room_kitchen  3")
end)

test("catalog window: tabs, category chips and search filter the grid", function()
    local w, C = world()
    C.open()
    local win = C.view
    win.tabs.bedroom:click()
    eq(labels(win), "Blue Bed,Oakwood Floor")
    FakeUI.button(win, "UI_FBR_Cat_floors"):click()
    eq(labels(win), "Oakwood Floor")
    win.search:type("bed")
    eq(labels(win), "Blue Bed", "search looks through the whole room")
    win.search:type("")
    eq(labels(win), "Oakwood Floor", "clearing the search goes back to the category")
    win.tabs.bar:click()
    eq(C.browse().cat, "all", "a new room starts on All")
    eq(win.search:getInternalText(), "")
end)

test("catalog window: picking a card tucks the window into the chip until Esc", function()
    local w, C = world()
    C.open()
    local win = C.view
    win.grid:onMouseDown(10, 10)
    eq(C.placing.entry.label, "White Fridge")
    ok(not win.visible, "window hidden while placing")
    local chip = win.chip
    ok(FakeUI.showing(chip), "chip shown")
    local text = FakeUI.draw(chip)
    ok(string.find(text, "UI_FBR_PlacingLine(UI_FBR_Room_kitchen|White Fridge|0)", 1, true), text)
    ok(string.find(text, "UI_FBR_Hint_place", 1, true))

    w.drag:create(2, 2, 0)
    ok(string.find(FakeUI.draw(chip), "|1)", 1, true), "count goes up")

    ok(chip:isKeyConsumed(Keyboard.KEY_ESCAPE), "Esc is taken from the game menu")
    chip:onKeyRelease(Keyboard.KEY_ESCAPE)
    eq(w.drag, nil, "placing stopped")
    ok(win.visible, "window back")
    ok(not FakeUI.showing(chip), "chip gone")
    eq(win.grid.selectedKey, C.picked, "the last pick stays highlighted")
end)

test("catalog window: right-click ends placing the vanilla way and the window returns", function()
    local w, C = world()
    C.open()
    local win = C.view
    win.grid:onMouseDown(10, 10)
    getCell():setDrag(nil, 0)
    eq(C.placing, nil)
    ok(win.visible)
end)

test("catalog window: Undo and Ctrl+Z undo; the Undo button counts", function()
    local w, C = world()
    C.open()
    local win = C.view
    win.grid:onMouseDown(10, 10)
    w.drag:create(1, 1, 0)
    w.drag:create(2, 2, 0)
    eq(win.chip.undoButton ~= nil, true)
    w.ctrl = true
    w.fire("OnKeyPressed", Keyboard.KEY_Z)
    w.ctrl = false
    eq(w.spritesAt(2, 2, 0), "floor_base_0")
    eq(w.spritesAt(1, 1, 0), "floor_base_0,appliances_refrigeration_01_2")
    win.chip:onBack()
    eq(win.undoButton.title, "UI_FBR_Undo (1)")
    win.undoButton:click()
    eq(w.spritesAt(1, 1, 0), "floor_base_0")
    eq(win.undoButton.title, "UI_FBR_Undo (0)")
end)

test("catalog window: Ctrl+Z does nothing while the mod is closed", function()
    local w, C = world()
    C.open()
    C.view.grid:onMouseDown(10, 10)
    w.drag:create(1, 1, 0)
    C.close()
    w.ctrl = true
    w.fire("OnKeyPressed", Keyboard.KEY_Z)
    eq(w.spritesAt(1, 1, 0), "floor_base_0,appliances_refrigeration_01_2")
end)

test("catalog window: Remove button starts the remove tool", function()
    local w, C = world()
    C.open()
    C.view.removeButton:click()
    eq(C.placing.mode, "remove")
    ok(string.find(FakeUI.draw(C.view.chip), "UI_FBR_Removing(0)", 1, true))
end)

test("catalog window: Esc, the close button and F7 all close it", function()
    local w, C = world()
    C.open()
    local win = C.view
    ok(win:isKeyConsumed(Keyboard.KEY_ESCAPE))
    win:onKeyRelease(Keyboard.KEY_ESCAPE)
    ok(not FakeUI.showing(win))
    eq(C.view, nil)
    w.fire("OnKeyPressed", Keyboard.KEY_F7)
    ok(FakeUI.showing(C.view))
    C.view:close()
    eq(C.view, nil)
    w.fire("OnKeyPressed", Keyboard.KEY_F7)
    w.fire("OnKeyPressed", Keyboard.KEY_F7)
    eq(C.view, nil, "F7 toggles")
end)

test("catalog window: opens on the last room when you stand outside", function()
    local w, C = world()
    C.open()
    C.view.tabs.garage:click()
    C.close()
    w.standing = w.square(40, 40, 0)
    C.open()
    eq(C.browse().room, "garage")
    ok(string.find(FakeUI.draw(C.view), "UI_FBR_PickRoom", 1, true))
end)

test("menu: right-click in the bedroom offers to furnish it and opens there", function()
    local w, C = world()
    local Menu = require("FurnishByRoom/menu")
    local context = FakeUI.menu()
    Menu.onFill(0, context, { w.square(11, 1, 0).objects[1] }, false)
    local option = context.options[1]
    eq(option.name, "UI_FBR_MenuRoom(ui_fbr_room_bedroom)")
    option.fn(option.target)
    eq(C.browse().room, "bedroom")
    ok(FakeUI.showing(C.view))

    local outside = FakeUI.menu()
    w.square(50, 50, 0):addFloor("floor_base_0")
    Menu.onFill(0, outside, { w.square(50, 50, 0).objects[1] }, false)
    eq(outside.options[1].name, "UI_FBR_Menu")
    local tested = FakeUI.menu()
    Menu.onFill(0, tested, {}, true)
    eq(#tested.options, 0, "nothing in test mode")
end)
