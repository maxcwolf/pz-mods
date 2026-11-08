--- The small status chip the catalog window shrinks into while placing:
--- room and item, how many placed, the keys to use, and buttons back to
--- the catalog and to undo.
require "ISUI/ISPanel"
require "ISUI/ISButton"
local Rooms = require("FurnishByRoom/rooms")
local Theme = require("FurnishByRoom/theme")

FBR_PlacingChip = ISPanel:derive("FBR_PlacingChip")

--- Makes the chip for a controller.
function FBR_PlacingChip:new(controller)
    local o = ISPanel.new(self, 40, 80, 600, 58)
    o.controller = controller
    o.backgroundColor = { r = 0.09, g = 0.09, b = 0.08, a = 0.92 }
    o.borderColor = { r = Theme.BORDER.r, g = Theme.BORDER.g, b = Theme.BORDER.b, a = 1 }
    o.moveWithMouse = true
    return o
end

--- Adds the Catalog and Undo buttons.
function FBR_PlacingChip:createChildren()
    ISPanel.createChildren(self)
    self.backButton = ISButton:new(self.width - 178, 8, 84, 22, getText("UI_FBR_BackToCatalog"), self, FBR_PlacingChip.onBack)
    self.undoButton = ISButton:new(self.width - 88, 8, 80, 22, getText("UI_FBR_Undo"), self, FBR_PlacingChip.onUndo)
    for _, button in ipairs({ self.backButton, self.undoButton }) do
        button:initialise()
        button:instantiate()
        Theme.styleButton(button, false)
        self:addChild(button)
    end
end

--- Returns the first line: room, item and count.
function FBR_PlacingChip:title()
    local placing = self.placing
    if not placing then
        return ""
    end
    if placing.mode == "remove" then
        return getText("UI_FBR_Removing", tostring(placing.count or 0))
    end
    local room = getText(Rooms.labelKey(self.controller.browse().room))
    return getText("UI_FBR_PlacingLine", room, placing.entry.label, tostring(placing.count or 0))
end

--- Draws the two lines.
function FBR_PlacingChip:render()
    ISPanel.render(self)
    local c, m = Theme.TEXT, Theme.MUTED
    self:drawText(Theme.fit(self:title(), self.width - 200, UIFont.Small), 10, 10, c.r, c.g, c.b, 1, UIFont.Small)
    local hint = self.placing and getText("UI_FBR_Hint_" .. self.placing.mode) or ""
    self:drawText(Theme.fit(hint, self.width - 20, UIFont.Small), 10, 34, m.r, m.g, m.b, 1, UIFont.Small)
end

--- Stops placing, which brings the catalog back.
function FBR_PlacingChip:onBack()
    self.controller.stop()
end

--- Undoes the newest change.
function FBR_PlacingChip:onUndo()
    self.controller.undo()
end

--- Takes Escape while placing so it ends placing, not opens the game menu.
function FBR_PlacingChip:isKeyConsumed(key)
    return key == Keyboard.KEY_ESCAPE and self:isVisible()
end

--- Ends placing on Escape.
function FBR_PlacingChip:onKeyRelease(key)
    if key == Keyboard.KEY_ESCAPE and self:isVisible() then
        self.controller.stop()
    end
end

--- Shows the chip for a placing mode.
function FBR_PlacingChip:show(placing)
    self.placing = placing
    if not self.added then
        self:initialise()
        self:addToUIManager()
        self:setWantKeyEvents(true)
        self.added = true
    end
    self:setVisible(true)
end

--- Removes the chip.
function FBR_PlacingChip:dismiss()
    self:setVisible(false)
    self:removeFromUIManager()
    self.added = false
end

return FBR_PlacingChip
