--- A search box that pops up a list of matching catalog items under itself.
--- Picking a row calls onPick(target, fullType, arg) and clears the box.
require "ISUI/ISPanel"
require "ISUI/ISTextEntryBox"
require "ISUI/ISScrollingListBox"
require "ChooseStartingGear/state"

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local BUTTON_HGT = FONT_HGT_SMALL + 6
local MAX_ROWS = 8
local MAX_MATCHES = 60

CSG_ItemSearch = ISPanel:derive("CSG_ItemSearch")

--- Creates the search box.
function CSG_ItemSearch:new(x, y, width, entries, target, onPick, arg)
    local o = ISPanel:new(x, y, width, BUTTON_HGT)
    setmetatable(o, self)
    self.__index = self
    o.entries = entries
    o.target = target
    o.onPick = onPick
    o.arg = arg
    o:noBackground()
    return o
end

--- Builds the text entry and the floating result list.
function CSG_ItemSearch:createChildren()
    local owner = self
    self.entry = ISTextEntryBox:new("", 0, 0, self.width, BUTTON_HGT)
    self.entry:initialise()
    self.entry:instantiate()
    self.entry:setClearButton(true)
    self.entry.onTextChange = function() owner:onFilter() end
    self:addChild(self.entry)

    self.list = ISScrollingListBox:new(0, 0, self.width, BUTTON_HGT)
    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight = BUTTON_HGT
    self.list.font = UIFont.Small
    self.list.drawBorder = true
    self.list.backgroundColor = { r = 0, g = 0, b = 0, a = 0.95 }
    self.list:setOnMouseDownFunction(self, CSG_ItemSearch.onRowClicked)
    self.list.onMouseDownOutside = function(list, x, y)
        if not owner.entry:isMouseOver() then
            owner:hideList()
        end
    end
    self.list:setVisible(false)
end

--- Fills the result list from the typed text and shows or hides it.
function CSG_ItemSearch:onFilter()
    local text = self.entry:getInternalText() or ""
    self.list:clear()
    if text:trim() == "" then
        self:hideList()
        return
    end
    local matches = CSG_Catalog.filter(self.entries, text)
    local shown = math.min(#matches, MAX_MATCHES)
    for i = 1, shown do
        self.list:addItem(matches[i].label, matches[i].fullType, matches[i].fullType)
    end
    if shown == 0 then
        self.list:addItem("(" .. getText("UI_CSG_None") .. ")", nil)
        shown = 1
    end
    self.list:setHeight(math.min(shown, MAX_ROWS) * BUTTON_HGT)
    self:showList()
end

--- Shows the result list as a floating element above everything else.
function CSG_ItemSearch:showList()
    if not self.list:getIsVisible() then
        self.list:addToUIManager()
        self.list:setVisible(true)
    end
    self:positionList()
    self.list:bringToTop()
end

--- Hides the floating result list.
function CSG_ItemSearch:hideList()
    if self.list:getIsVisible() then
        self.list:setVisible(false)
        self.list:removeFromUIManager()
    end
end

--- Keeps the floating list glued under the text entry.
function CSG_ItemSearch:positionList()
    self.list:setX(self.entry:getAbsoluteX())
    self.list:setY(self.entry:getAbsoluteY() + BUTTON_HGT)
    self.list:setWidth(self.width)
end

--- Follows the entry as the parent scrolls and hides when the panel is hidden.
function CSG_ItemSearch:update()
    ISPanel.update(self)
    if self.list:getIsVisible() then
        if not self:isReallyVisible() then
            self:hideList()
        else
            self:positionList()
        end
    end
end

--- Reports the chosen item and resets the box.
function CSG_ItemSearch:onRowClicked(fullType)
    if not fullType then
        return
    end
    self.entry:setText("")
    self:hideList()
    if self.onPick then
        self.onPick(self.target, fullType, self.arg)
    end
end

--- Removes the floating list when the box itself goes away.
function CSG_ItemSearch:removeFromUIManager()
    self:hideList()
    ISPanel.removeFromUIManager(self)
end
