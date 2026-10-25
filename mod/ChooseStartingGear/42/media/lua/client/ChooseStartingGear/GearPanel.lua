--- The "Starting Gear" section that the mod appends under the clothing rows of
--- the character creation screen: hand items, one combo per attachment slot
--- the worn clothing provides, and the contents of every worn bag.
require "ISUI/ISPanel"
require "ISUI/ISLabel"
require "ISUI/ISButton"
require "ISUI/ISComboBox"
require "ISUI/ISRect"
require "ChooseStartingGear/state"
require "ChooseStartingGear/ItemSearch"

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local UI_BORDER_SPACING = 10
local BUTTON_HGT = FONT_HGT_SMALL + 6
local MAX_COMBO_WIDTH = 300
local INDENT = UI_BORDER_SPACING * 2

CSG_GearPanel = ISPanel:derive("CSG_GearPanel")

--- Creates the panel; `screen` is the CharacterCreationMain it belongs to.
function CSG_GearPanel:new(x, y, width, screen)
    local o = ISPanel:new(x, y, width, BUTTON_HGT)
    setmetatable(o, self)
    self.__index = self
    o.screen = screen
    o.widgets = {}
    o.signature = nil
    o:noBackground()
    return o
end

--- Loads the remembered selection and starts reading the item list.
function CSG_GearPanel:createChildren()
    CSG_State.load()
    CSG_State.beginCatalog()
end

--- Returns the SurvivorDesc the screen is editing.
function CSG_GearPanel:desc()
    return MainScreen.instance and MainScreen.instance.desc
end

--- Adds a child and remembers it so the next rebuild can remove it.
function CSG_GearPanel:track(widget)
    self:addChild(widget)
    table.insert(self.widgets, widget)
    return widget
end

--- Removes every widget the last rebuild created.
function CSG_GearPanel:clearWidgets()
    for _, widget in ipairs(self.widgets) do
        if widget.hideList then
            widget:hideList()
        end
        self:removeChild(widget)
    end
    self.widgets = {}
    self.progressLabel = nil
end

--- Moves the panel under the clothing rows and forces a rebuild.
function CSG_GearPanel:relayout(y)
    self:setY(y)
    if self.screen.clothingRect then
        self:setWidth(self.screen.clothingRect:getWidth())
    end
    self:refreshIfNeeded(true)
end

--- Rebuilds when the worn items or the catalog state changed.
function CSG_GearPanel:refreshIfNeeded(force)
    local desc = self:desc()
    if not desc then
        return
    end
    local signature = CSG_Runtime.wornSignature(desc) .. (CSG_State.catalogReady() and "#ready" or "#loading")
    if force or signature ~= self.signature then
        self.signature = signature
        self:rebuild()
    end
end

--- Advances the catalog build a little every frame and watches for changes.
function CSG_GearPanel:update()
    ISPanel.update(self)
    if not CSG_State.catalogReady() then
        CSG_State.stepCatalog()
        if self.progressLabel then
            local percent = math.floor(CSG_State.catalogProgress() * 100)
            self.progressLabel:setName(getText("UI_CSG_Loading") .. " " .. tostring(percent) .. "%")
        end
    end
    self:refreshIfNeeded(false)
end

--- Tells the scrolling clothing panel how tall its content is now.
function CSG_GearPanel:updateParentScroll()
    if self.parent and self.parent.setScrollHeight then
        self.parent:setScrollHeight(self:getY() + self:getHeight())
    end
end

--- Returns the width the vanilla labels use, so the rows line up.
function CSG_GearPanel:labelWidth()
    return self.screen.labelRight or 120
end

--- Returns a combo width that fits beside a label of the given width.
function CSG_GearPanel:comboWidth(labelWidth)
    return math.max(80, math.min(MAX_COMBO_WIDTH, self.width - labelWidth - UI_BORDER_SPACING))
end

--- Adds a left-aligned label and returns it.
function CSG_GearPanel:addLabel(x, y, text, font)
    local label = self:track(ISLabel:new(x, y, BUTTON_HGT, text, 1, 1, 1, 1, font or UIFont.Small, true))
    label:initialise()
    return label
end

--- Adds a section heading and returns the next y.
function CSG_GearPanel:addSectionTitle(y, text)
    self:addLabel(0, y, text, UIFont.Small)
    return y + BUTTON_HGT + 2
end

--- Adds a dim one-line hint and returns the next y.
function CSG_GearPanel:addHint(y, text)
    local label = self:addLabel(INDENT, y, text)
    label.r, label.g, label.b = 0.7, 0.7, 0.7
    return y + BUTTON_HGT + 2
end

--- Adds a button sized to its title and returns it.
function CSG_GearPanel:addButton(x, y, title, onClick, arg)
    local width = getTextManager():MeasureStringX(UIFont.Small, title) + 16
    local button = self:track(ISButton:new(x, y, width, BUTTON_HGT, title, self))
    button:setOnClick(onClick, arg)
    button:initialise()
    button:instantiate()
    return button
end

--- Adds a right-aligned label plus a filterable combo of "None" and the given
--- entries; returns the next y.
function CSG_GearPanel:addCombo(y, labelText, entries, selectedType, onChange, arg)
    local labelWidth = self:labelWidth()
    local label = self:addLabel(0, y, labelText)
    label:setX(labelWidth - label:getWidth())
    local combo = self:track(ISComboBox:new(labelWidth + UI_BORDER_SPACING, y, self:comboWidth(labelWidth), BUTTON_HGT, self, onChange, arg))
    combo:initialise()
    combo:setEditable(true)
    combo:addOptionWithData(getText("UI_CSG_None"), nil)
    for _, entry in ipairs(entries) do
        combo:addOptionWithData(entry.label, entry.fullType, entry.fullType)
    end
    combo.selected = 1
    if selectedType then
        combo:selectData(selectedType)
    end
    return y + BUTTON_HGT + UI_BORDER_SPACING
end

--- Adds the rows for one worn container: a header with its weight, a row per
--- chosen stack with + and - buttons, and a search box; returns the next y.
function CSG_GearPanel:addContainer(y, container)
    local selection = CSG_State.selection
    local weight = CSG_Selection.containerWeight(selection, container.key, CSG_State.weightOf)
    local title = container.name
    if container.locationName then
        title = title .. " - " .. container.locationName
    end
    title = title .. "   (" .. getText("UI_CSG_Weight") .. " " .. string.format("%.1f", weight) .. " / " .. tostring(container.capacity) .. ")"
    local header = self:addLabel(0, y, title)
    if weight > container.capacity then
        header.r, header.g, header.b = 1, 0.45, 0.45
    end
    y = y + BUTTON_HGT + 2

    for _, stack in ipairs(CSG_Selection.containerItems(selection, container.key)) do
        local entry = CSG_State.entry(stack.fullType)
        local ref = { key = container.key, fullType = stack.fullType }
        local minus = self:addButton(INDENT, y, "-", CSG_GearPanel.onContainerMinus, ref)
        local plus = self:addButton(minus:getRight() + 2, y, "+", CSG_GearPanel.onContainerPlus, ref)
        local remove = self:addButton(plus:getRight() + 2, y, getText("UI_CSG_Remove"), CSG_GearPanel.onContainerRemove, ref)
        self:addLabel(remove:getRight() + UI_BORDER_SPACING, y, tostring(stack.count) .. "x " .. (entry and entry.label or stack.fullType))
        y = y + BUTTON_HGT + 2
    end

    local search = self:track(CSG_ItemSearch:new(INDENT, y, self:comboWidth(INDENT), CSG_State.entries, self, CSG_GearPanel.onContainerAdd, container.key))
    search:initialise()
    search.entry:setTooltip(getText("UI_CSG_AddItem"))
    return y + BUTTON_HGT + UI_BORDER_SPACING
end

--- Rebuilds every row from the worn items, the catalog and the selection.
function CSG_GearPanel:rebuild()
    self:clearWidgets()
    local y = UI_BORDER_SPACING

    self:addLabel(0, y, getText("UI_CSG_Title"), UIFont.Medium)
    local clear = self:addButton(0, y, getText("UI_CSG_Clear"), CSG_GearPanel.onClearAll)
    clear:setX(self.width - clear:getWidth())
    y = y + FONT_HGT_MEDIUM + 5
    local rule = self:track(ISRect:new(0, y, self.width, 1, 1, 0.3, 0.3, 0.3))
    rule:initialise()
    rule:instantiate()
    y = y + UI_BORDER_SPACING

    if not CSG_State.catalogReady() then
        self.progressLabel = self:addLabel(0, y, getText("UI_CSG_Loading"))
        self:setHeight(y + BUTTON_HGT + UI_BORDER_SPACING)
        self:updateParentScroll()
        return
    end

    local selection = CSG_State.selection
    local facts = CSG_Runtime.facts(self:desc())

    y = self:addSectionTitle(y, getText("UI_CSG_Hands"))
    y = self:addCombo(y, getText("UI_CSG_PrimaryHand"), CSG_State.weaponEntries, selection.hands.primary, CSG_GearPanel.onHandChanged, "primary")
    y = self:addCombo(y, getText("UI_CSG_SecondaryHand"), CSG_State.weaponEntries, selection.hands.secondary, CSG_GearPanel.onHandChanged, "secondary")

    y = self:addSectionTitle(y, getText("UI_CSG_Attachments"))
    for _, slot in ipairs(facts.slots) do
        local eligible = CSG_SlotLogic.eligibleItems(CSG_State.entries, slot.def, facts.replacements)
        local name = getTextOrNull("IGUI_HotbarAttachment_" .. slot.type) or slot.name
        y = self:addCombo(y, name, eligible, selection.attachments[slot.type], CSG_GearPanel.onAttachmentChanged, slot.type)
    end
    if #facts.slots <= 1 then
        y = self:addHint(y, getText("UI_CSG_NoSlots"))
    end

    y = self:addSectionTitle(y, getText("UI_CSG_Containers"))
    if #facts.containers == 0 then
        y = self:addHint(y, getText("UI_CSG_NoBags"))
    end
    for _, container in ipairs(facts.containers) do
        y = self:addContainer(y, container)
    end

    self:setHeight(y + UI_BORDER_SPACING)
    self:updateParentScroll()
end

--- Stores a hand choice.
function CSG_GearPanel:onHandChanged(combo, hand)
    CSG_Selection.setHand(CSG_State.selection, hand, combo:getOptionData(combo.selected))
    CSG_State.save()
end

--- Stores an attachment-slot choice.
function CSG_GearPanel:onAttachmentChanged(combo, slotType)
    CSG_Selection.setAttachment(CSG_State.selection, slotType, combo:getOptionData(combo.selected))
    CSG_State.save()
end

--- Adds one of the picked item to a container and redraws.
function CSG_GearPanel:onContainerAdd(fullType, key)
    CSG_Selection.addToContainer(CSG_State.selection, key, fullType, 1)
    CSG_State.save()
    self:rebuild()
end

--- Adds one more of a stack.
function CSG_GearPanel:onContainerPlus(button, ref)
    CSG_Selection.addToContainer(CSG_State.selection, ref.key, ref.fullType, 1)
    CSG_State.save()
    self:rebuild()
end

--- Takes one away from a stack.
function CSG_GearPanel:onContainerMinus(button, ref)
    CSG_Selection.removeFromContainer(CSG_State.selection, ref.key, ref.fullType, 1)
    CSG_State.save()
    self:rebuild()
end

--- Removes a whole stack.
function CSG_GearPanel:onContainerRemove(button, ref)
    local stacks = CSG_Selection.containerItems(CSG_State.selection, ref.key)
    for _, stack in ipairs(stacks) do
        if stack.fullType == ref.fullType then
            CSG_Selection.removeFromContainer(CSG_State.selection, ref.key, ref.fullType, stack.count)
            break
        end
    end
    CSG_State.save()
    self:rebuild()
end

--- Forgets every chosen item.
function CSG_GearPanel:onClearAll()
    CSG_State.reset()
    self:rebuild()
end
