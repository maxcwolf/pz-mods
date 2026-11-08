--- Stand-ins for the game's ISUI widgets, enough to build both layouts,
--- click buttons and cards, type in the search box, press keys and read
--- back what was drawn. Shapes follow vanilla: ISButton calls
--- onclick(target, button); ISTextEntryBox calls
--- onTextChangeFunction(target, box); instantiate() runs createChildren().
local FakeUI = {}

--- Installs the fakes as globals.
function FakeUI.install()
    FakeUI.screen = {}
    for _, name in ipairs({ "ISUI/ISPanel", "ISUI/ISCollapsableWindow", "ISUI/ISButton", "ISUI/ISTextEntryBox" }) do
        package.preload[name] = function() return true end
        package.loaded[name] = nil
    end

    local Element = {}
    Element.__index = Element
    --- Makes a subclass.
    function Element:derive(name)
        local cls = setmetatable({ Type = name }, { __index = self })
        cls.__index = cls
        return cls
    end
    --- Makes an element of the calling class.
    function Element.new(cls, x, y, w, h)
        local o = setmetatable({ x = x, y = y, width = w, height = h, children = {}, visible = true,
            drawn = {}, mouseX = 0, mouseY = 0, mouseOver = false }, cls)
        return o
    end
    --- Does nothing.
    function Element:initialise() end
    --- Builds children once, like the game's instantiate.
    function Element:instantiate()
        if not self.instantiated then
            self.instantiated = true
            if self.createChildren then self:createChildren() end
        end
    end
    --- Does nothing.
    function Element:createChildren() end
    --- Adds a child.
    function Element:addChild(child) child.parent = self; self.children[#self.children + 1] = child end
    --- Removes a child.
    function Element:removeChild(child)
        for i, c in ipairs(self.children) do
            if c == child then table.remove(self.children, i) return end
        end
    end
    --- Puts it on screen.
    function Element:addToUIManager() self:instantiate(); FakeUI.screen[self] = true end
    --- Takes it off screen.
    function Element:removeFromUIManager() FakeUI.screen[self] = nil end
    --- Shows or hides.
    function Element:setVisible(v) self.visible = v end
    --- Returns visibility.
    function Element:isVisible() return self.visible end
    --- Records the wish for key events.
    function Element:setWantKeyEvents(v) self.wantsKeys = v end
    --- Sets y.
    function Element:setY(v) self.y = v end
    --- Returns y.
    function Element:getY() return self.y end
    --- Sets the height.
    function Element:setHeight(v) self.height = v end
    --- Returns the mouse x inside the element.
    function Element:getMouseX() return self.mouseX end
    --- Returns the mouse y inside the element.
    function Element:getMouseY() return self.mouseY end
    --- Returns true when the mouse is over it.
    function Element:isMouseOver() return self.mouseOver end
    --- Records drawn text.
    function Element:drawText(s) self.drawn[#self.drawn + 1] = s end
    --- Records drawn text.
    function Element:drawTextCentre(s) self.drawn[#self.drawn + 1] = s end
    --- Records drawn text.
    function Element:drawTextRight(s) self.drawn[#self.drawn + 1] = s end
    --- Does nothing.
    function Element:drawRect() end
    --- Does nothing.
    function Element:drawRectBorder() end
    --- Records a drawn picture.
    function Element:drawTextureScaledAspect(tex) self.drawn[#self.drawn + 1] = "tex:" .. tex.name end
    --- Does nothing.
    function Element:setStencilRect() end
    --- Does nothing.
    function Element:clearStencilRect() end
    --- Does nothing.
    function Element:render() end
    --- Does nothing.
    function Element:onMouseDown() return true end

    _G.ISUIElement = Element
    _G.ISPanel = Element:derive("ISPanel")
    _G.ISCollapsableWindow = Element:derive("ISCollapsableWindow")
    --- Returns the title bar height.
    function ISCollapsableWindow:titleBarHeight() return 16 end
    --- Sets the title.
    function ISCollapsableWindow:setTitle(t) self.title = t end
    --- Ignores resize settings.
    function ISCollapsableWindow:setResizable() end

    _G.ISButton = Element:derive("ISButton")
    --- Makes a button.
    function ISButton:new(x, y, w, h, title, target, onclick)
        local o = Element.new(self, x, y, w, h)
        o.title, o.target, o.onclick = title, target, onclick
        return o
    end
    --- Sets the title.
    function ISButton:setTitle(t) self.title = t end
    --- Test helper: clicks the button.
    function ISButton:click() self.onclick(self.target, self) end

    _G.ISTextEntryBox = Element:derive("ISTextEntryBox")
    --- Makes a text box.
    function ISTextEntryBox:new(text, x, y, w, h)
        local o = Element.new(self, x, y, w, h)
        o.text = text
        return o
    end
    --- Returns the text.
    function ISTextEntryBox:getInternalText() return self.text end
    --- Sets the text.
    function ISTextEntryBox:setText(t) self.text = t end
    --- Test helper: types text, firing the change callback.
    function ISTextEntryBox:type(t)
        self.text = t
        if self.onTextChangeFunction then self.onTextChangeFunction(self.target, self) end
    end
end

--- Returns true when the element is on screen and visible.
function FakeUI.showing(element)
    return element ~= nil and FakeUI.screen[element] == true and element.visible
end

--- Returns the first child button whose title starts with the text.
function FakeUI.button(parent, title)
    for _, child in ipairs(parent.children) do
        if child.title and string.sub(child.title, 1, #title) == title then
            return child
        end
    end
    return nil
end

--- Returns the titles of child buttons with an internal value.
function FakeUI.chipTitles(parent)
    local out = {}
    for _, child in ipairs(parent.children) do
        if child.internal and child.title then
            out[#out + 1] = child.title
        end
    end
    return out
end

--- Renders an element and returns everything it drew, joined.
function FakeUI.draw(element)
    element.drawn = {}
    element:render()
    return table.concat(element.drawn, "\n")
end

--- Makes a fake right-click menu that records its options.
function FakeUI.menu()
    local m = { options = {} }
    --- Adds an option.
    function m:addOption(name, target, fn)
        local o = { name = name, target = target, fn = fn }
        self.options[#self.options + 1] = o
        return o
    end
    return m
end

return FakeUI
