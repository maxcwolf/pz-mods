--- Hooks the mod into the game: the right-click menu, the change highlight,
--- applying blueprints as the map loads, and auto-applying in new games.
require "BaseBlueprints/BlueprintWindow"
local Runtime = require("BaseBlueprints/runtime")
local Overlay = require("BaseBlueprints/overlay")
local Menu = require("BaseBlueprints/menu")

local Main = {}

--- Loads the save state and applies anything waiting near the player.
function Main.onGameStart()
    Runtime.state()
    Runtime.processLoaded()
end

--- Applies the blueprints marked for new games.
function Main.onNewGame()
    Runtime.state()
    Runtime.applyAuto()
end

--- Retries waiting squares once a game minute in case a load was missed.
function Main.everyOneMinute()
    local root = Runtime.cache
    if root and root.columns then
        for _ in pairs(root.columns) do
            Runtime.processLoaded()
            return
        end
    end
end

if isClient() then
    Runtime.log("single player only; not active in multiplayer")
else
    Events.OnGameStart.Add(Main.onGameStart)
    Events.OnNewGame.Add(Main.onNewGame)
    Events.EveryOneMinute.Add(Main.everyOneMinute)
    Events.LoadGridsquare.Add(Runtime.onLoadGridsquare)
    Events.OnTick.Add(Runtime.onTick)
    Events.OnRenderTick.Add(Overlay.onRenderTick)
    Events.OnFillWorldObjectContextMenu.Add(Menu.onFill)
end

return Main
