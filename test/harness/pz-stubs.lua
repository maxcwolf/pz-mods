--- Just enough of the Project Zomboid Lua/Java surface to load the client
--- files and drive the gear panel and spawn code outside the game.
local Stubs = {}

--- Wraps a Lua list as a Java-style list with size() and get(i).
function Stubs.javaList(items)
    return {
        size = function() return #items end,
        get = function(_, i) return items[i + 1] end,
    }
end

string.trim = string.trim or function(s) return (s:match("^%s*(.-)%s*$")) end
string.contains = string.contains or function(s, sub) return string.find(s, sub, 1, true) ~= nil end

UIFont = { Small = "Small", Medium = "Medium", Large = "Large" }
local textManager = {
    getFontHeight = function() return 12 end,
    MeasureStringX = function(_, _, text) return #tostring(text) * 6 end,
}
function getTextManager() return textManager end
function getText(key) return key end
function getTextOrNull(key) return nil end
function isClient() return false end
function isServer() return false end
function getTexture() return nil end

--- Minimal UI element base shared by every stub widget.
local Element = {}
Element.__index = Element
function Element:derive(name)
    local cls = setmetatable({ className = name }, { __index = self })
    cls.__index = cls
    return cls
end
function Element:new(x, y, width, height)
    return setmetatable({ x = x or 0, y = y or 0, width = width or 0, height = height or 0, children = {}, visible = true }, self)
end
function Element:initialise() self:createChildren() end
function Element:createChildren() end
function Element:instantiate() end
function Element:addChild(c) table.insert(self.children, c); c.parent = self end
function Element:removeChild(c) for i, v in ipairs(self.children) do if v == c then table.remove(self.children, i); return end end end
function Element:setX(x) self.x = x end
function Element:setY(y) self.y = y end
function Element:getX() return self.x end
function Element:getY() return self.y end
function Element:setWidth(w) self.width = w end
function Element:setHeight(h) self.height = h end
function Element:getWidth() return self.width end
function Element:getHeight() return self.height end
function Element:getRight() return self.x + self.width end
function Element:getBottom() return self.y + self.height end
function Element:setVisible(v) self.visible = v end
function Element:getIsVisible() return self.visible end
function Element:isReallyVisible() return self.visible end
function Element:isMouseOver() return false end
function Element:getAbsoluteX() return self.x end
function Element:getAbsoluteY() return self.y end
function Element:addToUIManager() self.inManager = true end
function Element:removeFromUIManager() self.inManager = false end
function Element:bringToTop() end
function Element:noBackground() end
function Element:setScrollHeight(h) self.scrollHeight = h end
function Element:update() end
function Element:setTooltip(t) self.tooltip = t end
function Element:onMouseDownOutside() end
function Element:drawRect() end
function Element:drawRectBorder() end
function Element:drawText() end
function Element:getYScroll() return 0 end
function Element:setFont() end
function Element:setOnlyNumbers() end
function Element:setResizable() end
function Element:setTitle(t) self.title = t end
function Element:titleBarHeight() return 16 end
function Element:clear() self.options = {}; self.items = {} end
function getCore() return { getScreenWidth = function() return 1920 end, getScreenHeight = function() return 1080 end } end

ISCollapsableWindow = Element:derive("ISCollapsableWindow")
CharacterCreationAvatar = Element:derive("CharacterCreationAvatar")
function CharacterCreationAvatar:setSurvivorDesc(desc) self.avatarPanel:setSurvivorDesc(desc) end

ISPanel = Element:derive("ISPanel")
ISRect = Element:derive("ISRect")
function ISRect:new(x, y, w, h) return Element.new(self, x, y, w, h) end

ISLabel = Element:derive("ISLabel")
function ISLabel:new(x, y, height, name, r, g, b, a, font, bLeft)
    local o = Element.new(self, x, y, #tostring(name) * 6, height)
    o.name = name
    if bLeft ~= true then o.x = o.x - o.width end
    return o
end
function ISLabel:setName(name) self.name = name; self.width = #tostring(name) * 6 end

ISButton = Element:derive("ISButton")
function ISButton:new(x, y, w, h, title, target, onclick)
    local o = Element.new(self, x, y, w, h)
    o.title = title; o.target = target; o.onclick = onclick
    return o
end
function ISButton:setOnClick(fn, arg1) self.onclick = fn; self.arg1 = arg1 end
function ISButton:click() self.onclick(self.target, self, self.arg1) end

ISComboBox = Element:derive("ISComboBox")
function ISComboBox:new(x, y, w, h, target, onChange, arg1)
    local o = Element.new(self, x, y, w, h)
    o.target = target; o.onChange = onChange; o.onChangeArgs = { arg1 }; o.options = {}; o.selected = 0
    return o
end
function ISComboBox:setEditable(e) self.editable = e end
function ISComboBox:addOptionWithData(text, data) table.insert(self.options, { text = text, data = data }) end
function ISComboBox:getOptionData(i) return self.options[i] and self.options[i].data end
function ISComboBox:selectData(data) for i, o in ipairs(self.options) do if o.data == data then self.selected = i; return end end end
function ISComboBox:pick(data) self:selectData(data); self.onChange(self.target, self, self.onChangeArgs[1]) end

ISTextEntryBox = Element:derive("ISTextEntryBox")
function ISTextEntryBox:new(title, x, y, w, h) local o = Element.new(self, x, y, w, h); o.text = title or ""; return o end
function ISTextEntryBox:setClearButton() end
function ISTextEntryBox:getInternalText() return self.text end
function ISTextEntryBox:setText(t) self.text = t end
function ISTextEntryBox:type(t) self.text = t; self:onTextChange() end
function ISTextEntryBox:onTextChange() end

ISScrollingListBox = Element:derive("ISScrollingListBox")
function ISScrollingListBox:new(x, y, w, h) local o = Element.new(self, x, y, w, h); o.items = {}; return o end
function ISScrollingListBox:clear() self.items = {} end
function ISScrollingListBox:addItem(text, item) table.insert(self.items, { text = text, item = item, index = #self.items + 1, height = 18 }) end
function ISScrollingListBox:setOnMouseDownFunction(target, fn) self.target = target; self.onmousedown = fn end
function ISScrollingListBox:setOnMouseDoubleClick(target, fn) self.target = target; self.ondblclick = fn end
function ISScrollingListBox:clickRow(i) self.selected = i; if self.onmousedown then self.onmousedown(self.target, self.items[i].item) end end
function ISScrollingListBox:doubleClickRow(i) self.selected = i; self.ondblclick(self.target, self.items[i].item) end

--- Vanilla-shaped hotbar slot definitions plus a modded sling slot.
ISHotbarAttachDefinition = {
    { type = "SmallBeltLeft", name = "Belt Left", attachments = { Wrench = "Wrench Left", Knife = "Belt Left Upside" } },
    { type = "SmallBeltRight", name = "Belt Right", attachments = { Wrench = "Wrench Right", Knife = "Belt Right Upside" } },
    { type = "Back", name = "Back", attachments = { Crowbar = "Back Crowbar", Rifle = "Back Rifle" } },
    { type = "AliceSling", name = "Sling", attachments = { Rifle = "AliceSlingRifle" } },
}
ISHotbarAttachDefinition.replacements = {
    { type = "Bag", replacement = { Rifle = "Bag Rifle", Crowbar = "null" } },
}

--- Script item and inventory item stubs.
local SCRIPT_ITEMS = {
    { fullType = "Base.Wrench", name = "Wrench", attachmentType = "Wrench", weight = 1, weapon = true, category = "Weapon" },
    { fullType = "Base.Machete", name = "Machete", attachmentType = "Knife", weight = 2, weapon = true, category = "Weapon" },
    { fullType = "Base.Crowbar", name = "Crowbar", attachmentType = "Crowbar", weight = 2, weapon = true, category = "Weapon" },
    { fullType = "Base.AssaultRifle", name = "M16", attachmentType = "Rifle", weight = 4, weapon = true, twoHanded = true, category = "Weapon" },
    { fullType = "Base.Pop", name = "Pop", weight = 0.3, category = "Food" },
    { fullType = "Base.WaterBottleFull", name = "Water Bottle", weight = 0.8, category = "Food" },
    { fullType = "Base.Bag_ALICEpack", name = "ALICE Pack", weight = 1, container = true, capacity = 27, provided = {}, replacement = "Bag", equip = "Back" },
    { fullType = "Base.Bag_Satchel", name = "Satchel", weight = 1, container = true, capacity = 12, provided = {}, equip = "Satchel" },
    { fullType = "Base.Belt2", name = "Belt", weight = 0.5, provided = { "SmallBeltLeft", "SmallBeltRight" } },
    { fullType = "alice.Sling", name = "Sling", weight = 0.5, provided = { "AliceSling" } },
    { fullType = "Base.Secret", name = "Secret", hidden = true },
    { fullType = "Moveables.Sofa", name = "Sofa" },
}
local function scriptStub(def)
    return {
        getFullName = function() return def.fullType end,
        getDisplayName = function() return def.name end,
        isHidden = function() return def.hidden == true end,
        getObsolete = function() return false end,
        getActualWeight = function() return def.weight or 0 end,
        getDisplayCategory = function() return def.category end,
    }
end
local scriptByType = {}
local scriptList = {}
for _, def in ipairs(SCRIPT_ITEMS) do scriptByType[def.fullType] = def; table.insert(scriptList, scriptStub(def)) end
function getScriptManager() return { getAllItems = function() return Stubs.javaList(scriptList) end } end

--- Creates an inventory-item stub for a full type.
function Stubs.item(fullType)
    local def = assert(scriptByType[fullType], "unknown stub item " .. tostring(fullType))
    local contents = {}
    local item = {
        classes = { InventoryItem = true, InventoryContainer = def.container, HandWeapon = def.weapon },
        contents = contents,
        getFullType = function() return def.fullType end,
        getDisplayName = function() return def.name end,
        getAttachmentType = function() return def.attachmentType end,
        getAttachmentsProvided = function() return def.provided and Stubs.javaList(def.provided) or nil end,
        getAttachmentReplacement = function() return def.replacement end,
        getCapacity = function() return def.capacity end,
        canBeEquipped = function() return def.equip and { getTranslationName = function() return def.equip end } or nil end,
        isTwoHandWeapon = function() return def.twoHanded == true end,
        isRequiresEquippedBothHands = function() return false end,
        getInventory = function() return { AddItem = function(_, t) local i = Stubs.item(t); table.insert(contents, i); return i end } end,
    }
    return item
end
function instanceItem(fullType) return Stubs.item(fullType) end
function instanceof(obj, cls) return type(obj) == "table" and obj.classes and obj.classes[cls] == true end

--- Worn items of a desc or player.
function Stubs.wornItems(list)
    return {
        size = function() return #list end,
        getItemByIndex = function(_, i) return list[i + 1].item end,
        get = function(_, i)
            local w = list[i + 1]
            return { getLocation = function() return w.location end }
        end,
    }
end

--- Fake files for getFileWriter / getFileReader.
Stubs.files = {}
function getFileWriter(name) return { write = function(_, text) Stubs.files[name] = text end, close = function() end } end
function getFileReader(name)
    local text = Stubs.files[name]
    if not text then return nil end
    local lines = {}
    for line in text:gmatch("[^\n]+") do table.insert(lines, line) end
    local i = 0
    return { readLine = function() i = i + 1; return lines[i] end, close = function() end }
end

--- Event bus.
Events = {}
for _, name in ipairs({ "OnNewGame", "OnCreatePlayer", "OnMainMenuEnter", "OnTick" }) do
    local handlers = {}
    Events[name] = {
        Add = function(fn) table.insert(handlers, fn) end,
        Remove = function(fn) for i, h in ipairs(handlers) do if h == fn then table.remove(handlers, i); return end end end,
        fire = function(...) for _, h in ipairs({ unpack(handlers) }) do h(...) end end,
    }
end

--- Fake hotbar that records attachments the way ISHotbar would.
function Stubs.hotbar(player)
    local hotbar = { chr = player, availableSlot = {}, attachedItems = {}, attached = {} }
    function hotbar:refresh()
        local slots = CSG_SlotLogic.availableSlots(CSG_Runtime.wornProvided(player), ISHotbarAttachDefinition)
        self.availableSlot = {}
        for i, s in ipairs(slots) do self.availableSlot[i] = { slotType = s.type, name = s.name, def = s.def } end
    end
    function hotbar:getThisSlotIndex(slotType) for i, v in pairs(self.availableSlot) do if v.slotType == slotType then return i end end end
    function hotbar:removeItem(item) end
    function hotbar:attachItem(item, slot, slotIndex, slotDef) table.insert(self.attached, { item = item, slot = slot, slotIndex = slotIndex, slotType = slotDef.type }) end
    return hotbar
end

--- Fake player with worn items.
function Stubs.player(worn)
    local player = { inventory = {}, attachedRaw = {}, worn = worn }
    player.hotbar = Stubs.hotbar(player)
    function player:getPlayerNum() return 0 end
    function player:getHoursSurvived() return 0 end
    function player:getWornItems() return Stubs.wornItems(self.worn) end
    function player:getInventory() return { AddItem = function(_, t) local i = Stubs.item(t); table.insert(player.inventory, i); return i end } end
    function player:setPrimaryHandItem(i) self.primary = i end
    function player:setSecondaryHandItem(i) self.secondary = i end
    function player:setAttachedItem(model, item) table.insert(self.attachedRaw, { model = model, item = item }) end
    return player
end
function getPlayerHotbar(num) return Stubs.currentPlayer and Stubs.currentPlayer.hotbar end

--- Body-location helpers: locations are plain strings in the stubs.
ItemBodyLocation = { get = function(x) return x end }
ResourceLocation = { of = function(x) return x end }

--- Fake SurvivorDesc over a mutable worn list of { item, location }.
function Stubs.desc(worn)
    local desc = { worn = worn }
    function desc:getWornItems() return Stubs.wornItems(self.worn) end
    function desc:isFemale() return false end
    function desc:getWornItem(location)
        for _, w in ipairs(self.worn) do if w.location == location then return w.item end end
        return nil
    end
    function desc:setWornItem(location, item)
        for i, w in ipairs(self.worn) do
            if w.location == location then
                if item then w.item = item else table.remove(self.worn, i) end
                return
            end
        end
        if item then table.insert(self.worn, { item = item, location = location }) end
    end
    return desc
end

--- IsoSurvivor.new builds a preview character sharing the desc's worn list.
IsoSurvivor = { new = function(desc) local p = Stubs.player(desc.worn); p.resets = 0; function p:resetModelNextFrame() self.resets = self.resets + 1 end; return p end }

--- Fake CharacterCreationMain and MainScreen.
CharacterCreationMain = Element:derive("CharacterCreationMain")
function CharacterCreationMain:arrangeClothingUI() self.arranged = (self.arranged or 0) + 1 end
function CharacterCreationMain:removeAllClothingWidgets() self.removed = (self.removed or 0) + 1 end
function CharacterCreationMain:onOptionMouseDown(button) self.lastOption = button.internal end
function CharacterCreationMain:updateSelectedClothingCombo() self.synced = (self.synced or 0) + 1 end
function Stubs.screen(worn)
    local screen = CharacterCreationMain:new(0, 0, 800, 600)
    screen.clothingPanel = ISPanel:new(0, 0, 500, 400)
    screen.clothingRect = ISRect:new(0, 0, 480, 1)
    screen.clothingCombo = {}
    screen.yOffset = 200
    screen.labelRight = 100
    screen.avatarPanel = CharacterCreationAvatar:new(0, 0, 128, 260)
    screen.avatarPanel.avatarPanel = { setSurvivorDesc = function(m, d) m.lastDesc = d; m.lastCharacter = nil end, setCharacter = function(m, c) m.lastCharacter = c end }
    MainScreen = { instance = { desc = Stubs.desc(worn), avatar = {} } }
    return screen
end

--- require() that maps mod paths onto the repo and ignores vanilla paths.
local root = Stubs.root or "."
local loaded = {}
function require(path)
    if loaded[path] then return loaded[path] end
    local file
    if path:match("^ChooseStartingGear/") then
        local name = path:gsub("^ChooseStartingGear/", "")
        local shared = root .. "/mod/ChooseStartingGear/42/media/lua/shared/ChooseStartingGear/" .. name .. ".lua"
        local client = root .. "/mod/ChooseStartingGear/42/media/lua/client/ChooseStartingGear/" .. name .. ".lua"
        file = io.open(shared) and shared or client
    end
    loaded[path] = true
    if file then loaded[path] = dofile(file) or true end
    return loaded[path]
end

return Stubs
