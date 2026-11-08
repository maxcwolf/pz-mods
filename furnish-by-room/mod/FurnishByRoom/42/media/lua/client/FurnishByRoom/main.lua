--- Hooks the mod into the game: its options, the open key, Ctrl+Z, the
--- right-click menu, and the two layouts.
require "FurnishByRoom/CatalogWindow"
require "FurnishByRoom/ItemStrip"
local Controller = require("FurnishByRoom/controller")
local Options = require("FurnishByRoom/options")
local Layout = require("FurnishByRoom/layout")
local Menu = require("FurnishByRoom/menu")

local Main = {}

--- Returns true while the mod's UI or a mouse mode is up.
function Main.active()
    return Controller.placing ~= nil or (Controller.view ~= nil and Controller.view:isShown())
end

--- Opens or closes on the chosen key; undoes on Ctrl+Z while active.
function Main.onKeyPressed(key)
    if not Controller.player() then
        return
    end
    if key == Options.key() then
        Controller.toggle()
    elseif key == Keyboard.KEY_Z and isCtrlKeyDown() and Main.active() then
        Controller.undo()
    end
end

--- Registers the layouts and events.
function Main.install()
    Options.setup()
    Controller.registerView(Layout.CATALOG, FBR_CatalogWindow.create)
    Controller.registerView(Layout.STRIP, FBR_ItemStrip.create)
    Events.OnKeyPressed.Add(Main.onKeyPressed)
    Events.OnFillWorldObjectContextMenu.Add(Menu.onFill)
end

if isClient() then
    Controller.log("single player only; not active in multiplayer")
else
    Main.install()
end

return Main
