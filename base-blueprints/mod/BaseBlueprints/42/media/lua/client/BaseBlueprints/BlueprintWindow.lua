--- The Base Blueprints window: your claimed base and its changes, saving
--- them as a blueprint, and the list of saved blueprints to apply to this
--- world now or to every new game.
require "ISUI/ISCollapsableWindow"
require "ISUI/ISLabel"
require "ISUI/ISButton"
require "ISUI/ISTickBox"
require "ISUI/ISTextEntryBox"
require "ISUI/ISScrollingListBox"
require "ISUI/ISModalDialog"
local Runtime = require("BaseBlueprints/runtime")
local Overlay = require("BaseBlueprints/overlay")
local Blueprint = require("BaseBlueprints/blueprint")
local Library = require("BaseBlueprints/library")

local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local PAD = 12
local BUTTON_HGT = FONT_HGT_MEDIUM + 10
local ROW_HGT = FONT_HGT_MEDIUM + FONT_HGT_SMALL + 14

BBP_BlueprintWindow = ISCollapsableWindow:derive("BBP_BlueprintWindow")

--- Opens (or brings back) the single window.
function BBP_BlueprintWindow.open()
    local window = BBP_BlueprintWindow.instance
    if not window then
        local w = math.min(640, getCore():getScreenWidth() - 40)
        local h = math.min(660, getCore():getScreenHeight() - 40)
        window = BBP_BlueprintWindow:new((getCore():getScreenWidth() - w) / 2, (getCore():getScreenHeight() - h) / 2, w, h)
        window:initialise()
        window:addToUIManager()
        BBP_BlueprintWindow.instance = window
    end
    window:setVisible(true)
    window:bringToTop()
    window:refresh()
    return window
end

--- Creates the window.
function BBP_BlueprintWindow:new(x, y, width, height)
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o:setTitle(getText("UI_BBP_Title"))
    o.message = ""
    return o
end

--- Adds a label in a font.
function BBP_BlueprintWindow:makeLabel(x, y, text, font, r, g, b)
    local label = ISLabel:new(x, y, BUTTON_HGT, text, r or 1, g or 1, b or 1, 1, font or UIFont.Medium, true)
    label:initialise()
    self:addChild(label)
    return label
end

--- Adds a button sized to its title.
function BBP_BlueprintWindow:makeButton(x, y, title, onClick)
    local width = getTextManager():MeasureStringX(UIFont.Medium, title) + 24
    local button = ISButton:new(x, y, width, BUTTON_HGT, title, self)
    button.font = UIFont.Medium
    button:setOnClick(onClick)
    button:initialise()
    button:instantiate()
    self:addChild(button)
    return button
end

--- Adds a one-option tick box.
function BBP_BlueprintWindow:makeTick(x, y, text, onTick)
    local tick = ISTickBox:new(x, y, 200, BUTTON_HGT, "", self, onTick)
    tick:initialise()
    self:addChild(tick)
    tick:addOption(text)
    tick:setWidthToFit()
    return tick
end

--- Builds every control.
function BBP_BlueprintWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    self:setResizable(false)
    local x = PAD
    local y = self:titleBarHeight() + PAD
    local innerW = self.width - PAD * 2

    self:makeLabel(x, y, getText("UI_BBP_YourBase"))
    y = y + BUTTON_HGT
    self.statusLabel = self:makeLabel(x, y, "", UIFont.Small, 0.85, 0.85, 0.85)
    y = y + FONT_HGT_SMALL + 6
    self.changesTick = self:makeTick(x, y, getText("UI_BBP_ShowChanges"), BBP_BlueprintWindow.onChangesTick)
    self.unclaimButton = self:makeButton(0, y, getText("UI_BBP_Unclaim"), BBP_BlueprintWindow.onUnclaim)
    self.unclaimButton:setX(self.width - PAD - self.unclaimButton:getWidth())
    y = y + BUTTON_HGT + PAD * 2

    self:makeLabel(x, y, getText("UI_BBP_SaveHeading"))
    y = y + BUTTON_HGT + 4
    self.saveButton = self:makeButton(0, y, getText("UI_BBP_Save"), BBP_BlueprintWindow.onSave)
    self.saveButton:setX(self.width - PAD - self.saveButton:getWidth())
    self.nameEntry = ISTextEntryBox:new(getText("UI_BBP_DefaultName"), x, y, self.saveButton:getX() - PAD - x, BUTTON_HGT)
    self.nameEntry.font = UIFont.Medium
    self.nameEntry:initialise()
    self.nameEntry:instantiate()
    self:addChild(self.nameEntry)
    y = y + BUTTON_HGT + 4
    self.contentsTick = self:makeTick(x, y, getText("UI_BBP_SaveContents"), nil)
    self.everyTileTick = self:makeTick(self.contentsTick:getRight() + PAD * 2, y, getText("UI_BBP_EveryTile"), nil)
    y = y + BUTTON_HGT + PAD * 2

    self:makeLabel(x, y, getText("UI_BBP_SavedHeading"))
    y = y + BUTTON_HGT + 4
    local bottom = self.height - PAD
    local messageY = bottom - FONT_HGT_SMALL
    local tickY = messageY - 6 - BUTTON_HGT
    local buttonY = tickY - 4 - BUTTON_HGT
    local listH = buttonY - 6 - y
    self.list = ISScrollingListBox:new(x, y, innerW, listH)
    self.list:initialise()
    self.list:instantiate()
    self.list:setFont(UIFont.Medium, 5)
    self.list.itemheight = ROW_HGT
    self.list.drawBorder = true
    self.list.doDrawItem = BBP_BlueprintWindow.drawRow
    self.list:setOnMouseDownFunction(self, BBP_BlueprintWindow.onRowClicked)
    self:addChild(self.list)

    self.applyButton = self:makeButton(x, buttonY, getText("UI_BBP_ApplyNow"), BBP_BlueprintWindow.onApply)
    self.deleteButton = self:makeButton(0, buttonY, getText("UI_BBP_Delete"), BBP_BlueprintWindow.onDelete)
    self.deleteButton:setX(self.width - PAD - self.deleteButton:getWidth())
    self.autoTick = self:makeTick(x, tickY, getText("UI_BBP_AutoApply"), BBP_BlueprintWindow.onAutoTick)
    self.useContentsTick = self:makeTick(self.autoTick:getRight() + PAD * 2, tickY, getText("UI_BBP_UseContents"), BBP_BlueprintWindow.onUseContentsTick)
    self.messageLabel = self:makeLabel(x, messageY - 4, "", UIFont.Small, 0.95, 0.85, 0.4)
end

--- Draws one saved blueprint row: name, then place, size and flags.
function BBP_BlueprintWindow.drawRow(list, y, item, alt)
    if y + list:getYScroll() + item.height < 0 or y + list:getYScroll() >= list.height then
        return y + item.height
    end
    if list.selected == item.index then
        list:drawRect(0, y, list:getWidth(), item.height - 1, 0.35, 0.7, 0.35, 0.15)
    end
    list:drawRectBorder(0, y, list:getWidth(), item.height, 0.3, list.borderColor.r, list.borderColor.g, list.borderColor.b)
    local entry = item.item
    list:drawText(entry.name, 10, y + 5, 1, 1, 1, 1, UIFont.Medium)
    local details = getText("UI_BBP_RowDetails", Runtime.int(entry.x), Runtime.int(entry.y), Runtime.int(entry.squares))
    if entry.auto then
        details = details .. "  -  " .. getText("UI_BBP_RowAuto")
    end
    if entry.contents then
        details = details .. "  -  " .. getText("UI_BBP_RowContents")
    end
    list:drawText(details, 10, y + 7 + FONT_HGT_MEDIUM, 0.65, 0.65, 0.75, 1, UIFont.Small)
    return y + item.height
end

--- Returns the selected saved blueprint entry, or nil.
function BBP_BlueprintWindow:selectedEntry()
    local row = self.list.items[self.list.selected]
    return row and row.item or nil
end

--- Rereads the claim, its changes and the saved list into the controls.
function BBP_BlueprintWindow:refresh()
    if not self.list then
        return
    end
    local claim = Runtime.claim()
    if claim then
        local changes = Runtime.findChanges()
        local b = claim.building
        self.statusLabel:setName(getText("UI_BBP_StatusClaimed", Runtime.int(b.x), Runtime.int(b.y), Runtime.int(#changes.keys)))
    else
        self.statusLabel:setName(getText("UI_BBP_StatusNone"))
    end
    self.changesTick:setSelected(1, Overlay.enabled and claim ~= nil)
    self.unclaimButton:setEnable(claim ~= nil)
    self.saveButton:setEnable(claim ~= nil)

    local selectedId = self:selectedEntry() and self:selectedEntry().id
    self.list:clear()
    for _, entry in ipairs(Runtime.entries()) do
        self.list:addItem(entry.name, entry)
        if entry.id == selectedId then
            self.list.selected = #self.list.items
        end
    end
    if self.list.selected > #self.list.items or self.list.selected < 1 then
        self.list.selected = 1
    end
    self:refreshSelection()
end

--- Updates the buttons and ticks for the selected blueprint.
function BBP_BlueprintWindow:refreshSelection()
    local entry = self:selectedEntry()
    self.applyButton:setEnable(entry ~= nil)
    self.deleteButton:setEnable(entry ~= nil)
    self.autoTick:setSelected(1, entry ~= nil and entry.auto == true)
    self.useContentsTick:setSelected(1, entry ~= nil and entry.contents and entry.useContents == true)
end

--- Shows a result line at the bottom.
function BBP_BlueprintWindow:setMessage(text)
    self.messageLabel:setName(text or "")
end

--- Updates the controls after a row is clicked.
function BBP_BlueprintWindow:onRowClicked(entry)
    self:refreshSelection()
end

--- Turns the change highlight on or off.
function BBP_BlueprintWindow:onChangesTick(index, selected)
    Overlay.setEnabled(selected == true and Runtime.claim() ~= nil)
    self:refresh()
end

--- Drops the claim after asking.
function BBP_BlueprintWindow:onUnclaim()
    self:confirm(getText("UI_BBP_ConfirmUnclaim"), function()
        Runtime.unclaim()
        Overlay.setEnabled(false)
        self:setMessage(getText("UI_BBP_Unclaimed"))
        self:refresh()
    end)
end

--- Saves the claimed base under the typed name, asking before replacing a
--- blueprint with the same name.
function BBP_BlueprintWindow:onSave()
    local name = Blueprint.cleanName(self.nameEntry:getInternalText())
    if Library.idForName(Runtime.entries(), name) then
        self:confirm(getText("UI_BBP_ConfirmReplace", name), function()
            self:save(name)
        end)
        return
    end
    self:save(name)
end

--- Saves under a name and selects the new row.
function BBP_BlueprintWindow:save(name)
    local entry, message = Runtime.save(name, {
        contents = self.contentsTick:isSelected(1),
        everyTile = self.everyTileTick:isSelected(1),
    })
    self:setMessage(message)
    self:refresh()
    if entry then
        for i, row in ipairs(self.list.items) do
            if row.item.id == entry.id then
                self.list.selected = i
            end
        end
        self:refreshSelection()
    end
end

--- Applies the selected blueprint to this world after asking.
function BBP_BlueprintWindow:onApply()
    local entry = self:selectedEntry()
    if not entry then
        return
    end
    local withContents = entry.contents and entry.useContents == true
    self:confirm(getText("UI_BBP_ConfirmApply", entry.name), function()
        local _, message = Runtime.apply(entry.id, withContents)
        self:setMessage(message)
        self:refresh()
    end)
end

--- Deletes the selected blueprint after asking.
function BBP_BlueprintWindow:onDelete()
    local entry = self:selectedEntry()
    if not entry then
        return
    end
    self:confirm(getText("UI_BBP_ConfirmDelete", entry.name), function()
        Runtime.delete(entry.id)
        self:setMessage(getText("UI_BBP_Deleted", entry.name))
        self:refresh()
    end)
end

--- Marks the selected blueprint for new games.
function BBP_BlueprintWindow:onAutoTick(index, selected)
    local entry = self:selectedEntry()
    if entry then
        Runtime.setFlag(entry.id, "auto", selected == true)
    end
    self:refresh()
end

--- Chooses whether applying restores the saved container contents.
function BBP_BlueprintWindow:onUseContentsTick(index, selected)
    local entry = self:selectedEntry()
    if entry and entry.contents then
        Runtime.setFlag(entry.id, "useContents", selected == true)
    elseif selected then
        self:setMessage(getText("UI_BBP_NoContentsSaved"))
    end
    self:refresh()
end

--- Asks a yes/no question and runs fn on yes.
function BBP_BlueprintWindow:confirm(text, fn)
    local w, h = 420, 160
    local modal = ISModalDialog:new((getCore():getScreenWidth() - w) / 2, (getCore():getScreenHeight() - h) / 2, w, h, text, true, nil, function(_, button)
        if button.internal == "YES" then
            fn()
        end
    end)
    modal:initialise()
    modal:addToUIManager()
    modal:bringToTop()
end

--- Hides the window.
function BBP_BlueprintWindow:close()
    self:setVisible(false)
end
