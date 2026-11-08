--- Just enough of the game's ISUI widgets (and the globals they use) to build
--- the Starting Vehicle window in plain Lua and drive it like a player would:
--- open it, pick from combos, tick boxes and click list rows. The 3D scene
--- records every command it gets; drawing calls do nothing.
local UiStubs = {}

--- Creates a widget class with ISUI-style derive/new.
local function class(name, base)
    local cls = {}
    cls.__index = cls
    cls.Type = name
    if base then
        setmetatable(cls, { __index = base })
    end
    --- Derives a subclass.
    function cls:derive(subName)
        return class(subName, self)
    end
    return cls
end

--- Installs the stub widgets and UI globals.
function UiStubs.install()
    local noop = function() end
    UIFont = { Small = "Small", Medium = "Medium", Large = "Large" }
    getTextManager = function()
        return {
            getFontHeight = function() return 16 end,
            MeasureStringX = function(_, _, text) return #tostring(text or "") * 7 end,
        }
    end
    getCore = function()
        local function color(r, g, b)
            return { getR = function() return r end, getG = function() return g end, getB = function() return b end }
        end
        return {
            getScreenWidth = function() return 1920 end,
            getScreenHeight = function() return 1080 end,
            getGoodHighlitedColor = function() return color(0.2, 0.8, 0.2) end,
            getBadHighlitedColor = function() return color(0.8, 0.2, 0.2) end,
        }
    end
    getTexture = function(path) return { path = path, getWidth = function() return 300 end, getHeight = function() return 640 end } end
    getSoundManager = function() return { playUISound = noop } end
    UIManager = { getMillisSinceLastRender = function() return 16 end }
    SpriteModel = { new = function()
        local s = {}
        function s:setModelScriptName(n) self.model = n end
        function s:setTextureName(n) self.texture = n end
        return s
    end }
    ISCarMechanicsOverlay = { CarList = {}, PartList = {} }
    UiStubs.sceneCalls = {}

    local Element = class("ISUIElement")
    --- Creates an element at a position and size.
    function Element:new(x, y, w, h)
        local o = setmetatable({}, self)
        o.x, o.y, o.width, o.height = x or 0, y or 0, w or 0, h or 0
        o.children = {}
        o.visible = true
        o.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
        o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.8 }
        return o
    end
    Element.initialise, Element.instantiate, Element.noBackground = noop, noop, noop
    Element.prerender, Element.render = noop, noop
    Element.drawText, Element.drawTextCentre, Element.drawRect, Element.drawRectBorder = noop, noop, noop, noop
    Element.drawTextureScaledUniform, Element.setStencilRect, Element.clearStencilRect = noop, noop, noop
    Element.bringToTop, Element.addToUIManager, Element.setAnchorLeft, Element.setAnchorTop = noop, noop, noop, noop
    --- Adds a child and calls its createChildren like the game does.
    function Element:addChild(child)
        table.insert(self.children, child)
        child.parent = self
        if child.createChildren and not child.childrenCreated then
            child.childrenCreated = true
            child:createChildren()
        end
    end
    --- Removes a child.
    function Element:removeChild(child)
        for i, c in ipairs(self.children) do
            if c == child then table.remove(self.children, i) return end
        end
    end
    function Element:createChildren() end
    function Element:setVisible(v) self.visible = v end
    function Element:isVisible() return self.visible end
    function Element:getX() return self.x end
    function Element:getY() return self.y end
    function Element:setX(x) self.x = x end
    function Element:setY(y) self.y = y end
    function Element:getWidth() return self.width end
    function Element:getHeight() return self.height end
    function Element:setWidth(w) self.width = w end
    function Element:setHeight(h) self.height = h end
    function Element:getRight() return self.x + self.width end
    function Element:getBottom() return self.y + self.height end
    function Element:isMouseOver() return false end
    function Element:getMouseX() return 0 end
    function Element:getMouseY() return 0 end
    ISUIElement = Element

    --- Draws one frame of an element tree the way the game does: prerender,
    --- render, then the children; a scene marked broken throws like Java.
    function UiStubs.frame(element)
        if not element.visible then return end
        if element.prerender then element:prerender() end
        if element.render then element:render() end
        for _, child in ipairs(element.children) do
            if child.brokenRender then error("scene render failed") end
            UiStubs.frame(child)
        end
    end

    ISPanel = Element:derive("ISPanel")
    ISCollapsableWindow = Element:derive("ISCollapsableWindow")
    function ISCollapsableWindow:titleBarHeight() return 20 end
    function ISCollapsableWindow:setTitle(t) self.title = t end
    ISCollapsableWindow.setResizable = noop
    --- Builds the window's children the first time it is initialised.
    function ISCollapsableWindow:initialise()
        if not self.childrenCreated then
            self.childrenCreated = true
            self:createChildren()
        end
    end

    ISLabel = Element:derive("ISLabel")
    --- Creates a label sized to its text.
    function ISLabel:new(x, y, h, name)
        local o = Element.new(self, x, y, #tostring(name) * 7, h)
        o.name = name
        return o
    end
    function ISLabel:setName(n) self.name = n end

    ISButton = Element:derive("ISButton")
    --- Creates a button.
    function ISButton:new(x, y, w, h, title, target)
        local o = Element.new(self, x, y, w, h)
        o.title, o.target = title, target
        return o
    end
    --- Stores the click handler and its arguments.
    function ISButton:setOnClick(fn, a, b) self.onclick, self.args = fn, { a, b } end
    --- Clicks the button the way the game calls handlers.
    function ISButton:click() self.onclick(self.target, self, self.args[1], self.args[2]) end
    function ISButton:setTitle(t) self.title = t end

    ISComboBox = Element:derive("ISComboBox")
    --- Creates a combo box.
    function ISComboBox:new(x, y, w, h, target, onChange, a, b)
        local o = Element.new(self, x, y, w, h)
        o.target, o.onChange, o.args = target, onChange, { a, b }
        o.options, o.selected = {}, 1
        return o
    end
    function ISComboBox:clear() self.options, self.selected = {}, 0 end
    function ISComboBox:addOptionWithData(text, data) table.insert(self.options, { text = text, data = data }) end
    function ISComboBox:getOptionData(i) return self.options[i] and self.options[i].data end
    --- Selects the option holding a value.
    function ISComboBox:selectData(data)
        for i, o in ipairs(self.options) do
            if o.data == data then self.selected = i return end
        end
    end
    --- Picks an option by its data and fires onChange, like a player would.
    function ISComboBox:pick(data)
        self:selectData(data)
        assert(self:getOptionData(self.selected) == data, "no option " .. tostring(data))
        self.onChange(self.target, self, self.args[1], self.args[2])
    end

    ISTextEntryBox = Element:derive("ISTextEntryBox")
    --- Creates a text entry.
    function ISTextEntryBox:new(text, x, y, w, h)
        local o = Element.new(self, x, y, w, h)
        o.text = text
        return o
    end
    function ISTextEntryBox:getInternalText() return self.text end
    function ISTextEntryBox:setText(t) self.text = t end

    ISTickBox = Element:derive("ISTickBox")
    --- Creates a tick box.
    function ISTickBox:new(x, y, w, h, name, target, method)
        local o = Element.new(self, x, y, w, h)
        o.target, o.method = target, method
        o.options, o.optionsIndex, o.selectedOptions = {}, {}, {}
        return o
    end
    function ISTickBox:addOption(name) table.insert(self.options, name) self.optionsIndex[#self.options] = name end
    function ISTickBox:setSelected(i, v) self.selectedOptions[i] = v end
    function ISTickBox:isSelected(i) return self.selectedOptions[i] == true end
    ISTickBox.setWidthToFit = noop
    --- Toggles an option and fires the handler like the game does.
    function ISTickBox:toggle(i)
        self.selectedOptions[i] = not self.selectedOptions[i]
        self.method(self.target, i, self.selectedOptions[i], nil, nil, self)
    end

    ISScrollingListBox = Element:derive("ISScrollingListBox")
    --- Creates a list.
    function ISScrollingListBox:new(x, y, w, h)
        local o = Element.new(self, x, y, w, h)
        o.items, o.count, o.selected, o.itemheight = {}, 0, 1, 16
        return o
    end
    function ISScrollingListBox:clear() self.items, self.count, self.selected = {}, 0, 1 end
    --- Adds a row.
    function ISScrollingListBox:addItem(text, item)
        self.count = self.count + 1
        local row = { text = text, item = item, itemindex = self.count, height = self.itemheight }
        table.insert(self.items, row)
        return row
    end
    ISScrollingListBox.setScrollHeight, ISScrollingListBox.ensureVisible = noop, noop
    function ISScrollingListBox:getYScroll() return 0 end
    --- Returns the row at a point (tests pass the row number as y).
    function ISScrollingListBox:rowAt(_, y) return y end

    ISUI3DScene = Element:derive("ISUI3DScene")
    --- Creates a scene whose Java side records every command.
    function ISUI3DScene:new(x, y, w, h)
        local o = Element.new(self, x, y, w, h)
        local java = {}
        local objects = {}
        for n = 0, 9 do
            java["fromLua" .. n] = function(_, command, ...)
                local args = { ... }
                table.insert(UiStubs.sceneCalls, { command = command, args = args })
                if command == "getObjectTranslation" or command == "getObjectScale" or command == "getObjectRotation" then
                    local vector = { object = args[1] }
                    --- Records the values set on the scene object's vector.
                    function vector:set(x, y, z)
                        table.insert(UiStubs.sceneCalls, { command = command .. ":set", args = { args[1], x, y, z } })
                    end
                    return vector
                elseif command == "createModel" or command == "createVehicle" then
                    objects[args[1]] = true
                elseif command == "removeObject" then
                    objects[args[1]] = nil
                elseif command == "getObjectExists" then
                    return objects[args[1]] == true
                end
                return nil
            end
        end
        o.javaObject = java
        return o
    end
    function ISUI3DScene:setView(v) self.view = v end

    for _, name in ipairs({ "ISUI/ISCollapsableWindow", "ISUI/ISPanel", "ISUI/ISLabel", "ISUI/ISButton", "ISUI/ISComboBox",
        "ISUI/ISTextEntryBox", "ISUI/ISTickBox", "ISUI/ISScrollingListBox", "ISUI/ISUIElement",
        "Vehicles/ISUI/ISUI3DScene", "Vehicles/ISUI/ISCarMechanicsOverlay" }) do
        package.loaded[name] = true
    end
end

--- Returns the scene commands recorded so far with this name.
function UiStubs.calls(command)
    local found = {}
    for _, call in ipairs(UiStubs.sceneCalls) do
        if call.command == command then
            found[#found + 1] = call
        end
    end
    return found
end

return UiStubs
