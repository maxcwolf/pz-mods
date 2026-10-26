--- A window for choosing what goes in each worn bag: pick a bag, filter the
--- item catalog by category and text, add any number of an item, and adjust
--- or remove what is already in the bag.
require "ISUI/ISCollapsableWindow"
require "ISUI/ISLabel"
require "ISUI/ISButton"
require "ISUI/ISComboBox"
require "ISUI/ISTextEntryBox"
require "ISUI/ISScrollingListBox"
require "ChooseStartingGear/state"

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local PAD = 10
local BUTTON_HGT = FONT_HGT_SMALL + 6
local ROW_HGT = FONT_HGT_SMALL + 6
local WINDOW_W = 820
local WINDOW_H = 540
local ALL = "__all__"

CSG_BagContentsDialog = ISCollapsableWindow:derive("CSG_BagContentsDialog")

--- Opens (or re-shows) the single dialog for the given bags, selecting `key`.
--- `onChanged(target)` is called after every change to the selection.
function CSG_BagContentsDialog.open(bags, key, target, onChanged)
    local dialog = CSG_BagContentsDialog.instance
    if not dialog then
        local x = math.max(0, (getCore():getScreenWidth() - WINDOW_W) / 2)
        local y = math.max(0, (getCore():getScreenHeight() - WINDOW_H) / 2)
        dialog = CSG_BagContentsDialog:new(x, y, WINDOW_W, WINDOW_H)
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
    o.category = nil
    return o
end

--- Builds the bag chooser, the catalog column and the contents column.
function CSG_BagContentsDialog:createChildren()
    ISCollapsableWindow.createChildren(self)
    self:setResizable(false)
    local top = self:titleBarHeight() + PAD
    local colW = (self.width - PAD * 3) / 2
    local leftX = PAD
    local rightX = PAD * 2 + colW

    self.bagLabel = ISLabel:new(leftX, top, BUTTON_HGT, getText("UI_CSG_Bag"), 1, 1, 1, 1, UIFont.Small, true)
    self.bagLabel:initialise()
    self:addChild(self.bagLabel)
    self.bagCombo = ISComboBox:new(self.bagLabel:getRight() + PAD, top, colW - self.bagLabel:getWidth() - PAD, BUTTON_HGT, self, CSG_BagContentsDialog.onBagChanged)
    self.bagCombo:initialise()
    self:addChild(self.bagCombo)
    self.weightLabel = ISLabel:new(rightX, top, BUTTON_HGT, "", 1, 1, 1, 1, UIFont.Small, true)
    self.weightLabel:initialise()
    self:addChild(self.weightLabel)
    top = top + BUTTON_HGT + PAD

    local catalogTitle = ISLabel:new(leftX, top, BUTTON_HGT, getText("UI_CSG_AllItems"), 1, 1, 1, 1, UIFont.Small, true)
    catalogTitle:initialise()
    self:addChild(catalogTitle)
    local contentsTitle = ISLabel:new(rightX, top, BUTTON_HGT, getText("UI_CSG_InThisBag"), 1, 1, 1, 1, UIFont.Small, true)
    contentsTitle:initialise()
    self:addChild(contentsTitle)
    top = top + BUTTON_HGT + 4

    self.categoryCombo = ISComboBox:new(leftX, top, colW * 0.45, BUTTON_HGT, self, CSG_BagContentsDialog.onFilterChanged)
    self.categoryCombo:initialise()
    self.categoryCombo:addOptionWithData(getText("UI_CSG_AllCategories"), ALL)
    for _, category in ipairs(CSG_Catalog.categories(CSG_State.entries or {})) do
        self.categoryCombo:addOptionWithData(getTextOrNull("IGUI_ItemCat_" .. category) or category, category)
    end
    self.categoryCombo.selected = 1
    self:addChild(self.categoryCombo)

    local owner = self
    self.searchEntry = ISTextEntryBox:new("", self.categoryCombo:getRight() + PAD, top, colW - self.categoryCombo:getWidth() - PAD, BUTTON_HGT)
    self.searchEntry:initialise()
    self.searchEntry:instantiate()
    self.searchEntry:setClearButton(true)
    self.searchEntry:setTooltip(getText("UI_CSG_SearchTip"))
    self.searchEntry.onTextChange = function() owner:onFilterChanged() end
    self:addChild(self.searchEntry)

    local bottomRowY = self.height - PAD - BUTTON_HGT
    local listTop = top + BUTTON_HGT + 4
    local listH = bottomRowY - PAD - BUTTON_HGT - listTop

    self.catalogList = ISScrollingListBox:new(leftX, listTop, colW, listH)
    self.catalogList:initialise()
    self.catalogList:instantiate()
    self.catalogList:setFont(UIFont.Small, 3)
    self.catalogList.itemheight = ROW_HGT
    self.catalogList.drawBorder = true
    self.catalogList.doDrawItem = CSG_BagContentsDialog.drawCatalogRow
    self.catalogList:setOnMouseDoubleClick(self, CSG_BagContentsDialog.onCatalogDoubleClick)
    self:addChild(self.catalogList)

    self.contentsList = ISScrollingListBox:new(rightX, listTop, colW, listH)
    self.contentsList:initialise()
    self.contentsList:instantiate()
    self.contentsList:setFont(UIFont.Small, 3)
    self.contentsList.itemheight = ROW_HGT
    self.contentsList.drawBorder = true
    self.contentsList.doDrawItem = CSG_BagContentsDialog.drawContentsRow
    self:addChild(self.contentsList)

    local actionY = listTop + listH + PAD
    self.qtyLabel = ISLabel:new(leftX, actionY, BUTTON_HGT, getText("UI_CSG_Quantity"), 1, 1, 1, 1, UIFont.Small, true)
    self.qtyLabel:initialise()
    self:addChild(self.qtyLabel)
    self.qtyEntry = ISTextEntryBox:new("1", self.qtyLabel:getRight() + PAD, actionY, 50, BUTTON_HGT)
    self.qtyEntry:initialise()
    self.qtyEntry:instantiate()
    self.qtyEntry:setOnlyNumbers(true)
    self:addChild(self.qtyEntry)
    self.addButton = self:makeButton(self.qtyEntry:getRight() + PAD, actionY, getText("UI_CSG_AddToBag"), CSG_BagContentsDialog.onAddClicked)

    self.minusButton = self:makeButton(rightX, actionY, "-1", CSG_BagContentsDialog.onAdjustClicked, -1)
    self.plusButton = self:makeButton(self.minusButton:getRight() + 4, actionY, "+1", CSG_BagContentsDialog.onAdjustClicked, 1)
    self.removeButton = self:makeButton(self.plusButton:getRight() + 4, actionY, getText("UI_CSG_Remove"), CSG_BagContentsDialog.onRemoveClicked)
    self.emptyButton = self:makeButton(self.removeButton:getRight() + 4, actionY, getText("UI_CSG_EmptyBag"), CSG_BagContentsDialog.onEmptyClicked)

    self.doneButton = self:makeButton(0, bottomRowY, getText("UI_CSG_Done"), CSG_BagContentsDialog.onDoneClicked)
    self.doneButton:setX(self.width - PAD - self.doneButton:getWidth())

    self:refreshCatalog()
end

--- Adds a button sized to its title and returns it.
function CSG_BagContentsDialog:makeButton(x, y, title, onClick, arg)
    local width = getTextManager():MeasureStringX(UIFont.Small, title) + 20
    local button = ISButton:new(x, y, width, BUTTON_HGT, title, self)
    button:setOnClick(onClick, arg)
    button:initialise()
    button:instantiate()
    self:addChild(button)
    return button
end

--- Replaces the list of bags and selects one by key.
function CSG_BagContentsDialog:setBags(bags, key)
    self.bags = bags or {}
    self.bagCombo:clear()
    for _, bag in ipairs(self.bags) do
        local name = bag.name
        if bag.locationName then
            name = name .. " - " .. bag.locationName
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

--- Adds the quantity of the selected catalog item to the current bag.
function CSG_BagContentsDialog:addSelected(entry)
    if not entry or not self.bagKey then
        return
    end
    CSG_Selection.addToContainer(CSG_State.selection, self.bagKey, entry.fullType, self:quantity())
    self:changed()
end

--- Add button: uses the highlighted catalog row.
function CSG_BagContentsDialog:onAddClicked()
    local row = self.catalogList.items[self.catalogList.selected]
    self:addSelected(row and row.item)
end

--- Double-clicking a catalog row adds it too.
function CSG_BagContentsDialog:onCatalogDoubleClick(entry)
    self:addSelected(entry)
end

--- Returns the highlighted contents row's stack, or nil.
function CSG_BagContentsDialog:selectedStack()
    local row = self.contentsList.items[self.contentsList.selected]
    return row and row.item and row.item.stack
end

--- -1 / +1 on the highlighted stack.
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

--- Draws one catalog row: name, category and weight in columns.
function CSG_BagContentsDialog.drawCatalogRow(list, y, item, alt)
    if y + list:getYScroll() + item.height < 0 or y + list:getYScroll() >= list.height then
        return y + item.height
    end
    if list.selected == item.index then
        list:drawRect(0, y, list:getWidth(), item.height - 1, 0.3, 0.7, 0.35, 0.15)
    elseif list.mouseoverselected == item.index and list:isMouseOver() then
        list:drawRect(0, y, list:getWidth(), item.height - 1, 0.1, 0.9, 0.9, 0.9)
    end
    list:drawRectBorder(0, y, list:getWidth(), item.height, 0.3, list.borderColor.r, list.borderColor.g, list.borderColor.b)
    local entry = item.item
    local textY = y + 3
    list:drawText(entry.label, 8, textY, 1, 1, 1, 1, list.font)
    local category = getTextOrNull("IGUI_ItemCat_" .. tostring(entry.category)) or tostring(entry.category)
    list:drawText(category, math.floor(list:getWidth() * 0.6), textY, 0.6, 0.6, 0.8, 1, list.font)
    list:drawText(string.format("%.1f", entry.weight or 0), list:getWidth() - 44, textY, 0.8, 0.8, 0.8, 1, list.font)
    return y + item.height
end

--- Draws one contents row: count and name, weight on the right.
function CSG_BagContentsDialog.drawContentsRow(list, y, item, alt)
    if y + list:getYScroll() + item.height < 0 or y + list:getYScroll() >= list.height then
        return y + item.height
    end
    if list.selected == item.index then
        list:drawRect(0, y, list:getWidth(), item.height - 1, 0.3, 0.7, 0.35, 0.15)
    elseif list.mouseoverselected == item.index and list:isMouseOver() then
        list:drawRect(0, y, list:getWidth(), item.height - 1, 0.1, 0.9, 0.9, 0.9)
    end
    list:drawRectBorder(0, y, list:getWidth(), item.height, 0.3, list.borderColor.r, list.borderColor.g, list.borderColor.b)
    local textY = y + 3
    list:drawText(item.text, 8, textY, 1, 1, 1, 1, list.font)
    local weight = (item.item.entry and item.item.entry.weight or 0) * item.item.stack.count
    list:drawText(string.format("%.1f", weight), list:getWidth() - 44, textY, 0.8, 0.8, 0.8, 1, list.font)
    return y + item.height
end
