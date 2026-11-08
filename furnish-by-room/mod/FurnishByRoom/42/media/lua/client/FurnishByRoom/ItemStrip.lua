--- Layout B: a strip along the bottom of the screen with room pills, a
--- category button that cycles, and eight item cards at a time. It stays
--- up while placing, so a click on another card switches pieces.
require "ISUI/ISPanel"
require "ISUI/ISButton"
local Rooms = require("FurnishByRoom/rooms")
local Classify = require("FurnishByRoom/classify")
local Layout = require("FurnishByRoom/layout")
local Paging = require("FurnishByRoom/paging")
local Theme = require("FurnishByRoom/theme")

FBR_ItemStrip = ISPanel:derive("FBR_ItemStrip")

FBR_ItemStrip.PAGE = 8
FBR_ItemStrip.HEIGHT = 182
FBR_ItemStrip.CARD_H = 96
FBR_ItemStrip.ARROW_W = 28
FBR_ItemStrip.GAP = 6

--- Makes the strip for a controller, centered above the hotbar.
function FBR_ItemStrip:new(controller)
    local screenW, screenH = getCore():getScreenWidth(), getCore():getScreenHeight()
    local w = math.min(1000, screenW - 160)
    local o = ISPanel.new(self, math.floor((screenW - w) / 2), screenH - FBR_ItemStrip.HEIGHT - 96, w, FBR_ItemStrip.HEIGHT)
    o.controller = controller
    o.first = 1
    o.backgroundColor = { r = 0.09, g = 0.09, b = 0.08, a = 0.92 }
    o.borderColor = { r = Theme.BORDER.r, g = Theme.BORDER.g, b = Theme.BORDER.b, a = 1 }
    o.moveWithMouse = true
    return o
end

--- Adds one small button.
function FBR_ItemStrip:button(x, y, w, h, title, fn)
    local button = ISButton:new(x, y, w, h, title, self, fn)
    button:initialise()
    button:instantiate()
    Theme.styleButton(button, false)
    self:addChild(button)
    return button
end

--- Creates the room pills, the right-hand buttons and the arrows.
function FBR_ItemStrip:createChildren()
    ISPanel.createChildren(self)
    local tm = getTextManager()
    local x = 8
    self.pills = {}
    for _, room in ipairs(Rooms.ORDER) do
        local title = getText(Rooms.labelKey(room))
        local w = tm:MeasureStringX(UIFont.Small, title) + 20
        local pill = self:button(x, 8, w, 24, title, FBR_ItemStrip.onPill)
        pill.internal = room
        self.pills[room] = pill
        x = x + w + 4
    end
    self.catButton = self:button(x + 8, 8, 130, 24, "", FBR_ItemStrip.onCategory)

    local right = self.width - 8
    self.closeButton = self:button(right - 28, 8, 28, 24, "X", FBR_ItemStrip.onClose)
    self.layoutButton = self:button(right - 28 - 6 - 96, 8, 96, 24, getText("UI_FBR_UseCatalog"), FBR_ItemStrip.onLayout)
    self.undoButton = self:button(right - 28 - 6 - 96 - 6 - 80, 8, 80, 24, getText("UI_FBR_Undo"), FBR_ItemStrip.onUndo)
    self.removeButton = self:button(right - 28 - 6 - 96 - 6 - 80 - 6 - 80, 8, 80, 24, getText("UI_FBR_Remove"), FBR_ItemStrip.onRemove)

    local cardsY = 40
    self.prevButton = self:button(8, cardsY, FBR_ItemStrip.ARROW_W, FBR_ItemStrip.CARD_H, "<", FBR_ItemStrip.onPrev)
    self.nextButton = self:button(self.width - 8 - FBR_ItemStrip.ARROW_W, cardsY, FBR_ItemStrip.ARROW_W,
        FBR_ItemStrip.CARD_H, ">", FBR_ItemStrip.onNext)
    self.cardsX = 8 + FBR_ItemStrip.ARROW_W + FBR_ItemStrip.GAP
    self.cardsY = cardsY
    self.cardsW = self.width - 2 * self.cardsX
end

--- Returns the width of one card.
function FBR_ItemStrip:cardWidth()
    return math.floor((self.cardsW - FBR_ItemStrip.GAP * (FBR_ItemStrip.PAGE - 1)) / FBR_ItemStrip.PAGE)
end

--- Returns the visible items.
function FBR_ItemStrip:visibleItems()
    return Paging.slice(self.items or {}, self.first, FBR_ItemStrip.PAGE)
end

--- Returns the visible item index under a point, or nil.
function FBR_ItemStrip:indexAt(x, y)
    if y < self.cardsY or y > self.cardsY + FBR_ItemStrip.CARD_H then
        return nil
    end
    return Paging.cardAt(x - self.cardsX, y - self.cardsY, 0, FBR_ItemStrip.PAGE, self:cardWidth(),
        FBR_ItemStrip.CARD_H, FBR_ItemStrip.GAP, #self:visibleItems())
end

--- Redraws pills, the category button and the cards.
function FBR_ItemStrip:refresh()
    local browse = self.controller.browse()
    for room, pill in pairs(self.pills) do
        Theme.styleButton(pill, room == browse.room)
    end
    local filters = self.controller.filters()
    local position = 1
    for i, cat in ipairs(filters) do
        if cat == browse.cat then
            position = i
        end
    end
    self.catButton:setTitle(getText(Classify.labelKey(browse.cat)) .. "  " .. position .. "/" .. #filters .. "  >")
    if self.shownRoom ~= browse.room or self.shownCat ~= browse.cat then
        self.first = 1
    end
    self.shownRoom, self.shownCat = browse.room, browse.cat
    self.items = self.controller.items()
    self.first = Paging.scrollBy(self.first, #self.items, FBR_ItemStrip.PAGE, 0)
    self.undoButton:setTitle(getText("UI_FBR_Undo") .. " (" .. self.controller.undoCount() .. ")")
end

--- Draws the cards and the hint line.
function FBR_ItemStrip:render()
    ISPanel.render(self)
    local cardW = self:cardWidth()
    local hover = self:isMouseOver() and self:indexAt(self:getMouseX(), self:getMouseY()) or nil
    for i, entry in ipairs(self:visibleItems()) do
        local x = self.cardsX + (i - 1) * (cardW + FBR_ItemStrip.GAP)
        Theme.drawCard(self, entry, x, self.cardsY, cardW, FBR_ItemStrip.CARD_H,
            entry.key == self.controller.picked, i == hover)
    end
    local m = Theme.MUTED
    local placing = self.controller.placing
    local hint = getText(placing and ("UI_FBR_Hint_" .. placing.mode) or "UI_FBR_Hint_strip")
    local lineY = self.cardsY + FBR_ItemStrip.CARD_H + 12
    self:drawText(Theme.fit(hint, self.width - 160, UIFont.Small), 10, lineY, m.r, m.g, m.b, 1, UIFont.Small)
    local total = #(self.items or {})
    local last = math.min(total, self.first + FBR_ItemStrip.PAGE - 1)
    local range = total == 0 and getText("UI_FBR_NoItems") or (self.first .. "-" .. last .. " / " .. total)
    self:drawTextRight(range, self.width - 10, lineY, m.r, m.g, m.b, 1, UIFont.Small)
end

--- Picks the clicked card; elsewhere drags the strip.
function FBR_ItemStrip:onMouseDown(x, y)
    local index = self:indexAt(x, y)
    if index then
        self.controller.pick(self:visibleItems()[index])
        return true
    end
    return ISPanel.onMouseDown(self, x, y)
end

--- Scrolls one card per wheel notch.
function FBR_ItemStrip:onMouseWheel(del)
    self.first = Paging.scrollBy(self.first, #(self.items or {}), FBR_ItemStrip.PAGE, del)
    return true
end

--- Switches rooms.
function FBR_ItemStrip:onPill(button)
    self.controller.selectRoom(button.internal)
end

--- Steps to the next category.
function FBR_ItemStrip:onCategory()
    self.controller.nextCategory()
end

--- Pages back.
function FBR_ItemStrip:onPrev()
    self.first = Paging.step(self.first, #(self.items or {}), FBR_ItemStrip.PAGE, -1)
end

--- Pages forward.
function FBR_ItemStrip:onNext()
    self.first = Paging.step(self.first, #(self.items or {}), FBR_ItemStrip.PAGE, 1)
end

--- Starts the Remove tool.
function FBR_ItemStrip:onRemove()
    self.controller.startRemove()
end

--- Undoes the newest change.
function FBR_ItemStrip:onUndo()
    self.controller.undo()
end

--- Switches to the catalog window.
function FBR_ItemStrip:onLayout()
    self.controller.setLayout(Layout.CATALOG)
end

--- Closes the mod.
function FBR_ItemStrip:onClose()
    self.controller.close()
end

--- Takes Escape: it ends placing first, then closes the strip.
function FBR_ItemStrip:isKeyConsumed(key)
    return key == Keyboard.KEY_ESCAPE and self:isVisible()
end

--- Ends placing, or closes the strip, on Escape.
function FBR_ItemStrip:onKeyRelease(key)
    if key ~= Keyboard.KEY_ESCAPE or not self:isVisible() then
        return
    end
    if self.controller.placing then
        self.controller.stop()
    else
        self.controller.close()
    end
end

--- View: puts the strip on screen.
function FBR_ItemStrip:show()
    if not self.added then
        self:initialise()
        self:addToUIManager()
        self:setWantKeyEvents(true)
        self.added = true
    end
    self:setVisible(true)
end

--- View: true while the strip is on screen.
function FBR_ItemStrip:isShown()
    return self.added == true
end

--- View: removes the strip.
function FBR_ItemStrip:dismiss()
    self:setVisible(false)
    self:removeFromUIManager()
    self.added = false
end

--- View: the strip stays up while placing; it only redraws.
function FBR_ItemStrip:onPlacingStarted()
    self:refresh()
end

--- View: redraws when placing ends.
function FBR_ItemStrip:onPlacingEnded()
    self:refresh()
end

--- Makes the view for the controller.
function FBR_ItemStrip.create(controller)
    return FBR_ItemStrip:new(controller)
end

return FBR_ItemStrip
