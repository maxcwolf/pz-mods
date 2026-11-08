--- End to end through the controller and the three mouse modes, against
--- the fake game: placing (with rotation and multi-tile beds), painting
--- floors (whole room and rectangle), removing, and undoing each.
local Fake = require("fake-game")
local FakeUI = require("fake-ui")

--- Builds a fresh world with the test furniture and loads the mod.
local function world()
    local w = Fake.newWorld()
    Fake.furniture(w)
    FakeUI.install()
    freshModules()
    require("FurnishByRoom/main")
    return w, require("FurnishByRoom/controller")
end

--- Returns the room's entry with the label.
local function entry(C, room, label)
    for _, e in ipairs(require("FurnishByRoom/catalog").entries(C.catalog(), room)) do
        if e.label == label then
            return e
        end
    end
    error("no " .. label .. " in " .. room)
end

test("place: a fridge goes down where clicked, starts empty, and undo takes it away", function()
    local w, C = world()
    C.pick(entry(C, "kitchen", "White Fridge"))
    local cursor = w.drag
    ok(cursor and cursor.isFurnishCursor, "a furnish cursor is active")
    local square = w.square(2, 2, 0)
    ok(cursor:isValid(square))
    cursor:render(2, 2, 0, square)
    eq(w.ghosts[1][1] .. "|" .. w.ghosts[1][5], "appliances_refrigeration_01_2|ok", "south-facing ghost, green")

    cursor:create(2, 2, 0)
    eq(w.spritesAt(2, 2, 0), "floor_base_0,appliances_refrigeration_01_2")
    ok(square.objects[2].containers[1].explored, "container marked searched so no loot rolls")
    eq(C.undoCount(), 1)
    eq(C.placing.count, 1)

    ok(not cursor:isValid(square), "no second fridge on the same square")
    w.ghosts = {}
    cursor:render(2, 2, 0, square)
    eq(w.ghosts[1][5], "red")

    ok(C.undo())
    eq(w.spritesAt(2, 2, 0), "floor_base_0")
    eq(w.notes[#w.notes], "UI_FBR_Undone_place")
    ok(not C.undo(), "nothing left")
    eq(w.notes[#w.notes], "UI_FBR_NothingToUndo")
end)

test("place: counters and cabinets go down without a hammer or carpentry", function()
    local w, C = world()
    C.pick(entry(C, "kitchen", "Oak Counter"))
    local square = w.square(3, 3, 0)
    ok(w.drag:isValid(square), "a counter fits for a player with no tools")
    ok((w.toolChecks or 0) == 0, "the game's tool rule never ran")
    w.drag:create(3, 3, 0)
    eq(w.spritesAt(3, 3, 0), "floor_base_0,fixtures_counters_01_0")
    eq(ISMoveableDefinitions.cheat, false, "the game's movables cheat is left as it was")
    ok(not w.drag:isValid(square), "the room rules still apply: no second counter there")
end)

test("place: R steps through the facings; other keys do not", function()
    local w, C = world()
    C.pick(entry(C, "kitchen", "White Fridge"))
    local cursor = w.drag
    cursor:rotateKey(Keyboard.KEY_R)
    eq(cursor:getSprite(), "appliances_refrigeration_01_3", "south then east")
    cursor:rotateKey(Keyboard.KEY_R)
    eq(cursor:getSprite(), "appliances_refrigeration_01_0", "then north")
    cursor:rotateKey(Keyboard.KEY_Z)
    eq(cursor:getSprite(), "appliances_refrigeration_01_0")
    cursor:create(1, 1, 0)
    eq(w.spritesAt(1, 1, 0), "floor_base_0,appliances_refrigeration_01_0")
end)

test("place: a bed covers both its tiles, turns with R, and stays inside the room", function()
    local w, C = world()
    C.pick(entry(C, "bedroom", "Blue Bed"))
    local cursor = w.drag
    cursor:create(11, 1, 0)
    eq(w.spritesAt(11, 1, 0), "floor_base_0,furniture_bedding_01_0")
    eq(w.spritesAt(11, 2, 0), "floor_base_0,furniture_bedding_01_1")
    w.ghosts = {}
    cursor:render(11, 1, 0, w.square(11, 1, 0))
    eq(#w.ghosts, 2, "both tiles drawn")

    cursor:rotateKey(Keyboard.KEY_R)
    eq(cursor:getSprite(), "furniture_bedding_01_2")
    ok(not cursor:isValid(w.square(13, 2, 0)), "east-facing bed would hang off the map")
    cursor:create(12, 2, 0)
    eq(w.spritesAt(13, 2, 0), "floor_base_0,furniture_bedding_01_3")
    eq(C.undoCount(), 2)

    ok(C.undo())
    eq(w.spritesAt(12, 2, 0), "floor_base_0", "undo takes away both tiles")
    eq(w.spritesAt(13, 2, 0), "floor_base_0")
end)

test("remove: clicking one end of a bed removes the whole bed; undo puts it back", function()
    local w, C = world()
    C.pick(entry(C, "bedroom", "Blue Bed"))
    w.drag:create(11, 1, 0)
    C.startRemove()
    local remover = w.drag
    ok(not remover:isValid(w.square(12, 3, 0)), "nothing to remove on an empty floor")
    ok(remover:isValid(w.square(11, 2, 0)))
    w.ghosts = {}
    remover:render(11, 2, 0, w.square(11, 2, 0))
    eq(#w.ghosts, 2)
    eq(w.ghosts[1][5], "red")
    remover:create(11, 2, 0)
    eq(w.spritesAt(11, 1, 0), "floor_base_0")
    eq(w.spritesAt(11, 2, 0), "floor_base_0")
    eq(C.placing.mode, "remove")

    ok(C.undo())
    eq(w.spritesAt(11, 1, 0), "floor_base_0,furniture_bedding_01_0")
    eq(w.spritesAt(11, 2, 0), "floor_base_0,furniture_bedding_01_1")
    eq(w.notes[#w.notes], "UI_FBR_Undone_remove")
end)

test("remove: floors and things the game cannot move are left alone", function()
    local w, C = world()
    local sq = w.square(2, 2, 0)
    local junk = w.object("floor_base_0", sq)
    sq.objects[#sq.objects + 1] = junk
    C.startRemove()
    ok(not w.drag:isValid(sq), "a floor-tile object is not furniture")
end)

test("floor: one click paints the whole kitchen, a drag paints a rectangle, undo restores", function()
    local w, C = world()
    C.pick(entry(C, "kitchen", "White Tiles"))
    local cursor = w.drag
    eq(C.placing.mode, "floor")
    ok(cursor:isValid(w.square(1, 1, 0)))
    w.ghosts = {}
    cursor:render(1, 1, 0, w.square(1, 1, 0))
    eq(#w.ghosts, 16, "previews the whole room")
    cursor:create(1, 1, 0)
    eq(w.spritesAt(0, 0, 0), "floors_interior_tilesandwood_01_11")
    eq(w.spritesAt(3, 3, 0), "floors_interior_tilesandwood_01_11")
    eq(w.spritesAt(10, 0, 0), "floor_base_0", "the bedroom is untouched")
    ok(C.undo())
    eq(w.spritesAt(3, 3, 0), "floor_base_0")

    cursor.isLeftDown = true
    cursor:rotateMouse(2, 1)
    w.ghosts = {}
    cursor:render(0, 0, 0, w.square(0, 0, 0))
    eq(#w.ghosts, 6, "a 3 by 2 rectangle")
    cursor.isLeftDown = false
    cursor.build = true
    cursor:create(0, 0, 0)
    eq(w.spritesAt(2, 1, 0), "floors_interior_tilesandwood_01_11")
    eq(w.spritesAt(3, 3, 0), "floor_base_0")
    eq(cursor.dragEnd, nil, "the drag is forgotten after painting")
end)

test("floor: painting a square with no floor adds one, and undo takes it away", function()
    local w, C = world()
    w.square(30, 30, 0)
    C.pick(entry(C, "living", "Oakwood Floor"))
    w.drag:create(30, 30, 0)
    eq(w.spritesAt(30, 30, 0), "floors_interior_tilesandwood_01_30")
    C.undo()
    eq(w.spritesAt(30, 30, 0), "")
end)

test("controller: a new pick swaps cursors without ending placing; stop ends it", function()
    local w, C = world()
    C.pick(entry(C, "kitchen", "White Fridge"))
    C.pick(entry(C, "living", "Red Comfy Couch"))
    ok(C.placing and C.placing.cursor == w.drag, "still placing with the new cursor")
    eq(C.placing.entry.label, "Red Comfy Couch")
    C.stop()
    eq(C.placing, nil)
    eq(w.drag, nil)
end)

test("options: ignoring placement rules lets a couch share the fridge's square", function()
    local w, C = world()
    C.pick(entry(C, "kitchen", "White Fridge"))
    w.drag:create(2, 2, 0)
    C.pick(entry(C, "living", "Red Comfy Couch"))
    ok(not w.drag:isValid(w.square(2, 2, 0)), "the game's rule says no")
    w.options.FurnishByRoom:getOption("anywhere"):setValue(true)
    ok(w.drag:isValid(w.square(2, 2, 0)), "the option says yes")
    w.square(2, 2, 0).car = true
    ok(not w.drag:isValid(w.square(2, 2, 0)), "never under a car")
end)
