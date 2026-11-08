--- The small on-screen button that opens the editor. It shows your current
--- A-Life level, can be dragged anywhere, and right-click hides it (the
--- world right-click menu brings it back). Its spot is saved between games.
require "ISUI/ISPanel"
require "ProjectALife/Records/ALifeRepLevels"
require "ALifeRepEditor/hud-prefs"
require "ALifeRepEditor/look"
require "ALifeRepEditor/RepEditorWindow"

local HudPrefs = ALifeRepEditor.HudPrefs
local Look = ALifeRepEditor.Look

local TM = getTextManager()
local FONT_S = TM:getFontHeight(UIFont.Small)
local FILE = "ALifeRepEditor_hud.txt"
local DRAG_SLOP = 4

ARE_HudButton = ISPanel:derive("ARE_HudButton")

--- Reads the saved button spot, or nil when there is none.
function ARE_HudButton.loadPrefs()
    local reader = getFileReader(FILE, false)
    if reader == nil then return nil end
    local line = reader:readLine()
    reader:close()
    return HudPrefs.parse(line)
end

--- Saves the button spot and visibility.
function ARE_HudButton.savePrefs(prefs)
    local writer = getFileWriter(FILE, true, false)
    if writer == nil then return end
    writer:write(HudPrefs.format(prefs))
    writer:close()
end

--- Returns the label: "Rep: <level>" from what A-Life last sent this client.
function ARE_HudButton.label()
    local store = ProjectALife and ProjectALife.StatusStore or nil
    local personal = store ~= nil and type(store.reputation) == "table" and store.reputation.personal or nil
    local levels = ProjectALife and ProjectALife.RepLevels or nil
    local name = personal ~= nil and levels ~= nil and levels.name(personal.level) or nil
    if name == nil then return getText("UI_ALifeRepEditor_HudPlain"), nil end
    return getText("UI_ALifeRepEditor_Hud", name), personal.level
end

--- Creates the button panel.
function ARE_HudButton:new(x, y)
    local o = ISPanel.new(self, x, y, 90, FONT_S + 8)
    o.background = false
    o.dragging = false
    return o
end

--- Sizes the button to its label, keeping the right edge put while it sits under the clock.
function ARE_HudButton:fitWidth()
    local text, levelId = ARE_HudButton.label()
    local width = TM:MeasureStringX(UIFont.Small, text) + 16
    if width ~= self.width then
        if self.anchorRight then self:setX(HudPrefs.keepRightEdge(self:getX(), self.width, width)) end
        self:setWidth(width)
    end
    return text, levelId
end

--- Returns the vanilla watch clock's rectangle, or nil when the game has none.
function ARE_HudButton.clockRect()
    if type(UIManager) == "nil" or UIManager.getClock == nil then return nil end
    local clock = UIManager.getClock()
    if clock == nil then return nil end
    return { x = clock:getX(), y = clock:getY(), width = clock:getWidth(), height = clock:getHeight() }
end

--- Draws the label with a border in the level's color, resizing to fit.
function ARE_HudButton:render()
    local player = getPlayer()
    if player == nil or player:isDead() then return end
    local text, levelId = self:fitWidth()
    local levels = ProjectALife and ProjectALife.RepLevels or nil
    local color = Look.NEUTRAL
    if levels ~= nil and levelId ~= nil and levels.indexOf(levelId) ~= nil then
        color = Look.levelColor(levels.indexOf(levelId), Look.neutralIndex(levels.rows), #levels.rows)
    end
    local hover = self:isMouseOver()
    self:drawRect(0, 0, self.width, self.height, hover and 0.85 or 0.6, 0.05, 0.05, 0.05)
    self:drawRectBorder(0, 0, self.width, self.height, 1, color[1], color[2], color[3])
    self:drawTextCentre(text, self.width / 2, 4, 1, 1, 1, hover and 1 or 0.85, UIFont.Small)
end

--- Starts a click or a drag.
function ARE_HudButton:onMouseDown(x, y)
    self.pressX, self.pressY = getMouseX(), getMouseY()
    self.startX, self.startY = self:getX(), self:getY()
    self.pressed, self.dragging = true, false
    self:setCapture(true)
    return true
end

--- Moves the button once the mouse has travelled past the drag threshold.
function ARE_HudButton:onMouseMove(dx, dy)
    if not self.pressed then return end
    local moveX, moveY = getMouseX() - self.pressX, getMouseY() - self.pressY
    if not self.dragging and math.abs(moveX) + math.abs(moveY) > DRAG_SLOP then self.dragging = true end
    if self.dragging then
        self.anchorRight = false
        local x, y = HudPrefs.fit(self.startX + moveX, self.startY + moveY, self.width, self.height,
            getCore():getScreenWidth(), getCore():getScreenHeight())
        self:setX(x)
        self:setY(y)
    end
end

--- Keeps dragging when the mouse leaves the button.
function ARE_HudButton:onMouseMoveOutside(dx, dy)
    self:onMouseMove(dx, dy)
end

--- Opens the editor on a click, or saves the new spot after a drag.
function ARE_HudButton:onMouseUp(x, y)
    if not self.pressed then return end
    self.pressed = false
    self:setCapture(false)
    if self.dragging then
        self.dragging = false
        ARE_HudButton.savePrefs({ x = self:getX(), y = self:getY(), hidden = false })
        return
    end
    getSoundManager():playUISound("UIActivateButton")
    ARE_RepEditorWindow.toggle()
end

--- Ends a press that was released outside the button.
function ARE_HudButton:onMouseUpOutside(x, y)
    self:onMouseUp(x, y)
end

--- Offers to hide the button.
function ARE_HudButton:onRightMouseUp(x, y)
    local context = ISContextMenu.get(0, getMouseX(), getMouseY())
    context:addOption(getText("UI_ALifeRepEditor_HudHide"), self, ARE_HudButton.hide)
    return true
end

--- Hides the button and remembers that.
function ARE_HudButton:hide()
    self:setVisible(false)
    self:removeFromUIManager()
    ARE_HudButton.savePrefs({ x = self:getX(), y = self:getY(), hidden = true })
end

--- Shows the button, creating it at its saved or default spot.
function ARE_HudButton.show(forced)
    local prefs = ARE_HudButton.loadPrefs()
    if prefs ~= nil and prefs.hidden and not forced then return nil end
    local button = ARE_HudButton.instance
    if button == nil then
        button = ARE_HudButton:new(0, 0)
        button:initialise()
        ARE_HudButton.instance = button
    end
    local screenWidth, screenHeight = getCore():getScreenWidth(), getCore():getScreenHeight()
    button.anchorRight = false
    button:fitWidth()
    local x, y
    if prefs ~= nil then
        x, y = prefs.x, prefs.y
    else
        x, y = HudPrefs.defaultPosition(button.width, screenWidth, ARE_HudButton.clockRect())
        button.anchorRight = true
    end
    x, y = HudPrefs.fit(x, y, button.width, button.height, screenWidth, screenHeight)
    button:setX(x)
    button:setY(y)
    button:setVisible(true)
    button:addToUIManager()
    if forced then ARE_HudButton.savePrefs({ x = x, y = y, hidden = false }) end
    return button
end

--- Returns true when the button is hidden.
function ARE_HudButton.isHidden()
    local button = ARE_HudButton.instance
    return button == nil or not button:getIsVisible()
end

if type(Events) == "table" and Events.OnGameStart ~= nil then
    Events.OnGameStart.Add(function() ARE_HudButton.show(false) end)
end

return ARE_HudButton
