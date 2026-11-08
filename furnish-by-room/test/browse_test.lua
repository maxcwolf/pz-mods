--- Filtering by room, category and search, and stepping through lists.
local Browse = require("FurnishByRoom/browse")

local catalog = { rooms = {
    kitchen = {
        cats = { "appliances", "floors" },
        entries = {
            { key = "a", label = "White Fridge", cat = "appliances" },
            { key = "b", label = "Modern Oven", cat = "appliances" },
            { key = "c", label = "White Tiles", cat = "floors" },
        },
    },
    bar = { cats = { "seating" }, entries = { { key = "d", label = "Bar Stool", cat = "seating" } } },
} }

--- Returns the keys of the view's items.
local function keys(view)
    local out = {}
    for _, e in ipairs(Browse.items(catalog, view)) do out[#out + 1] = e.key end
    return table.concat(out, ",")
end

test("browse: all, then a category", function()
    local view = Browse.new("kitchen")
    eq(keys(view), "a,b,c")
    Browse.setCategory(catalog, view, "floors")
    eq(keys(view), "c")
    Browse.setCategory(catalog, view, "beds")
    eq(view.cat, "all", "a category the room lacks falls back")
end)

test("browse: search covers the whole room, every word must match", function()
    local view = Browse.new("kitchen")
    Browse.setCategory(catalog, view, "floors")
    view.query = "white"
    eq(keys(view), "a,c", "ignores the category")
    view.query = "WHITE  tiles"
    eq(keys(view), "c")
    view.query = "   "
    eq(keys(view), "c", "blank search is no search")
end)

test("browse: switching rooms resets category and search", function()
    local view = Browse.new("kitchen")
    view.cat, view.query = "floors", "x"
    Browse.setRoom(view, "bar")
    eq(view.cat, "all")
    eq(view.query, "")
    eq(keys(view), "d")
    eq(table.concat(Browse.filters(catalog, view), ","), "all,seating")
end)

test("browse: next category wraps; neighbor steps and wraps", function()
    local view = Browse.new("kitchen")
    eq(Browse.nextCategory(catalog, view), "appliances")
    view.cat = "floors"
    eq(Browse.nextCategory(catalog, view), "all")
    local list = Browse.items(catalog, Browse.new("kitchen"))
    eq(Browse.neighbor(list, "a", 1).key, "b")
    eq(Browse.neighbor(list, "a", -1).key, "c")
    eq(Browse.neighbor(list, "zzz", 1).key, "a")
    eq(Browse.neighbor({}, "a", 1), nil)
    eq(Browse.find(catalog, "kitchen", "c").label, "White Tiles")
    eq(Browse.find(catalog, "kitchen", "nope"), nil)
end)
