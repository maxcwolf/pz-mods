--- The catalog window's scrolling grid of item cards. Clicking a card
--- picks it; the mouse wheel scrolls.
require "ISUI/ISPanel"
local Theme = require("FurnishByRoom/theme")
local Paging = require("FurnishByRoom/paging")

FBR_ItemGrid = ISPanel:derive("FBR_ItemGrid")

FBR_ItemGrid.COLUMNS = 4
FBR_ItemGrid.GAP = 6
FBR_ItemGrid.CARD_H = 96

--- Makes a grid; onPick(target, entry) runs on a click.
function FBR_ItemGrid:new(x, y, w, h, target, onPick)
    local o = ISPanel.new(self, x, y, w, h)
    o.target = target
    o.onPick = onPick
    o.items = {}
    o.scroll = 0
    o.selectedKey = nil
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    o.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    return o
end

--- Returns the width of one card.
function FBR_ItemGrid:cardWidth()
    return math.floor((self.width - FBR_ItemGrid.GAP * (FBR_ItemGrid.COLUMNS - 1)) / FBR_ItemGrid.COLUMNS)
end

--- Replaces the items, keeping the scroll in range.
function FBR_ItemGrid:setItems(items, selectedKey, resetScroll)
    self.items = items
    self.selectedKey = selectedKey
    if resetScroll then
        self.scroll = 0
    end
    self:clampScroll()
end

--- Keeps the scroll offset inside the content.
function FBR_ItemGrid:clampScroll()
    local contentH = Paging.gridHeight(#self.items, FBR_ItemGrid.COLUMNS, FBR_ItemGrid.CARD_H, FBR_ItemGrid.GAP)
    self.scroll = Paging.clampScroll(self.scroll, contentH, self.height)
end

--- Returns the item index under a point, or nil.
function FBR_ItemGrid:indexAt(x, y)
    return Paging.cardAt(x, y, self.scroll, FBR_ItemGrid.COLUMNS, self:cardWidth(), FBR_ItemGrid.CARD_H,
        FBR_ItemGrid.GAP, #self.items)
end

--- Draws the visible cards, clipped to the panel.
function FBR_ItemGrid:render()
    ISPanel.render(self)
    local cardW, cardH, gap = self:cardWidth(), FBR_ItemGrid.CARD_H, FBR_ItemGrid.GAP
    local hover = self:isMouseOver() and self:indexAt(self:getMouseX(), self:getMouseY()) or nil
    self:setStencilRect(0, 0, self.width, self.height)
    for i, entry in ipairs(self.items) do
        local col = (i - 1) % FBR_ItemGrid.COLUMNS
        local row = math.floor((i - 1) / FBR_ItemGrid.COLUMNS)
        local y = row * (cardH + gap) - self.scroll
        if y + cardH >= 0 and y <= self.height then
            Theme.drawCard(self, entry, col * (cardW + gap), y, cardW, cardH, entry.key == self.selectedKey, i == hover)
        end
    end
    self:clearStencilRect()
    if #self.items == 0 then
        local c = Theme.MUTED
        self:drawTextCentre(getText("UI_FBR_NoItems"), self.width / 2, 24, c.r, c.g, c.b, 1, UIFont.Small)
    end
end

--- Picks the clicked card.
function FBR_ItemGrid:onMouseDown(x, y)
    local index = self:indexAt(x, y)
    if index and self.onPick then
        self.onPick(self.target, self.items[index])
    end
    return true
end

--- Scrolls by a row per wheel notch.
function FBR_ItemGrid:onMouseWheel(del)
    self.scroll = self.scroll + del * (FBR_ItemGrid.CARD_H + FBR_ItemGrid.GAP)
    self:clampScroll()
    return true
end

return FBR_ItemGrid
