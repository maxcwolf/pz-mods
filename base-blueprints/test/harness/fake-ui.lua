--- Stand-ins for the game's ISUI widgets, just enough to build the window,
--- click its buttons and tick boxes, answer its dialogs and fill the
--- right-click menu. Widgets follow the vanilla shapes: ISButton calls
--- onClick(target, button), ISTickBox calls changed(target, index, selected),
--- ISScrollingListBox calls onmousedown(target, item), ISModalDialog calls
--- onclick(target, button) with button.internal "YES" or "NO".
local FakeUI = { modals = {} }

--- Makes a basic element with position and children.
local function element(x, y, w, h)
    local e = { x = x, y = y, width = w, height = h, children = {}, visible = true, enable = true }
    --- Returns x.
    function e:getX() return self.x end
    --- Sets x.
    function e:setX(v) self.x = v end
    --- Returns the width.
    function e:getWidth() return self.width end
    --- Returns the right edge.
    function e:getRight() return self.x + self.width end
    --- Does nothing.
    function e:initialise() end
    --- Does nothing.
    function e:instantiate() end
    --- Adds a child.
    function e:addChild(child) self.children[#self.children + 1] = child end
    --- Sets enabled.
    function e:setEnable(v) self.enable = v end
    return e
end

--- Installs the fakes as globals.
function FakeUI.install()
    FakeUI.modals = {}
    for _, name in ipairs({ "ISUI/ISCollapsableWindow", "ISUI/ISLabel", "ISUI/ISButton", "ISUI/ISTickBox",
        "ISUI/ISTextEntryBox", "ISUI/ISScrollingListBox", "ISUI/ISModalDialog" }) do
        package.preload[name] = function() return true end
        package.loaded[name] = nil
    end
    _G.UIFont = { Medium = "Medium", Small = "Small" }
    _G.getTextManager = function()
        return { getFontHeight = function() return 16 end, MeasureStringX = function(_, _, s) return #s * 7 end }
    end
    _G.getCore = function()
        return { getScreenWidth = function() return 1920 end, getScreenHeight = function() return 1080 end }
    end
    _G.BBP_BlueprintWindow = nil

    _G.ISCollapsableWindow = {}
    --- Makes a subclass table.
    function ISCollapsableWindow:derive(name)
        local cls = setmetatable({ Type = name }, { __index = self })
        cls.__index = cls
        return cls
    end
    --- Creates a window of the calling class.
    function ISCollapsableWindow.new(cls, x, y, w, h)
        local o = element(x, y, w, h)
        setmetatable(o, { __index = function(t, k)
            local v = cls[k]
            if v ~= nil then return v end
            return ISCollapsableWindow[k]
        end })
        return o
    end
    --- Base createChildren.
    function ISCollapsableWindow.createChildren(self) end
    --- Returns the title bar height.
    function ISCollapsableWindow.titleBarHeight() return 16 end
    --- Ignores resize settings.
    function ISCollapsableWindow.setResizable() end
    --- Sets the title.
    function ISCollapsableWindow.setTitle(self, t) self.title = t end
    --- Builds children once.
    function ISCollapsableWindow.addToUIManager(self)
        if not self.built then
            self.built = true
            self:createChildren()
        end
    end
    --- Shows or hides.
    function ISCollapsableWindow.setVisible(self, v) self.visible = v end
    --- Does nothing.
    function ISCollapsableWindow.bringToTop() end

    _G.ISLabel = {}
    --- Makes a label.
    function ISLabel:new(x, y, h, name)
        local l = element(x, y, 100, h)
        l.name = name
        --- Sets the text.
        function l:setName(v) self.name = v end
        return l
    end

    _G.ISButton = {}
    --- Makes a button.
    function ISButton:new(x, y, w, h, title, target)
        local b = element(x, y, w, h)
        b.title, b.target = title, target
        --- Sets the click handler.
        function b:setOnClick(fn, arg) self.onclick, self.arg = fn, arg end
        --- Clicks it like a player would.
        function b:click()
            if not self.enable then error("clicked disabled button " .. self.title) end
            self.onclick(self.target, self, self.arg)
        end
        return b
    end

    _G.ISTickBox = {}
    --- Makes a tick box.
    function ISTickBox:new(x, y, w, h, name, target, changed)
        local t = element(x, y, w, h)
        t.target, t.changed, t.options, t.selected = target, changed, {}, {}
        --- Adds an option.
        function t:addOption(text) self.options[#self.options + 1] = text end
        --- Does nothing.
        function t:setWidthToFit() end
        --- Sets an option.
        function t:setSelected(i, v) self.selected[i] = v == true end
        --- Returns an option.
        function t:isSelected(i) return self.selected[i] == true end
        --- Toggles an option like a click.
        function t:click(i)
            i = i or 1
            self.selected[i] = not self.selected[i]
            if self.changed then self.changed(self.target, i, self.selected[i]) end
        end
        return t
    end

    _G.ISTextEntryBox = {}
    --- Makes a text entry.
    function ISTextEntryBox:new(text, x, y, w, h)
        local e = element(x, y, w, h)
        e.text = text
        --- Returns the typed text.
        function e:getInternalText() return self.text end
        --- Types text.
        function e:setText(v) self.text = v end
        return e
    end

    _G.ISScrollingListBox = {}
    --- Makes a list.
    function ISScrollingListBox:new(x, y, w, h)
        local l = element(x, y, w, h)
        l.items, l.selected = {}, 1
        --- Ignores fonts.
        function l:setFont() end
        --- Clears rows.
        function l:clear() self.items = {} end
        --- Adds a row.
        function l:addItem(text, item)
            self.items[#self.items + 1] = { text = text, item = item, index = #self.items + 1, height = self.itemheight }
        end
        --- Sets the click handler.
        function l:setOnMouseDownFunction(target, fn) self.target, self.onmousedown = target, fn end
        --- Clicks a row.
        function l:click(row)
            self.selected = row
            if self.onmousedown then self.onmousedown(self.target, self.items[row].item) end
        end
        return l
    end

    _G.ISModalDialog = {}
    --- Makes a dialog and remembers it so a test can answer it.
    function ISModalDialog:new(x, y, w, h, text, yesno, target, onclick)
        local d = element(x, y, w, h)
        d.text, d.target, d.onclick = text, target, onclick
        --- Does nothing.
        function d:addToUIManager() FakeUI.modals[#FakeUI.modals + 1] = self end
        --- Does nothing.
        function d:bringToTop() end
        --- Answers the dialog.
        function d:answer(yes) self.onclick(self.target, { internal = yes and "YES" or "NO" }) end
        return d
    end

    _G.ISContextMenu = {}
    --- Makes a submenu.
    function ISContextMenu:getNew()
        return FakeUI.menu()
    end
end

--- Makes a context menu that records options.
function FakeUI.menu()
    local m = { options = {} }
    --- Adds an option.
    function m:addOption(name, target, fn, a, b)
        local o = { name = name, target = target, fn = fn, a = a, b = b }
        self.options[#self.options + 1] = o
        return o
    end
    --- Attaches a submenu.
    function m:addSubMenu(option, sub) option.sub = sub end
    --- Returns the option whose name starts with a text.
    function m:find(prefix)
        for _, o in ipairs(self.options) do
            if string.sub(o.name, 1, #prefix) == prefix then return o end
        end
        return nil
    end
    return m
end

--- Answers the newest dialog.
function FakeUI.answer(yes)
    local d = table.remove(FakeUI.modals)
    assert(d, "no dialog open")
    d:answer(yes)
    return d
end

return FakeUI
