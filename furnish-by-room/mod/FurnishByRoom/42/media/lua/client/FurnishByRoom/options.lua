--- The mod's entries under Options > Mods: the open key, which layout to
--- use (catalog window or bottom strip) and whether to ignore the game's
--- placement rules.
local Layout = require("FurnishByRoom/layout")

local Options = {}

Options.ID = "FurnishByRoom"
Options.DEFAULT_KEY = 65

--- Registers the options with the game. Safe to call more than once.
function Options.setup()
    if Options.handle or not (PZAPI and PZAPI.ModOptions) then
        return Options.handle
    end
    local o = PZAPI.ModOptions:create(Options.ID, getText("UI_FBR_Title"))
    o:addKeyBind("key", getText("UI_FBR_Option_Key"), Keyboard and Keyboard.KEY_F7 or Options.DEFAULT_KEY)
    local combo = o:addComboBox("layout", getText("UI_FBR_Option_Layout"), getText("UI_FBR_Option_LayoutTip"))
    combo:addItem("UI_FBR_Layout_catalog", true)
    combo:addItem("UI_FBR_Layout_strip", false)
    o:addTickBox("anywhere", getText("UI_FBR_Option_Anywhere"), false, getText("UI_FBR_Option_AnywhereTip"))
    Options.handle = o
    return o
end

--- Returns an option by id, or nil before setup.
local function option(id)
    return Options.handle and Options.handle:getOption(id) or nil
end

--- Returns the chosen layout name.
function Options.layout()
    local o = option("layout")
    return Layout.fromIndex(o and o:getValue())
end

--- Saves a new layout choice.
function Options.setLayout(layout)
    local o = option("layout")
    if o then
        o:setValue(Layout.toIndex(layout))
        if PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.save then
            PZAPI.ModOptions:save()
        end
    end
end

--- Returns the key that opens and closes the mod.
function Options.key()
    local o = option("key")
    return o and o:getValue() or Options.DEFAULT_KEY
end

--- Returns true when furniture may go anywhere with a floor.
function Options.anywhere()
    local o = option("anywhere")
    return o ~= nil and o:getValue() == true
end

return Options
