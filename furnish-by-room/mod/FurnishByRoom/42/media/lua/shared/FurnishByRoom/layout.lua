--- The two layouts the player can switch between, as stored in the mod
--- options combo box (1 = catalog window, 2 = bottom strip).
local Layout = {}

Layout.CATALOG = "catalog"
Layout.STRIP = "strip"
Layout.ORDER = { Layout.CATALOG, Layout.STRIP }

--- Returns the layout for a combo box index; the catalog for anything else.
function Layout.fromIndex(index)
    return Layout.ORDER[index] or Layout.CATALOG
end

--- Returns the combo box index for a layout.
function Layout.toIndex(layout)
    for i, name in ipairs(Layout.ORDER) do
        if name == layout then
            return i
        end
    end
    return 1
end

--- Returns the other layout.
function Layout.other(layout)
    if layout == Layout.STRIP then
        return Layout.CATALOG
    end
    return Layout.STRIP
end

return Layout
