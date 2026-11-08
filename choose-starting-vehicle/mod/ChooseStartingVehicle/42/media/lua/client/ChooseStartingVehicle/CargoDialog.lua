--- The cargo editor: pick what goes in the trunk, the glove box or the
--- trailer. Left column filters every item by category and name; right column
--- lists what is packed, with quantity buttons. Edits a stack list in place.
require "ISUI/ISCollapsableWindow"
require "ISUI/ISLabel"
require "ISUI/ISButton"
require "ISUI/ISComboBox"
require "ISUI/ISTextEntryBox"
require "ISUI/ISScrollingListBox"
local Items = require("ChooseStartingVehicle/items")
local Build = require("ChooseStartingVehicle/build")

local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local PAD = 12
local BUTTON_HGT = FONT_HGT_MEDIUM + 10
local ROW_HGT = FONT_HGT_MEDIUM + 12
local ICON = ROW_HGT - 8
local ALL = "__all__"
local MAX_RESULTS = 500

CSV_CargoDialog = ISCollapsableWindow:derive("CSV_CargoDialog")

local itemEntries = nil
local itemByType = nil

--- Reads every item script once into the searchable list.
function CSV_CargoDialog.entries()
    if itemEntries then
        return itemEntries
    end
    local raws = {}
    local all = getScriptManager():getAllItems()
    for i = 0, all:size() - 1 do
        local script = all:get(i)
        raws[#raws + 1] = {
            fullType = script:getFullName(),
            displayName = script:getDisplayName(),
            hidden = script:isHidden(),
            obsolete = script:getObsolete(),
            weight = script:getActualWeight(),
            category = script:getDisplayCategory(),
            icon = script:getNormalTexture(),
        }
    end
    itemEntries = Items.buildEntries(raws)
    itemByType = {}
    for _, entry in ipairs(itemEntries) do
        itemByType[entry.fullType] = entry
    end
    return itemEntries
end

--- Returns the entry for a full type, or nil.
function CSV_CargoDialog.entry(fullType)
    CSV_CargoDialog.entries()
    return itemByType[fullType]
end

--- Returns the window size for the current screen.
local function windowSize()
    return math.min(1100, getCore():getScreenWidth() - 80), math.min(760, getCore():getScreenHeight() - 80)
end

--- Opens the single cargo window on `stacks` (edited in place) with a title.
--- `onChanged()` runs after every change.
function CSV_CargoDialog.open(title, stacks, onChanged)
    local dialog = CSV_CargoDialog.instance
    if not dialog then
        local w, h = windowSize()
        dialog = CSV_CargoDialog:new((getCore():getScreenWidth() - w) / 2, (getCore():getScreenHeight() - h) / 2, w, h)
        dialog:initialise()
        dialog:addToUIManager()
        CSV_CargoDialog.instance = dialog
    end
    dialog:setTitle(title)
    dialog.stacks = stacks
    dialog.onChanged = onChanged
    dialog:refreshContents()
    dialog:setVisible(true)
    dialog:bringToTop()
    return dialog
end

--- Creates the window.
function CSV_CargoDialog:new(x, y, width, height)
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o.stacks = {}
    return o
end

--- Adds a medium label.
function CSV_CargoDialog:makeLabel(x, y, text)
    local label = ISLabel:new(x, y, BUTTON_HGT, text, 1, 1, 1, 1, UIFont.Medium, true)
    label:initialise()
    self:addChild(label)
    return label
end

--- Adds a button sized to its title.
function CSV_CargoDialog:makeButton(x, y, title, onClick, arg)
    local width = getTextManager():MeasureStringX(UIFont.Medium, title) + 24
    local button = ISButton:new(x, y, width, BUTTON_HGT, title, self)
    button.font = UIFont.Medium
    button:setOnClick(onClick, arg)
    button:initialise()
    button:instantiate()
    self:addChild(button)
    return button
end

--- Adds a scrolling list with a custom row drawer.
function CSV_CargoDialog:makeList(x, y, w, h, drawRow)
    local list = ISScrollingListBox:new(x, y, w, h)
    list:initialise()
    list:instantiate()
    list:setFont(UIFont.Medium, 5)
    list.itemheight = ROW_HGT
    list.drawBorder = true
    list.doDrawItem = drawRow
    self:addChild(list)
    return list
end

--- Builds both columns.
function CSV_CargoDialog:createChildren()
    ISCollapsableWindow.createChildren(self)
    self:setResizable(false)
    local top = self:titleBarHeight() + PAD
    local colW = (self.width - PAD * 3) / 2
    local leftX, rightX = PAD, PAD * 2 + colW

    self:makeLabel(leftX, top, getText("UI_CSV_AllItems"))
    self.weightLabel = self:makeLabel(rightX, top, "")
    top = top + BUTTON_HGT + 4

    self.categoryCombo = ISComboBox:new(leftX, top, colW * 0.42, BUTTON_HGT, self, CSV_CargoDialog.refreshCatalog)
    self.categoryCombo.font = UIFont.Medium
    self.categoryCombo:initialise()
    self.categoryCombo:addOptionWithData(getText("UI_CSV_AllCategories"), ALL)
    for _, category in ipairs(Items.categories(CSV_CargoDialog.entries())) do
        self.categoryCombo:addOptionWithData(getTextOrNull("IGUI_ItemCat_" .. category) or category, category)
    end
    self.categoryCombo.selected = 1
    self:addChild(self.categoryCombo)

    local owner = self
    self.searchEntry = ISTextEntryBox:new("", self.categoryCombo:getRight() + PAD, top, colW - self.categoryCombo:getWidth() - PAD, BUTTON_HGT)
    self.searchEntry.font = UIFont.Medium
    self.searchEntry:initialise()
    self.searchEntry:instantiate()
    self.searchEntry:setClearButton(true)
    self.searchEntry.onTextChange = function() owner:refreshCatalog() end
    self:addChild(self.searchEntry)

    local bottomY = self.height - PAD - BUTTON_HGT
    local listTop = top + BUTTON_HGT + 6
    local listH = bottomY - PAD - (BUTTON_HGT + 6) - listTop
    self.catalogList = self:makeList(leftX, listTop, colW, listH, CSV_CargoDialog.drawCatalogRow)
    self.catalogList:setOnMouseDoubleClick(self, CSV_CargoDialog.onCatalogDoubleClick)
    self.contentsList = self:makeList(rightX, listTop, colW, listH, CSV_CargoDialog.drawContentsRow)

    local row = listTop + listH + 6
    self.qtyLabel = self:makeLabel(leftX, row, getText("UI_CSV_Quantity"))
    self.qtyEntry = ISTextEntryBox:new("1", self.qtyLabel:getRight() + PAD, row, 64, BUTTON_HGT)
    self.qtyEntry.font = UIFont.Medium
    self.qtyEntry:initialise()
    self.qtyEntry:instantiate()
    self.qtyEntry:setOnlyNumbers(true)
    self:addChild(self.qtyEntry)
    self.addButton = self:makeButton(self.qtyEntry:getRight() + PAD, row, getText("UI_CSV_Add"), CSV_CargoDialog.onAddClicked)

    self.minusButton = self:makeButton(rightX, row, "-1", CSV_CargoDialog.onAdjustClicked, -1)
    self.plusButton = self:makeButton(self.minusButton:getRight() + 4, row, "+1", CSV_CargoDialog.onAdjustClicked, 1)
    self.removeButton = self:makeButton(self.plusButton:getRight() + PAD, row, getText("UI_CSV_Remove"), CSV_CargoDialog.onRemoveClicked)
    self.emptyButton = self:makeButton(self.removeButton:getRight() + PAD, row, getText("UI_CSV_Empty"), CSV_CargoDialog.onEmptyClicked)

    self.doneButton = self:makeButton(0, bottomY, getText("UI_CSV_Done"), CSV_CargoDialog.close)
    self.doneButton:setX(self.width - PAD - self.doneButton:getWidth())
    self:refreshCatalog()
end

--- Refills the catalog list from the category and search text.
function CSV_CargoDialog:refreshCatalog()
    local category = self.categoryCombo:getOptionData(self.categoryCombo.selected)
    if category == ALL then
        category = nil
    end
    self.catalogList:clear()
    for _, entry in ipairs(Items.filter(CSV_CargoDialog.entries(), self.searchEntry:getInternalText(), category, MAX_RESULTS)) do
        self.catalogList:addItem(entry.label, entry)
    end
end

--- Refills the packed list and the weight total.
function CSV_CargoDialog:refreshContents()
    if not self.contentsList then
        return
    end
    local selected = self.contentsList.selected
    self.contentsList:clear()
    for _, stack in ipairs(self.stacks or {}) do
        local entry = CSV_CargoDialog.entry(stack.type)
        self.contentsList:addItem(tostring(stack.count) .. "x " .. (entry and entry.label or stack.type), { stack = stack, entry = entry })
    end
    self.contentsList.selected = math.max(1, math.min(selected or 1, #self.contentsList.items))
    local weight = Items.stackWeight(self.stacks, function(fullType)
        local entry = CSV_CargoDialog.entry(fullType)
        return entry and entry.weight or 0
    end)
    self.weightLabel:setName(getText("UI_CSV_Packed") .. " " .. string.format("%.1f", weight))
end

--- Records a change and tells the owner.
function CSV_CargoDialog:changed()
    self:refreshContents()
    if self.onChanged then
        self.onChanged()
    end
end

--- Returns the typed quantity, at least 1.
function CSV_CargoDialog:quantity()
    return math.max(1, math.floor(tonumber(self.qtyEntry:getInternalText() or "") or 1))
end

--- Adds the typed quantity of an entry.
function CSV_CargoDialog:addEntry(entry, n)
    if entry and self.stacks then
        Build.addStack(self.stacks, entry.fullType, n)
        self:changed()
    end
end

--- Double-clicking a catalog row adds it.
function CSV_CargoDialog:onCatalogDoubleClick(entry)
    self:addEntry(entry, self:quantity())
end

--- Add button: adds the highlighted catalog row.
function CSV_CargoDialog:onAddClicked()
    local row = self.catalogList.items[self.catalogList.selected]
    self:addEntry(row and row.item, self:quantity())
end

--- Returns the highlighted packed stack, or nil.
function CSV_CargoDialog:selectedStack()
    local row = self.contentsList.items[self.contentsList.selected]
    return row and row.item and row.item.stack
end

--- -1 / +1 on the highlighted stack.
function CSV_CargoDialog:onAdjustClicked(button, delta)
    local stack = self:selectedStack()
    if stack then
        Build.setStackCount(self.stacks, stack.type, stack.count + delta)
        self:changed()
    end
end

--- Removes the highlighted stack.
function CSV_CargoDialog:onRemoveClicked()
    local stack = self:selectedStack()
    if stack then
        Build.setStackCount(self.stacks, stack.type, 0)
        self:changed()
    end
end

--- Removes everything.
function CSV_CargoDialog:onEmptyClicked()
    for i = #self.stacks, 1, -1 do
        self.stacks[i] = nil
    end
    self:changed()
end

--- Hides the window.
function CSV_CargoDialog:close()
    self:setVisible(false)
end

--- Draws the row background; returns false when the row is off-screen.
local function beginRow(list, y, item)
    if y + list:getYScroll() + item.height < 0 or y + list:getYScroll() >= list.height then
        return false
    end
    if list.selected == item.index then
        list:drawRect(0, y, list:getWidth(), item.height - 1, 0.35, 0.7, 0.35, 0.15)
    elseif list.mouseoverselected == item.index and list:isMouseOver() then
        list:drawRect(0, y, list:getWidth(), item.height - 1, 0.12, 0.9, 0.9, 0.9)
    end
    list:drawRectBorder(0, y, list:getWidth(), item.height, 0.3, list.borderColor.r, list.borderColor.g, list.borderColor.b)
    return true
end

--- Draws one catalog row: icon, name, category, weight.
function CSV_CargoDialog.drawCatalogRow(list, y, item, alt)
    if beginRow(list, y, item) then
        local entry = item.item
        if entry.icon then
            list:drawTextureScaledAspect(entry.icon, 6, y + 4, ICON, ICON, 1, 1, 1, 1)
        end
        list:drawText(entry.label, ICON + 14, y + 6, 1, 1, 1, 1, list.font)
        local category = getTextOrNull("IGUI_ItemCat_" .. tostring(entry.category)) or tostring(entry.category)
        list:drawText(category, math.floor(list:getWidth() * 0.62), y + 6, 0.6, 0.6, 0.8, 1, list.font)
    end
    return y + item.height
end

--- Draws one packed row: icon, count and name.
function CSV_CargoDialog.drawContentsRow(list, y, item, alt)
    if beginRow(list, y, item) then
        local entry = item.item.entry
        if entry and entry.icon then
            list:drawTextureScaledAspect(entry.icon, 6, y + 4, ICON, ICON, 1, 1, 1, 1)
        end
        list:drawText(item.text, ICON + 14, y + 6, 1, 1, 1, 1, list.font)
    end
    return y + item.height
end
