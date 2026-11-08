--- The top-down mechanics diagram from the in-game mechanics window, using
--- the overlay art vanilla and KI5 register (ISCarMechanicsOverlay). Each part
--- is tinted by its choice: green fitted, amber game's choice, blinking red
--- removed. Click a part to select it.
require "ISUI/ISPanel"
require "Vehicles/ISUI/ISCarMechanicsOverlay"
local Overlay = require("ChooseStartingVehicle/overlay")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)

CSV_MechanicsDiagram = ISPanel:derive("CSV_MechanicsDiagram")

--- Creates the diagram; `owner` provides partStateOf(id), levelColor(level),
--- partLabel(id) and selectPart(id).
function CSV_MechanicsDiagram:new(x, y, width, height, owner)
    local o = ISPanel.new(self, x, y, width, height)
    o.owner = owner
    o.backgroundColor = { r = 0.12, g = 0.12, b = 0.12, a = 1 }
    o.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    o.blink = 1
    o.blinkUp = false
    return o
end

--- Shows the diagram for an entry (nil clears it).
function CSV_MechanicsDiagram:setEntry(entry)
    self.diagram = nil
    self.baseTexture = nil
    if entry and ISCarMechanicsOverlay then
        local ids = {}
        for _, part in ipairs(entry.parts or {}) do
            ids[#ids + 1] = part.id
        end
        self.diagram = Overlay.diagram(ISCarMechanicsOverlay.CarList, ISCarMechanicsOverlay.PartList, entry.overlay, ids)
        if self.diagram then
            self.baseTexture = getTexture(self.diagram.base)
        end
    end
end

--- Works out the scale and offset that fit the overlay art in the panel.
function CSV_MechanicsDiagram:layout()
    local tex = self.baseTexture
    local artW = (self.diagram.x or 0) + (tex and tex:getWidth() or 300)
    local artH = (self.diagram.y or 0) + (tex and tex:getHeight() or 640)
    local roomH = self.height - FONT_HGT_SMALL - 8
    local scale = math.min(1, (self.width - 8) / artW, roomH / artH)
    self.scale = scale
    self.offsetX = math.floor((self.width - artW * scale) / 2)
    self.offsetY = 4
end

--- Advances the blinking used for removed parts.
function CSV_MechanicsDiagram:stepBlink()
    local step = 0.05 * (UIManager.getMillisSinceLastRender() / 33.3)
    if self.blinkUp then
        self.blink = self.blink + step
        if self.blink >= 1 then self.blink, self.blinkUp = 1, false end
    else
        self.blink = self.blink - step
        if self.blink <= 0.2 then self.blink, self.blinkUp = 0.2, true end
    end
end

--- Draws the base art, the tinted parts, the selection box and the hover name.
function CSV_MechanicsDiagram:render()
    ISPanel.render(self)
    if not self.diagram then
        self:drawTextCentre(getText("UI_CSV_NoDiagram"), self.width / 2, self.height / 2, 0.7, 0.7, 0.7, 1, UIFont.Small)
        return
    end
    self:layout()
    self:stepBlink()
    local s, ox, oy = self.scale, self.offsetX, self.offsetY
    local artX, artY = ox + (self.diagram.x or 0) * s, oy + (self.diagram.y or 0) * s
    if self.baseTexture then
        self:drawTextureScaledUniform(self.baseTexture, artX, artY, s, 1, 1, 1, 1)
    end
    local hover = self:isMouseOver() and self:partAt(self:getMouseX(), self:getMouseY()) or nil
    for _, part in ipairs(self.diagram.parts) do
        local state = self.owner:partStateOf(part.id)
        local color = self.owner:levelColor(Overlay.stateLevel(state))
        local alpha = state == "none" and self.blink or 0.9
        for _, path in ipairs(part.images) do
            local tex = getTexture(path)
            if tex then
                self:drawTextureScaledUniform(tex, artX, artY, s, alpha, color.r, color.g, color.b)
            end
        end
        local box = part.box
        if (part.id == self.owner.selectedPartId or part.id == hover) and box.x and box.x2 then
            local a = part.id == self.owner.selectedPartId and 1 or 0.5
            self:drawRectBorder(ox + box.x * s, oy + box.y * s, (box.x2 - box.x) * s, (box.y2 - box.y) * s, a, 1, 1, 1)
        end
    end
    local name = hover and self.owner:partLabel(hover) or getText("UI_CSV_DiagramHint")
    self:drawTextCentre(name, self.width / 2, self.height - FONT_HGT_SMALL - 4, 0.85, 0.85, 0.85, 1, UIFont.Small)
end

--- Returns the part id under a panel point, or nil.
function CSV_MechanicsDiagram:partAt(x, y)
    if not self.diagram or not self.scale then
        return nil
    end
    return Overlay.hit(self.diagram, (x - self.offsetX) / self.scale, (y - self.offsetY) / self.scale)
end

--- Selects the clicked part.
function CSV_MechanicsDiagram:onMouseDown(x, y)
    local id = self:partAt(x, y)
    if id then
        getSoundManager():playUISound("UISelectListItem")
        self.owner:selectPart(id)
    end
    return true
end
