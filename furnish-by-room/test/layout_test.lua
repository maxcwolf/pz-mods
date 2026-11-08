--- The layout option's values.
local Layout = require("FurnishByRoom/layout")

test("layout: combo indexes map both ways; catalog is the default", function()
    eq(Layout.fromIndex(1), "catalog")
    eq(Layout.fromIndex(2), "strip")
    eq(Layout.fromIndex(nil), "catalog")
    eq(Layout.fromIndex(9), "catalog")
    eq(Layout.toIndex("strip"), 2)
    eq(Layout.toIndex("odd"), 1)
    eq(Layout.other("strip"), "catalog")
    eq(Layout.other("catalog"), "strip")
end)
