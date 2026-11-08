--- Layout A, the default: a window with room tabs, category filters, a
--- search box and a grid of item pictures. Picking an item tucks the
--- window away into a small status chip until placing ends.
require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "ISUI/ISTextEntryBox"
require "FurnishByRoom/ItemGrid"
require "FurnishByRoom/PlacingChip"
local Rooms = require("FurnishByRoom/rooms")
local Classify = require("FurnishByRoom/classify")
local Layout = require("FurnishByRoom/layout")
local Theme = require("FurnishByRoom/theme")

FBR_CatalogWindow = ISCollapsableWindow:derive("FBR_CatalogWindow")

FBR_CatalogWindow.WIDTH = 480
FBR_CatalogWindow.PAD = 10
FBR_CatalogWindow.TAB_H = 28
FBR_CatalogWindow.CHIP_H = 22
FBR_CatalogWindow.FOOT_H = 28

--- Makes the window for a controller.
function FBR_CatalogWindow:new(controller)
    local screenH = getCore():getScreenHeight()
    local h = math.min(680, screenH - 120)
    local o = ISCollapsableWindow.new(self, 40, 80, FBR_CatalogWindow.WIDTH, h)
    o.controller = controller
    o:setTitle(getText("UI_FBR_Title"))
    o:setResizable(false)
    o.chips = {}
    return o
end

--- Creates the tabs, search box, grid and footer buttons.
function FBR_CatalogWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    local pad = FBR_CatalogWindow.PAD
    local top = self:titleBarHeight() + 30
    local tabW = math.floor((self.width - pad * 2 - 12) / 3)
    self.tabs = {}
    for i, room in ipairs(Rooms.ORDER) do
        local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
        local button = ISButton:new(pad + col * (tabW + 6), top + row * (FBR_CatalogWindow.TAB_H + 6), tabW,
            FBR_CatalogWindow.TAB_H, getText(Rooms.labelKey(room)), self, FBR_CatalogWindow.onTab)
        button.internal = room
        button:initialise()
        button:instantiate()
        self:addChild(button)
        self.tabs[room] = button
    end
    self.chipTop = top + 2 * (FBR_CatalogWindow.TAB_H + 6) + 4

    self.search = ISTextEntryBox:new("", pad, 0, self.width - pad * 2, 24)
    self.search:initialise()
    self.search:instantiate()
    self.search.target = self
    self.search.onTextChangeFunction = FBR_CatalogWindow.onSearch
    self:addChild(self.search)

    self.grid = FBR_ItemGrid:new(pad, 0, self.width - pad * 2, 100, self, FBR_CatalogWindow.onPick)
    self.grid:initialise()
    self.grid:instantiate()
    self:addChild(self.grid)

    local footY = self.height - pad - FBR_CatalogWindow.FOOT_H
    local footW = math.floor((self.width - pad * 2 - 12) / 3)
    self.removeButton = self:footButton(pad, footY, footW, "UI_FBR_Remove", FBR_CatalogWindow.onRemove)
    self.undoButton = self:footButton(pad + footW + 6, footY, footW, "UI_FBR_Undo", FBR_CatalogWindow.onUndo)
    self.layoutButton = self:footButton(pad + (footW + 6) * 2, footY, footW, "UI_FBR_UseStrip", FBR_CatalogWindow.onLayout)
end

--- Adds one footer button.
function FBR_CatalogWindow:footButton(x, y, w, key, fn)
    local button = ISButton:new(x, y, w, FBR_CatalogWindow.FOOT_H, getText(key), self, fn)
    button:initialise()
    button:instantiate()
    Theme.styleButton(button, false)
    self:addChild(button)
    return button
end

--- Rebuilds the category chips for the room and lays out the rest below
--- them.
function FBR_CatalogWindow:layoutChips()
    for _, chip in ipairs(self.chips) do
        self:removeChild(chip)
    end
    self.chips = {}
    local pad = FBR_CatalogWindow.PAD
    local browse = self.controller.browse()
    local x, y = pad, self.chipTop
    local tm = getTextManager()
    for _, cat in ipairs(self.controller.filters()) do
        local title = getText(Classify.labelKey(cat))
        local w = tm:MeasureStringX(UIFont.Small, title) + 18
        if x + w > self.width - pad then
            x = pad
            y = y + FBR_CatalogWindow.CHIP_H + 4
        end
        local chip = ISButton:new(x, y, w, FBR_CatalogWindow.CHIP_H, title, self, FBR_CatalogWindow.onChip)
        chip.internal = cat
        chip:initialise()
        chip:instantiate()
        Theme.styleButton(chip, cat == browse.cat and browse.query == "")
        self:addChild(chip)
        self.chips[#self.chips + 1] = chip
        x = x + w + 4
    end
    local searchY = y + FBR_CatalogWindow.CHIP_H + 8
    self.search:setY(searchY)
    local gridY = searchY + 24 + 8
    self.grid:setY(gridY)
    self.grid:setHeight(self.height - FBR_CatalogWindow.PAD * 2 - FBR_CatalogWindow.FOOT_H - gridY)
end

--- Redraws tabs, chips and items from the controller's state.
function FBR_CatalogWindow:refresh()
    local browse = self.controller.browse()
    for room, button in pairs(self.tabs) do
        button:setTitle(getText(Rooms.labelKey(room)) .. "  " .. tostring(self.controller.count(room)))
        Theme.styleButton(button, room == browse.room)
    end
    local roomChanged = self.shownRoom ~= browse.room or self.shownCat ~= browse.cat or self.shownQuery ~= browse.query
    self.shownRoom, self.shownCat, self.shownQuery = browse.room, browse.cat, browse.query
    self:layoutChips()
    if self.search:getInternalText() ~= browse.query then
        self.search:setText(browse.query)
    end
    self.grid:setItems(self.controller.items(), self.controller.picked, roomChanged)
    self.undoButton:setTitle(getText("UI_FBR_Undo") .. " (" .. self.controller.undoCount() .. ")")
end

--- Draws the "you're in a ..." line under the title bar.
function FBR_CatalogWindow:render()
    ISCollapsableWindow.render(self)
    local detected = self.controller.detected
    local text
    if detected then
        text = getText("UI_FBR_YouAreIn", string.lower(getText(Rooms.labelKey(detected))))
    else
        text = getText("UI_FBR_PickRoom")
    end
    local c = Theme.MUTED
    self:drawText(text, FBR_CatalogWindow.PAD, self:titleBarHeight() + 8, c.r, c.g, c.b, 1, UIFont.Small)
end

--- Switches rooms.
function FBR_CatalogWindow:onTab(button)
    self.controller.selectRoom(button.internal)
end

--- Switches category and clears the search.
function FBR_CatalogWindow:onChip(button)
    self.controller.browse().query = ""
    self.controller.selectCategory(button.internal)
end

--- Filters as the player types.
function FBR_CatalogWindow:onSearch(box)
    local text = box:getInternalText()
    if text ~= self.controller.browse().query then
        self.controller.setQuery(text)
    end
end

--- Starts placing the clicked item.
function FBR_CatalogWindow:onPick(entry)
    self.controller.pick(entry)
end

--- Starts the Remove tool.
function FBR_CatalogWindow:onRemove()
    self.controller.startRemove()
end

--- Undoes the newest change.
function FBR_CatalogWindow:onUndo()
    self.controller.undo()
end

--- Switches to the bottom strip.
function FBR_CatalogWindow:onLayout()
    self.controller.setLayout(Layout.STRIP)
end

--- The title bar's close button closes the mod.
function FBR_CatalogWindow:close()
    self.controller.close()
end

--- Takes Escape so it closes this window instead of opening the game menu.
function FBR_CatalogWindow:isKeyConsumed(key)
    return key == Keyboard.KEY_ESCAPE and self:isVisible()
end

--- Closes on Escape.
function FBR_CatalogWindow:onKeyRelease(key)
    if key == Keyboard.KEY_ESCAPE and self:isVisible() then
        self.controller.close()
    end
end

--- View: puts the window on screen.
function FBR_CatalogWindow:show()
    if not self.added then
        self:initialise()
        self:addToUIManager()
        self:setWantKeyEvents(true)
        self.added = true
    end
    if not self.controller.placing then
        self:setVisible(true)
    end
end

--- View: true while the window or its chip is on screen.
function FBR_CatalogWindow:isShown()
    return self.added == true
end

--- View: removes the window and its chip.
function FBR_CatalogWindow:dismiss()
    if self.chip then
        self.chip:dismiss()
        self.chip = nil
    end
    self:setVisible(false)
    self:removeFromUIManager()
    self.added = false
end

--- View: hides the window behind a small chip while the mouse is busy.
function FBR_CatalogWindow:onPlacingStarted(placing)
    self:setVisible(false)
    if not self.chip then
        self.chip = FBR_PlacingChip:new(self.controller)
    end
    self.chip:show(placing)
end

--- View: brings the window back when placing ends.
function FBR_CatalogWindow:onPlacingEnded()
    if self.chip then
        self.chip:dismiss()
        self.chip = nil
    end
    if self.added then
        self:setVisible(true)
        self:refresh()
    end
end

--- Makes the view for the controller.
function FBR_CatalogWindow.create(controller)
    return FBR_CatalogWindow:new(controller)
end

return FBR_CatalogWindow
