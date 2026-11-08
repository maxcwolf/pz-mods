--- One of the two part lists of the Starting Vehicle window, drawn like the
--- in-game mechanics window: category headings, then each part with what it
--- will hold on the right (green fitted, amber game's choice, red removed).
require "ISUI/ISScrollingListBox"

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)

CSV_PartList = ISScrollingListBox:derive("CSV_PartList")

--- Creates a list that reports clicks to `owner:selectPart(id)`.
function CSV_PartList:new(x, y, width, height, owner)
    local o = ISScrollingListBox.new(self, x, y, width, height)
    o.owner = owner
    o.itemheight = FONT_HGT_SMALL + 6
    o.drawBorder = true
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.35 }
    o.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    o.selected = -1
    return o
end

--- Fills the list from category groups ({category, label, parts}).
function CSV_PartList:setGroups(groups)
    self:clear()
    for _, group in ipairs(groups) do
        local heading = self:addItem(group.label, { cat = true, name = group.label })
        heading.height = FONT_HGT_MEDIUM + 6
        for _, part in ipairs(group.parts) do
            self:addItem(part.label, { part = part })
        end
    end
    local total = 0
    for _, row in ipairs(self.items) do
        total = total + row.height
    end
    self:setScrollHeight(total)
    self.selected = -1
end

--- Highlights the row of a part id, or clears the highlight.
function CSV_PartList:select(partId)
    self.selected = -1
    for i, row in ipairs(self.items) do
        if row.item.part and row.item.part.id == partId then
            self.selected = i
            self:ensureVisible(i)
            return true
        end
    end
    return false
end

local fitCache = {}

--- Cuts text with "..." so it fits a width in the small font; results are
--- cached because rows are drawn every frame.
local function fit(text, width)
    width = math.floor(width)
    local key = text .. "\0" .. width
    local cached = fitCache[key]
    if cached then
        return cached
    end
    local result = text
    local tm = getTextManager()
    if tm:MeasureStringX(UIFont.Small, text) > width then
        while #result > 1 and tm:MeasureStringX(UIFont.Small, result .. "...") > width do
            result = string.sub(result, 1, -2)
        end
        result = result .. "..."
    end
    fitCache[key] = result
    return result
end

--- Draws a heading or a part row.
function CSV_PartList:doDrawItem(y, item, alt)
    local height = item.height or self.itemheight
    if (y + self:getYScroll() + height < 0) or (y + self:getYScroll() >= self.height) then
        return y + height
    end
    if item.item.cat then
        self:drawText(item.item.name, 6, y + 3, 1, 1, 1, 1, UIFont.Medium)
        return y + height
    end
    local width = self:getWidth() - (self.vscroll and self.vscroll:getWidth() or 0)
    if item.itemindex == self.selected then
        self:drawRect(0, y, width, height, 0.15, 1, 1, 1)
    elseif item.itemindex == self.mouseoverselected and self:isMouseOver() and not self:isMouseOverScrollBar() then
        self:drawRect(0, y, width, height, 0.06, 1, 1, 1)
    end
    local part = item.item.part
    local text, r, g, b = self.owner:choiceText(part)
    local textY = y + (height - FONT_HGT_SMALL) / 2
    local right = 0
    if text and text ~= "" then
        text = fit(text, width * 0.5)
        right = getTextManager():MeasureStringX(UIFont.Small, text)
        self:drawText(text, width - right - 6, textY, r, g, b, 1, UIFont.Small)
    end
    self:drawText(fit(part.label, width - right - 32), 18, textY, 0.85, 0.85, 0.85, 1, UIFont.Small)
    return y + height
end

--- Selects the clicked part (headings ignore clicks).
function CSV_PartList:onMouseDown(x, y)
    if #self.items == 0 then
        return
    end
    local row = self:rowAt(x, y)
    local item = self.items[row]
    if not item or item.item.cat then
        return
    end
    getSoundManager():playUISound("UISelectListItem")
    self.selected = row
    self.owner:selectPart(item.item.part.id)
end
