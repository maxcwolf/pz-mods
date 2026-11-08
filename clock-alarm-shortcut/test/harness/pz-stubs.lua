--- Just enough of the Project Zomboid Lua/Java surface to load the mod's
--- client files and drive them outside the game.
local Stubs = {}

Stubs.players = {}
Stubs.textures = {}
Stubs.clockSizeOption = 1
Stubs.dialogs = {}
Stubs.joypadFocus = {}
Stubs.handlers = { OnGameStart = {} }

--- Resets every piece of fake game state between tests.
function Stubs.reset()
    Stubs.players = {}
    Stubs.textures = {}
    Stubs.clockSizeOption = 1
    Stubs.dialogs = {}
    Stubs.joypadFocus = {}
    Stubs.clock = Stubs.newClock(1000, 20, true)
    JoypadState.players = {}
    if ClockAlarmShortcut_BellOverlay then ClockAlarmShortcut_BellOverlay.rects = {} end
end

--- Wraps a Lua list as a Java-style list with size() and get(i).
function Stubs.javaList(items)
    return {
        size = function() return #items end,
        get = function(_, i) return items[i + 1] end,
    }
end

--- Builds a fake alarm item. `javaClass` is AlarmClock or AlarmClockClothing.
function Stubs.alarm(javaClass, digital, opts)
    opts = opts or {}
    local item = { javaClass = javaClass, digital = digital, worn = opts.worn, equipped = opts.equipped, name = opts.name }
    function item:isDigital() return self.digital end
    function item:isWorn() return self.worn == true end
    function item:isEquipped() return self.equipped == true end
    return item
end

--- Builds a plain item that is not an alarm.
function Stubs.plainItem(opts)
    opts = opts or {}
    local item = { javaClass = "InventoryItem", worn = opts.worn, equipped = opts.equipped }
    function item:isWorn() return self.worn == true end
    function item:isEquipped() return self.equipped == true end
    return item
end

--- Builds a fake local player with worn items and inventory items.
function Stubs.player(num, worn, inventory, dead)
    local player = { num = num, dead = dead == true }
    function player:isDead() return self.dead end
    function player:getPlayerNum() return self.num end
    function player:getWornItems()
        return {
            size = function() return #worn end,
            getItemByIndex = function(_, i) return worn[i + 1] end,
        }
    end
    function player:getInventory()
        return { getItems = function() return Stubs.javaList(inventory) end }
    end
    return player
end

--- Builds a fake HUD clock at a screen position.
function Stubs.newClock(x, y, visible)
    local clock = { x = x, y = y, visible = visible }
    function clock:getX() return self.x end
    function clock:getY() return self.y end
    function clock:isVisible() return self.visible end
    return clock
end

-- Game globals the mod reads.

function require() end

function instanceof(object, className)
    return type(object) == "table" and object.javaClass == className
end

function getNumActivePlayers() return #Stubs.players end

function getSpecificPlayer(i) return Stubs.players[i + 1] end

function getCore()
    return { getOptionClockSize = function() return Stubs.clockSizeOption end }
end

function getTexture(path)
    local size = Stubs.textures[path]
    if not size then return nil end
    return { getWidth = function() return size[1] end, getHeight = function() return size[2] end }
end

function getPlayerInventory(num) return { inventoryOf = num } end

function setJoypadFocus(num, target) Stubs.joypadFocus[num] = target end

UIManager = { getClock = function() return Stubs.clock end }

JoypadState = { players = {} }

Events = {
    OnGameStart = { Add = function(fn) table.insert(Stubs.handlers.OnGameStart, fn) end },
}

--- Minimal ISUIElement: geometry, derive, and UI-manager bookkeeping.
ISUIElement = {}
ISUIElement.__index = ISUIElement

function ISUIElement:derive(name)
    local class = {}
    setmetatable(class, self)
    self.__index = self
    class.Type = name
    return class
end

function ISUIElement:new(x, y, width, height)
    local o = { x = x, y = y, width = width, height = height, visible = true }
    setmetatable(o, self)
    self.__index = self
    return o
end

function ISUIElement:initialise() end
function ISUIElement:addToUIManager() self.inUIManager = true end
function ISUIElement:backMost() self.atBack = true end
function ISUIElement:bringToTop() self.broughtToTop = (self.broughtToTop or 0) + 1 end
function ISUIElement:isVisible() return self.visible end
function ISUIElement:setX(v) self.x = v end
function ISUIElement:setY(v) self.y = v end
function ISUIElement:setWidth(v) self.width = v end
function ISUIElement:setHeight(v) self.height = v end

--- Fake vanilla alarm dialog that records how it was opened.
ISAlarmClockDialog = ISUIElement:derive("ISAlarmClockDialog")

function ISAlarmClockDialog:new(x, y, width, height, player, alarm)
    local o = ISUIElement.new(self, x, y, width, height)
    o.player = player
    o.alarm = alarm
    table.insert(Stubs.dialogs, o)
    return o
end

function print() end

Stubs.clock = Stubs.newClock(1000, 20, true)

return Stubs
