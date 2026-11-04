--- A window for choosing what goes in each worn bag: pick a bag, filter the
--- item catalog by category and text, add any number of an item, and adjust
--- or remove what is already in the bag. Sized to most of the screen with
--- medium fonts and item icons so it is easy to read and click.
require "ISUI/ISCollapsableWindow"
require "ISUI/ISLabel"
require "ISUI/ISButton"
require "ISUI/ISComboBox"
require "ISUI/ISTextEntryBox"
require "ISUI/ISScrollingListBox"
require "ChooseStartingGear/state"

local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local PAD = 12
local BUTTON_HGT = FONT_HGT_MEDIUM + 10
local ROW_HGT = FONT_HGT_MEDIUM + 12
local ICON = ROW_HGT - 8
local ALL = "__all__"

CSG_BagContentsDialog = ISCollapsableWindow:derive("CSG_BagContentsDialog")

--- Returns the window size for the current screen.
local function windowSize()
    local w = math.min(1200, getCore():getScreenWidth() - 80)
    local h = math.min(820, getCore():getScreenHeight() - 80)
    return w, h
end

--- Opens (or re-shows) the single dialog for the given bags, selecting `key`.
--- `onChanged(target)` is called after every change to the selection.
function CSG_BagContentsDialog.open(bags, key, target, onChanged)
    local dialog = CSG_BagContentsDialog.instance
    if not dialog then
        local w, h = windowSize()
        local x = math.max(0, (getCore():getScreenWidth() - w) / 2)
        local y = math.max(0, (getCore():getScreenHeight() - h) / 2)
        dialog = CSG_BagContentsDialog:new(x, y, w, h)
        dialog:initialise()
        dialog:addToUIManager()
        CSG_BagContentsDialog.instance = dialog
    end
    dialog.target = target
    dialog.onChanged = onChanged
    dialog:setBags(bags, key)
    dialog:setVisible(true)
    dialog:bringToTop()
    return dialog
end

--- Creates the window.
function CSG_BagContentsDialog:new(x, y, width, height)
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o:setTitle(getText("UI_CSG_BagDialogTitle"))
    o.bags = {}
    o.bagKey = nil
    return o
end

--- Adds a medium-font label and returns it.
function CSG_BagContentsDialog:makeLabel(x, y, text)
    local label = ISLabel:new(x, y, BUTTON_HGT, text, 1, 1, 1, 1, UIFont.Medium, true)
    label:initialise()
    self:addChild(label)
    return label
end

--- Adds a button sized to its title and returns it.
function CSG_BagContentsDialog:makeButton(x, y, title, onClick, arg)
    local width = getTextManager():MeasureStringX(UIFont.Medium, title) + 24
    local button = ISButton:new(x, y, width, BUTTON_HGT, title, self)
    button.font = UIFont.Medium
    button:setOnClick(onClick, arg)
    button:initialise()
    button:instantiate()
    self:addChild(button)
    return button
end

--- Adds a scrolling list with medium rows and a custom row drawer.
function CSG_BagContentsDialog:makeList(x, y, w, h, drawRow)
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

--- Builds the bag chooser, the catalog column and the contents column.
function CSG_BagContentsDialog:createChildren()
    ISCollapsableWindow.createChildren(self)
    self:setResizable(false)
    local top = self:titleBarHeight() + PAD
    local colW = (self.width - PAD * 3) / 2
    local leftX = PAD
    local rightX = PAD * 2 + colW

    self.bagLabel = self:makeLabel(leftX, top, getText("UI_CSG_Bag"))
    self.bagCombo = ISComboBox:new(self.bagLabel:getRight() + PAD, top, colW - self.bagLabel:getWidth() - PAD, BUTTON_HGT, self, CSG_BagContentsDialog.onBagChanged)
    self.bagCombo.font = UIFont.Medium
    self.bagCombo:initialise()
    self:addChild(self.bagCombo)
    self.weightLabel = self:makeLabel(rightX, top, "")
    top = top + BUTTON_HGT + PAD

    self:makeLabel(leftX, top, getText("UI_CSG_AllItems"))
    self:makeLabel(rightX, top, getText("UI_CSG_InThisBag"))
    top = top + BUTTON_HGT + 4

    self.categoryCombo = ISComboBox:new(leftX, top, colW * 0.42, BUTTON_HGT, self, CSG_BagContentsDialog.onFilterChanged)
    self.categoryCombo.font = UIFont.Medium
    self.categoryCombo:initialise()
    self.categoryCombo:addOptionWithData(getText("UI_CSG_AllCategories"), ALL)
    for _, category in ipairs(CSG_Catalog.categories(CSG_State.entries or {})) do
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
    self.searchEntry:setTooltip(getText("UI_CSG_SearchTip"))
    self.searchEntry.onTextChange = function() owner:onFilterChanged() end
    self:addChild(self.searchEntry)

    local bottomRowY = self.height - PAD - BUTTON_HGT
    local listTop = top + BUTTON_HGT + 6
    local actionRows = 2
    local listH = bottomRowY - PAD - (BUTTON_HGT + 6) * actionRows - listTop

    self.catalogList = self:makeList(leftX, listTop, colW, listH, CSG_BagContentsDialog.drawCatalogRow)
    self.catalogList:setOnMouseDownFunction(self, CSG_BagContentsDialog.onCatalogClicked)
    self.catalogList:setOnMouseDoubleClick(self, CSG_BagContentsDialog.onCatalogDoubleClick)
    self.contentsList = self:makeList(rightX, listTop, colW, listH, CSG_BagContentsDialog.drawContentsRow)

    local row1 = listTop + listH + 6
    local row2 = row1 + BUTTON_HGT + 6
    self.selectedLabel = self:makeLabel(leftX, row1, getText("UI_CSG_Selected") .. " " .. getText("UI_CSG_NothingSelected"))
    self.qtyLabel = self:makeLabel(leftX, row2, getText("UI_CSG_Quantity"))
    self.qtyEntry = ISTextEntryBox:new("1", self.qtyLabel:getRight() + PAD, row2, 64, BUTTON_HGT)
    self.qtyEntry.font = UIFont.Medium
    self.qtyEntry:initialise()
    self.qtyEntry:instantiate()
    self.qtyEntry:setOnlyNumbers(true)
    self:addChild(self.qtyEntry)
    self.addButton = self:makeButton(self.qtyEntry:getRight() + PAD, row2, getText("UI_CSG_AddToBag"), CSG_BagContentsDialog.onAddClicked)
    self.add1Button = self:makeButton(self.addButton:getRight() + PAD, row2, "+1", CSG_BagContentsDialog.onQuickAdd, 1)
    self.add5Button = self:makeButton(self.add1Button:getRight() + 4, row2, "+5", CSG_BagContentsDialog.onQuickAdd, 5)
    self.add25Button = self:makeButton(self.add5Button:getRight() + 4, row2, "+25", CSG_BagContentsDialog.onQuickAdd, 25)

    self.minusButton = self:makeButton(rightX, row1, "-1", CSG_BagContentsDialog.onAdjustClicked, -1)
    self.plusButton = self:makeButton(self.minusButton:getRight() + 4, row1, "+1", CSG_BagContentsDialog.onAdjustClicked, 1)
    self.plus5Button = self:makeButton(self.plusButton:getRight() + 4, row1, "+5", CSG_BagContentsDialog.onAdjustClicked, 5)
    self.removeButton = self:makeButton(self.plus5Button:getRight() + PAD, row1, getText("UI_CSG_Remove"), CSG_BagContentsDialog.onRemoveClicked)
    self.emptyButton = self:makeButton(rightX, row2, getText("UI_CSG_EmptyBag"), CSG_BagContentsDialog.onEmptyClicked)

    self.doneButton = self:makeButton(0, bottomRowY, getText("UI_CSG_Done"), CSG_BagContentsDialog.onDoneClicked)
    self.doneButton:setX(self.width - PAD - self.doneButton:getWidth())

    self:refreshCatalog()
end

--- Replaces the list of bags and selects one by key.
function CSG_BagContentsDialog:setBags(bags, key)
    self.bags = bags or {}
    self.bagCombo:clear()
    for _, bag in ipairs(self.bags) do
        local name = bag.name
        if bag.locationName then
            name = name .. " (" .. bag.locationName .. ")"
        end
        self.bagCombo:addOptionWithData(name, bag.key)
    end
    self.bagKey = nil
    for _, bag in ipairs(self.bags) do
        if bag.key == key then
            self.bagKey = key
        end
    end
    if not self.bagKey and self.bags[1] then
        self.bagKey = self.bags[1].key
    end
    if self.bagKey then
        self.bagCombo:selectData(self.bagKey)
    end
    self:refreshContents()
end

--- Returns the bag record currently selected, or nil.
function CSG_BagContentsDialog:currentBag()
    for _, bag in ipairs(self.bags) do
        if bag.key == self.bagKey then
            return bag
        end
    end
    return nil
end

--- Switches to the bag chosen in the combo.
function CSG_BagContentsDialog:onBagChanged(combo)
    self.bagKey = combo:getOptionData(combo.selected)
    self:refreshContents()
end

--- Re-runs the catalog filter.
function CSG_BagContentsDialog:onFilterChanged()
    self:refreshCatalog()
end

--- Fills the catalog list from the category and search text.
function CSG_BagContentsDialog:refreshCatalog()
    local category = self.categoryCombo:getOptionData(self.categoryCombo.selected)
    if category == ALL then
        category = nil
    end
    local query = self.searchEntry:getInternalText() or ""
    self.catalogList:clear()
    for _, entry in ipairs(CSG_Catalog.filter(CSG_State.entries or {}, query, category)) do
        self.catalogList:addItem(entry.label, entry)
    end
    self:updateSelectedLabel()
end

--- Fills the contents list and weight label for the current bag.
function CSG_BagContentsDialog:refreshContents()
    self.contentsList:clear()
    local bag = self:currentBag()
    if not bag then
        self.weightLabel:setName("")
        return
    end
    for _, stack in ipairs(CSG_Selection.containerItems(CSG_State.selection, bag.key)) do
        local entry = CSG_State.entry(stack.fullType)
        self.contentsList:addItem(tostring(stack.count) .. "x " .. (entry and entry.label or stack.fullType), { stack = stack, entry = entry })
    end
    local weight = CSG_Selection.containerWeight(CSG_State.selection, bag.key, CSG_State.weightOf)
    self.weightLabel:setName(getText("UI_CSG_Weight") .. " " .. string.format("%.1f", weight) .. " / " .. tostring(bag.capacity))
    if weight > bag.capacity then
        self.weightLabel.r, self.weightLabel.g, self.weightLabel.b = 1, 0.45, 0.45
    else
        self.weightLabel.r, self.weightLabel.g, self.weightLabel.b = 1, 1, 1
    end
end

--- Returns the highlighted catalog entry, or nil.
function CSG_BagContentsDialog:selectedEntry()
    local row = self.catalogList.items[self.catalogList.selected]
    return row and row.item or nil
end

--- Shows which catalog item is highlighted.
function CSG_BagContentsDialog:updateSelectedLabel()
    local entry = self:selectedEntry()
    self.selectedLabel:setName(getText("UI_CSG_Selected") .. " " .. (entry and entry.label or getText("UI_CSG_NothingSelected")))
end

--- Returns the quantity typed in the box, at least 1.
function CSG_BagContentsDialog:quantity()
    local n = tonumber(self.qtyEntry:getInternalText() or "") or 1
    if n < 1 then
        n = 1
    end
    return math.floor(n)
end

--- Records a change, then tells the owner so the main panel can redraw.
function CSG_BagContentsDialog:changed()
    CSG_State.save()
    self:refreshContents()
    if self.onChanged then
        self.onChanged(self.target)
    end
end

--- Adds n of an entry to the current bag.
function CSG_BagContentsDialog:addEntry(entry, n)
    if not entry or not self.bagKey then
        return
    end
    CSG_Selection.addToContainer(CSG_State.selection, self.bagKey, entry.fullType, n)
    self:changed()
end

--- Clicking a catalog row highlights it.
function CSG_BagContentsDialog:onCatalogClicked(entry)
    self:updateSelectedLabel()
end

--- Double-clicking a catalog row adds the typed quantity.
function CSG_BagContentsDialog:onCatalogDoubleClick(entry)
    self:addEntry(entry, self:quantity())
end

--- Add button: adds the typed quantity of the highlighted row.
function CSG_BagContentsDialog:onAddClicked()
    self:addEntry(self:selectedEntry(), self:quantity())
end

--- +1 / +5 / +25 buttons on the catalog side.
function CSG_BagContentsDialog:onQuickAdd(button, n)
    self:addEntry(self:selectedEntry(), n)
end

--- Returns the highlighted contents row's stack, or nil.
function CSG_BagContentsDialog:selectedStack()
    local row = self.contentsList.items[self.contentsList.selected]
    return row and row.item and row.item.stack
end

--- -1 / +1 / +5 on the highlighted stack.
function CSG_BagContentsDialog:onAdjustClicked(button, delta)
    local stack = self:selectedStack()
    if not stack then
        return
    end
    if delta > 0 then
        CSG_Selection.addToContainer(CSG_State.selection, self.bagKey, stack.fullType, delta)
    else
        CSG_Selection.removeFromContainer(CSG_State.selection, self.bagKey, stack.fullType, -delta)
    end
    self:changed()
end

--- Removes the highlighted stack entirely.
function CSG_BagContentsDialog:onRemoveClicked()
    local stack = self:selectedStack()
    if not stack then
        return
    end
    CSG_Selection.removeFromContainer(CSG_State.selection, self.bagKey, stack.fullType, stack.count)
    self:changed()
end

--- Empties the current bag.
function CSG_BagContentsDialog:onEmptyClicked()
    if self.bagKey then
        CSG_Selection.clearContainer(CSG_State.selection, self.bagKey)
        self:changed()
    end
end

--- Hides the window.
function CSG_BagContentsDialog:onDoneClicked()
    self:setVisible(false)
end

--- The title-bar close button hides rather than destroys the window.
function CSG_BagContentsDialog:close()
    self:setVisible(false)
end

--- Draws the shared row background and returns false when the row is off-screen.
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

--- Draws an item icon at the left of a row when the item has one.
local function drawIcon(list, icon, y)
    if icon then
        list:drawTextureScaledAspect(icon, 6, y + 4, ICON, ICON, 1, 1, 1, 1)
    end
end

--- Draws one catalog row: icon, name, category and weight.
function CSG_BagContentsDialog.drawCatalogRow(list, y, item, alt)
    if not beginRow(list, y, item) then
        return y + item.height
    end
    local entry = item.item
    local textY = y + 6
    drawIcon(list, entry.icon, y)
    list:drawText(entry.label, ICON + 14, textY, 1, 1, 1, 1, list.font)
    local category = getTextOrNull("IGUI_ItemCat_" .. tostring(entry.category)) or tostring(entry.category)
    list:drawText(category, math.floor(list:getWidth() * 0.62), textY, 0.6, 0.6, 0.8, 1, list.font)
    list:drawText(string.format("%.1f", entry.weight or 0), list:getWidth() - 52, textY, 0.8, 0.8, 0.8, 1, list.font)
    return y + item.height
end

--- Draws one contents row: icon, count and name, total weight on the right.
function CSG_BagContentsDialog.drawContentsRow(list, y, item, alt)
    if not beginRow(list, y, item) then
        return y + item.height
    end
    local textY = y + 6
    drawIcon(list, item.item.entry and item.item.entry.icon, y)
    list:drawText(item.text, ICON + 14, textY, 1, 1, 1, 1, list.font)
    local weight = (item.item.entry and item.item.entry.weight or 0) * item.item.stack.count
    list:drawText(string.format("%.1f", weight), list:getWidth() - 52, textY, 0.8, 0.8, 0.8, 1, list.font)
    return y + item.height
end
