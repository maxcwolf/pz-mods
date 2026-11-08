--- End to end through layout B, the bottom strip, and switching between
--- the two layouts in both directions.
local Fake = require("fake-game")
local FakeUI = require("fake-ui")

--- Builds a fresh world (with extra counters for paging) and loads the UI.
local function world(counters)
    local w = Fake.newWorld()
    Fake.furniture(w)
    for i = 1, counters or 0 do
        w.sprite("fixtures_counters_01", i, { IsMoveAble = true, GroupName = "Oak " .. i, CustomName = "Counter", Facing = "S" })
    end
    FakeUI.install()
    freshModules()
    require("FurnishByRoom/main")
    return w, require("FurnishByRoom/controller")
end

--- Opens the mod and switches to the strip with the window's button.
local function openStrip(w, C)
    C.open()
    C.view.layoutButton:click()
    return C.view
end

test("strip: the window's button swaps to the strip and remembers it", function()
    local w, C = world()
    C.open()
    local win = C.view
    win.layoutButton:click()
    local strip = C.view
    eq(strip.layout, "strip")
    ok(FakeUI.showing(strip), "strip on screen")
    ok(not FakeUI.showing(win), "window gone")
    eq(require("FurnishByRoom/options").layout(), "strip")
    eq(PZAPI.ModOptions.saves, 1, "saved to the mod options file")
    C.toggle()
    C.toggle()
    eq(C.view.layout, "strip", "reopens as the strip")
end)

test("strip: room pills, the category button and a card pick", function()
    local w, C = world()
    local strip = openStrip(w, C)
    strip.pills.bar:click()
    eq(#strip.items, 3, "bar stool, fridge and wood floor")
    eq(strip.catButton.title, "UI_FBR_Cat_all  1/4  >")
    strip.catButton:click()
    eq(C.browse().cat, "appliances")
    eq(strip.catButton.title, "UI_FBR_Cat_appliances  2/4  >")

    strip:onMouseDown(strip.cardsX + 5, strip.cardsY + 5)
    eq(C.placing.entry.label, "White Fridge")
    ok(FakeUI.showing(strip), "the strip stays up while placing")
    ok(string.find(FakeUI.draw(strip), "UI_FBR_Hint_place", 1, true))
    w.drag:create(1, 1, 0)
    eq(strip.undoButton.title, "UI_FBR_Undo (1)")

    strip:onKeyRelease(Keyboard.KEY_ESCAPE)
    eq(C.placing, nil, "first Esc stops placing")
    ok(FakeUI.showing(strip))
    strip:onKeyRelease(Keyboard.KEY_ESCAPE)
    eq(C.view, nil, "second Esc closes")
end)

test("strip: arrows page, the wheel scrolls, and room switches go back to the start", function()
    local w, C = world(12)
    local strip = openStrip(w, C)
    eq(#strip.items, 15)
    ok(string.find(FakeUI.draw(strip), "1-8 / 15", 1, true))
    strip.nextButton:click()
    eq(strip.first, 8, "the last page is a full page")
    strip.prevButton:click()
    eq(strip.first, 1)
    strip:onMouseWheel(2)
    eq(strip.first, 3)
    strip:onMouseDown(strip.cardsX + 5, strip.cardsY + 5)
    eq(C.placing.entry.key, strip.items[3].key, "the card under the mouse after scrolling")
    strip.pills.bedroom:click()
    eq(strip.first, 1)
end)

test("strip: switching back to the catalog mid-placing keeps placing behind the chip", function()
    local w, C = world()
    local strip = openStrip(w, C)
    strip:onMouseDown(strip.cardsX + 5, strip.cardsY + 5)
    strip.layoutButton:click()
    local win = C.view
    eq(win.layout, "catalog")
    ok(not FakeUI.showing(strip))
    ok(C.placing ~= nil, "still placing")
    ok(not win.visible, "window waits behind the chip")
    ok(FakeUI.showing(win.chip))
    eq(require("FurnishByRoom/options").layout(), "catalog")
end)

test("strip: Remove and close buttons", function()
    local w, C = world()
    local strip = openStrip(w, C)
    strip.removeButton:click()
    eq(C.placing.mode, "remove")
    strip.closeButton:click()
    eq(C.view, nil)
    eq(C.placing, nil, "closing ends the mouse mode")
    eq(w.drag, nil)
end)
