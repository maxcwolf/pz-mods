--- Just enough of Project Zomboid's UI classes, fonts, game speed and file
--- access to load the editor's window, on-screen button and context menu and
--- drive them outside the game.
local Stubs = { speed = 1, multiplier = 1, files = {}, sounds = 0, screenWidth = 1920, screenHeight = 1080 }

for _, name in ipairs({ "ISUI/ISCollapsableWindow", "ISUI/ISButton", "ISUI/ISScrollingListBox", "ISUI/ISPanel" }) do
    package.preload[name] = function() return true end
end

UIFont = { Small = "Small", Medium = "Medium", Large = "Large" }
local textManager = {
    getFontHeight = function(_, font) return font == UIFont.Large and 24 or (font == UIFont.Medium and 18 or 14) end,
    MeasureStringX = function(_, _, text) return #tostring(text) * 7 end,
}
--- Returns the fake text manager.
function getTextManager() return textManager end
--- Returns a translation key with its arguments, so tests can see both.
function getText(key, a, b, c)
    local parts = { key }
    for _, value in ipairs({ a, b, c }) do parts[#parts + 1] = tostring(value) end
    return table.concat(parts, "|")
end
--- Returns the fake core with a fixed screen size.
function getCore()
    return { getScreenWidth = function() return Stubs.screenWidth end, getScreenHeight = function() return Stubs.screenHeight end }
end
local clockRect = { x = 1754, y = 10, width = 156, height = 62 }
Stubs.clock = clockRect
UIManager = {
    getClock = function()
        local rect = Stubs.clock
        if rect == nil then return nil end
        return { getX = function() return rect.x end, getY = function() return rect.y end,
            getWidth = function() return rect.width end, getHeight = function() return rect.height end }
    end,
}
--- Returns the stubbed game speed.
function getGameSpeed() return Stubs.speed end
--- Sets the stubbed game speed.
function setGameSpeed(speed) Stubs.speed = speed end
local worldHours = getGameTime
--- Returns a GameTime with world hours and a time multiplier.
function getGameTime()
    local base = worldHours and worldHours() or {}
    base.getTrueMultiplier = function() return Stubs.multiplier end
    base.setMultiplier = function(_, value) Stubs.multiplier = value end
    return base
end
--- Returns a sound manager that counts UI sounds.
function getSoundManager() return { playUISound = function() Stubs.sounds = Stubs.sounds + 1 end } end
--- Returns the stubbed mouse position.
function getMouseX() return Stubs.mouseX or 0 end
--- Returns the stubbed mouse position.
function getMouseY() return Stubs.mouseY or 0 end
--- Returns the test's current player.
function getPlayer() return Stubs.player end
--- Opens a fake file for reading.
function getFileReader(name)
    local text = Stubs.files[name]
    if text == nil then return nil end
    return { readLine = function() return text end, close = function() end }
end
--- Opens a fake file for writing.
function getFileWriter(name)
    local buffer = {}
    return { write = function(_, text) buffer[#buffer + 1] = text end,
        close = function() Stubs.files[name] = table.concat(buffer) end }
end

Stubs.events = {}
Events = Events or {}
for _, name in ipairs({ "OnGameStart", "OnServerCommand", "OnFillWorldObjectContextMenu", "OnClientCommand", "OnServerStarted" }) do
    Stubs.events[name] = {}
    Events[name] = { Add = function(fn) table.insert(Stubs.events[name], fn) end }
end
--- Calls every handler registered for an event.
function Stubs.fire(name, ...)
    for _, fn in ipairs(Stubs.events[name] or {}) do fn(...) end
end

local Element = {}
Element.__index = Element
--- Makes a subclass.
function Element:derive(name)
    local cls = setmetatable({ className = name }, { __index = self })
    cls.__index = cls
    return cls
end
--- Creates an element.
function Element.new(cls, x, y, width, height)
    return setmetatable({ x = x or 0, y = y or 0, width = width or 0, height = height or 0, children = {}, visible = true }, cls)
end
function Element:initialise() self:createChildren() end
function Element:createChildren() end
function Element:instantiate() end
function Element:addChild(child) self.children[#self.children + 1] = child; child.parent = self end
function Element:setX(x) self.x = x end
function Element:setY(y) self.y = y end
function Element:getX() return self.x end
function Element:getY() return self.y end
function Element:setWidth(w) self.width = w end
function Element:setHeight(h) self.height = h end
function Element:getWidth() return self.width end
function Element:getHeight() return self.height end
function Element:setVisible(v) self.visible = v end
function Element:getIsVisible() return self.visible end
function Element:isMouseOver() return false end
function Element:getMouseX() return 0 end
function Element:getMouseY() return 0 end
function Element:addToUIManager() self.managed = true end
function Element:removeFromUIManager() self.managed = false end
function Element:bringToTop() end
function Element:setCapture() end
function Element:drawRect() end
function Element:drawRectBorder() end
function Element:drawText() end
function Element:drawTextCentre() end
function Element:render() end

ISPanel = Element:derive("ISPanel")

ISCollapsableWindow = Element:derive("ISCollapsableWindow")
--- Remembers the title.
function ISCollapsableWindow:setTitle(title) self.title = title end
function ISCollapsableWindow:titleBarHeight() return 20 end
function ISCollapsableWindow:close() self:setVisible(false) end

ISButton = Element:derive("ISButton")
--- Creates a button with a click handler.
function ISButton:new(x, y, width, height, title, target, onclick)
    local o = Element.new(self, x, y, width, height)
    o.title, o.target, o.onclick, o.enabled = title, target, onclick, true
    return o
end
function ISButton:setEnable(enabled) self.enabled = enabled end
--- Simulates a click the way ISButton:onMouseUp calls its handler.
function ISButton:click() self.onclick(self.target, self) end

ISScrollingListBox = Element:derive("ISScrollingListBox")
--- Creates an empty list.
function ISScrollingListBox:new(x, y, width, height)
    local o = Element.new(self, x, y, width, height)
    o.items, o.itemheight = {}, 20
    return o
end
function ISScrollingListBox:clear() self.items = {} end
function ISScrollingListBox:addItem(name, item) self.items[#self.items + 1] = { text = name, item = item, height = self.itemheight } end
--- Finds the row under a content y.
function ISScrollingListBox:rowAt(x, y)
    local top = 0
    for index, item in ipairs(self.items) do
        if y >= top and y < top + item.height then return index end
        top = top + item.height
    end
    return -1
end
--- Returns a row's content y.
function ISScrollingListBox:topOfItem(index)
    local top = 0
    for i, item in ipairs(self.items) do
        if i == index then return top end
        top = top + item.height
    end
    return -1
end

ISContextMenu = {}
--- Returns a context menu that records its options.
function ISContextMenu.get()
    return Stubs.menu()
end
--- Builds a recording context menu.
function Stubs.menu()
    local menu = { options = {} }
    function menu:addOption(name, target, fn, a, b) self.options[#self.options + 1] = { name = name, target = target, fn = fn, a = a, b = b } return self.options[#self.options] end
    return menu
end

return Stubs
