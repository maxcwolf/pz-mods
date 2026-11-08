--- The reputation editor window: your level and score with a bar, quick
--- adjust and set-level buttons, recent NPC kills with Undo, and every
--- faction's attitude with Forgive and Make hostile. Pauses the game while open
--- in single player and puts the old speed back on close.
require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "ISUI/ISScrollingListBox"
require "ProjectALife/Records/ALifeRepLevels"
require "ALifeRepEditor/transport"
require "ALifeRepEditor/pause"
require "ALifeRepEditor/score"
require "ALifeRepEditor/look"
require "ALifeRepEditor/faction-rows"

local Transport = ALifeRepEditor.Transport
local Pause = ALifeRepEditor.Pause
local Score = ALifeRepEditor.Score
local Look = ALifeRepEditor.Look
local Rows = ALifeRepEditor.FactionRows

local TM = getTextManager()
local FONT_S = TM:getFontHeight(UIFont.Small)
local FONT_M = TM:getFontHeight(UIFont.Medium)
local FONT_L = TM:getFontHeight(UIFont.Large)
local PAD = 14
local GAP = 6
local BTN_H = FONT_M + 8
local BAR_H = 14
local KILL_ROW = BTN_H + 4
local FACTION_ROW = FONT_M + FONT_S + 16
local FACTION_ROWS_SHOWN = 6
local NUDGES = { -100, -25, -5, 5, 25, 100 }

ARE_RepEditorWindow = ISCollapsableWindow:derive("ARE_RepEditorWindow")

--- Returns the width of text in a font.
local function measure(font, text)
    return TM:MeasureStringX(font, tostring(text))
end

--- Opens the window, or brings it forward if it is already open.
function ARE_RepEditorWindow.open()
    local window = ARE_RepEditorWindow.instance
    if window == nil then
        local width = math.min(720, getCore():getScreenWidth() - 40)
        window = ARE_RepEditorWindow:new(0, 0, width, 400)
        window:initialise()
        ARE_RepEditorWindow.instance = window
    end
    if not window:getIsVisible() or not window.inManager then
        window:setVisible(true)
        window:addToUIManager()
        window.inManager = true
        window:pauseGame()
        window:center()
    end
    window:bringToTop()
    Transport.send("refresh", {})
    return window
end

--- Opens the window when closed and closes it when open.
function ARE_RepEditorWindow.toggle()
    local window = ARE_RepEditorWindow.instance
    if window ~= nil and window.inManager and window:getIsVisible() then
        window:close()
    else
        ARE_RepEditorWindow.open()
    end
end

--- Creates the window.
function ARE_RepEditorWindow:new(x, y, width, height)
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o:setTitle(getText("UI_ALifeRepEditor_Title"))
    o.resizable = false
    o.state = nil
    o.pauseState = nil
    o.killButtons = {}
    o.levelButtons = {}
    return o
end

--- Centers the window on screen.
function ARE_RepEditorWindow:center()
    self:setX(math.max(0, (getCore():getScreenWidth() - self.width) / 2))
    self:setY(math.max(0, (getCore():getScreenHeight() - self.height) / 2))
end

--- Pauses the game in single player, remembering the speed to restore.
function ARE_RepEditorWindow:pauseGame()
    local state, shouldPause = Pause.open(self.pauseState, getGameSpeed(), getGameTime():getTrueMultiplier(),
        Transport.multiplayer())
    self.pauseState = state
    if shouldPause then setGameSpeed(0) end
end

--- Puts the game speed back unless the player changed it meanwhile.
function ARE_RepEditorWindow:resumeGame()
    local restore = Pause.close(self.pauseState, getGameSpeed())
    self.pauseState = nil
    if restore ~= nil then
        setGameSpeed(restore.speed)
        getGameTime():setMultiplier(restore.multiplier)
    end
end

--- Closes the window and resumes the game.
function ARE_RepEditorWindow:close()
    self:resumeGame()
    self:setVisible(false)
    self:removeFromUIManager()
    self.inManager = false
end

--- Adds a medium-font button sized to its title.
function ARE_RepEditorWindow:makeButton(title, onClick, arg1, arg2)
    local width = measure(UIFont.Medium, title) + 20
    local button = ISButton:new(0, 0, width, BTN_H, title, self, onClick)
    button.font = UIFont.Medium
    button.arg1, button.arg2 = arg1, arg2
    button.onclick = function(target, clicked) onClick(target, clicked.arg1, clicked.arg2) end
    button:initialise()
    button:instantiate()
    self:addChild(button)
    return button
end

--- Builds every control; positions are set in layout().
function ARE_RepEditorWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    self.nudgeButtons = {}
    for _, delta in ipairs(NUDGES) do
        self.nudgeButtons[#self.nudgeButtons + 1] = self:makeButton(Score.signed(delta), self.onNudge, delta)
    end
    local levels = ProjectALife and ProjectALife.RepLevels and ProjectALife.RepLevels.rows or {}
    self.levelRows = levels
    self.neutralIndex = Look.neutralIndex(levels)
    for index, row in ipairs(levels) do
        local name = ProjectALife.RepLevels.name(row.id) or row.en
        local button = self:makeButton(name, self.onSetLevel, row.id)
        local color = Look.levelColor(index, self.neutralIndex, #levels)
        button.textColor = { r = color[1], g = color[2], b = color[3], a = 1 }
        self.levelButtons[index] = button
    end
    for slot = 1, 6 do
        local button = self:makeButton(getText("UI_ALifeRepEditor_Undo"), self.onUndo, slot)
        button:setVisible(false)
        self.killButtons[slot] = button
    end
    self.forgiveAllButton = self:makeButton(getText("UI_ALifeRepEditor_ForgiveAll"), self.onForgiveAll)
    self.closeBottom = self:makeButton(getText("UI_ALifeRepEditor_Close"), self.close)
    self:makeFactionList()
    self:layout()
end

--- Creates the scrolling faction list with Forgive and Make hostile drawn on each row.
function ARE_RepEditorWindow:makeFactionList()
    local list = ISScrollingListBox:new(PAD, 0, self.width - PAD * 2, FACTION_ROW * FACTION_ROWS_SHOWN)
    list:initialise()
    list:instantiate()
    list.itemheight = FACTION_ROW
    list.font = UIFont.Medium
    list.drawBorder = true
    list.window = self
    list.doDrawItem = ARE_RepEditorWindow.drawFactionRow
    list.drawSelection = function() end
    list.drawMouseOverHighlight = function() end
    list.onMouseDown = ARE_RepEditorWindow.onFactionListMouseDown
    self:addChild(list)
    self.factionList = list
end

--- Returns the x, y, width of a faction row's two buttons, relative to the row.
function ARE_RepEditorWindow.factionButtons(list)
    local forgiveW = measure(UIFont.Small, getText("UI_ALifeRepEditor_Forgive")) + 16
    local hostileW = measure(UIFont.Small, getText("UI_ALifeRepEditor_Hostile")) + 16
    local right = list:getWidth() - 22
    local height = FONT_S + 8
    local y = math.floor((FACTION_ROW - height) / 2)
    return { x = right - hostileW - forgiveW - GAP, w = forgiveW, y = y, h = height },
        { x = right - hostileW, w = hostileW, y = y, h = height }
end

--- Draws one small button inside the list, dimmed when disabled and lit on hover.
local function drawRowButton(list, rect, top, text, enabled)
    local mouseX, mouseY = list:getMouseX(), list:getMouseY()
    local hover = enabled and list:isMouseOver() and mouseX >= rect.x and mouseX < rect.x + rect.w
        and mouseY >= top + rect.y and mouseY < top + rect.y + rect.h
    local alpha = enabled and (hover and 0.55 or 0.3) or 0.1
    list:drawRect(rect.x, top + rect.y, rect.w, rect.h, alpha, 0.35, 0.35, 0.35)
    list:drawRectBorder(rect.x, top + rect.y, rect.w, rect.h, enabled and 0.8 or 0.3, 0.7, 0.7, 0.7)
    local shade = enabled and 1 or 0.4
    list:drawTextCentre(text, rect.x + rect.w / 2, top + rect.y + 4, shade, shade, shade, 1, UIFont.Small)
end

--- Draws a faction row: name, attitude, reason, and its buttons.
function ARE_RepEditorWindow.drawFactionRow(list, y, item, alt)
    local row = item.item
    if alt then list:drawRect(0, y, list:getWidth(), FACTION_ROW - 1, 0.12, 0.5, 0.5, 0.5) end
    local forgive, hostile = ARE_RepEditorWindow.factionButtons(list)
    local nameWidth = math.floor((forgive.x - 20) * 0.55)
    list:drawText(Look.fit(row.name, nameWidth, function(t) return measure(UIFont.Medium, t) end),
        10, y + 6, 1, 1, 1, 1, UIFont.Medium)
    local color = Rows.color(row.status)
    list:drawText(Rows.statusText(row.status), 10 + nameWidth + 10, y + 6, color[1], color[2], color[3], 1, UIFont.Medium)
    local reason = Rows.reasonText(row)
    if (tonumber(row.grudges) or 0) > 0 then
        reason = reason .. "; " .. getText("UI_ALifeRepEditor_Grudges", tostring(row.grudges))
    end
    list:drawText(Look.fit(reason, forgive.x - 20, function(t) return measure(UIFont.Small, t) end),
        10, y + 8 + FONT_M, 0.7, 0.7, 0.7, 1, UIFont.Small)
    drawRowButton(list, forgive, y, getText("UI_ALifeRepEditor_Forgive"), Rows.forgivable(row))
    drawRowButton(list, hostile, y, getText("UI_ALifeRepEditor_Hostile"), row.status ~= "hostile")
    return y + FACTION_ROW
end

--- Turns a click on a faction row into Forgive or Make hostile.
function ARE_RepEditorWindow.onFactionListMouseDown(list, x, y)
    local index = list:rowAt(x, y)
    local item = index > 0 and list.items[index] or nil
    if item == nil then return end
    local localY = y - list:topOfItem(index)
    local forgive, hostile = ARE_RepEditorWindow.factionButtons(list)
    local row = item.item
    local inside = function(rect) return x >= rect.x and x < rect.x + rect.w and localY >= rect.y and localY < rect.y + rect.h end
    if inside(forgive) and Rows.forgivable(row) then
        getSoundManager():playUISound("UIActivateButton")
        Transport.send("forgive", { faction = row.id })
    elseif inside(hostile) and row.status ~= "hostile" then
        getSoundManager():playUISound("UIActivateButton")
        Transport.send("makeHostile", { faction = row.id })
    end
end

--- Places every control for the current state and sizes the window to fit.
function ARE_RepEditorWindow:layout()
    local inner = self.width - PAD * 2
    local y = self:titleBarHeight() + PAD
    self.headerY = y
    y = y + FONT_L + 4 + FONT_S + GAP
    self.barY = y
    y = y + BAR_H + PAD

    self.nudgeY = y
    local labelWidth = math.max(measure(UIFont.Medium, getText("UI_ALifeRepEditor_Nudge")),
        measure(UIFont.Medium, getText("UI_ALifeRepEditor_SetLevel"))) + 12
    self.labelWidth = labelWidth
    local x = PAD + labelWidth
    for _, button in ipairs(self.nudgeButtons) do
        button:setX(x)
        button:setY(y)
        x = x + button.width + GAP
    end
    y = y + BTN_H + GAP

    self.levelY = y
    local widths = {}
    for index, button in ipairs(self.levelButtons) do widths[index] = button.width end
    local places, rowCount = Look.wrap(widths, inner - labelWidth, GAP)
    for index, button in ipairs(self.levelButtons) do
        button:setX(PAD + labelWidth + places[index].x)
        button:setY(y + places[index].row * (BTN_H + GAP))
    end
    y = y + rowCount * (BTN_H + GAP) + PAD

    self.killsY = y
    y = y + FONT_M + 2 + FONT_S + GAP
    local kills = self.state ~= nil and self.state.kills or {}
    self.killRowsY = y
    for slot, button in ipairs(self.killButtons) do
        local entry = kills[slot]
        button:setX(self.width - PAD - button.width)
        button:setY(y + (slot - 1) * KILL_ROW)
        button:setVisible(entry ~= nil and entry.undone ~= true)
    end
    y = y + math.max(1, #kills) * KILL_ROW + PAD

    self.factionsY = y
    self.forgiveAllButton:setX(self.width - PAD - self.forgiveAllButton.width)
    self.forgiveAllButton:setY(y - 2)
    y = y + BTN_H + 2
    self.factionList:setY(y)
    y = y + self.factionList.height + PAD

    self.footerY = y
    self.closeBottom:setX(self.width - PAD - self.closeBottom.width)
    self.closeBottom:setY(y)
    y = y + BTN_H + PAD
    self:setHeight(y)
end

--- Takes a fresh state from the server and refreshes the window.
function ARE_RepEditorWindow:setState(state)
    self.state = state
    local list = self.factionList
    list:clear()
    for _, row in ipairs(state.factions or {}) do list:addItem(row.name, row) end
    local current = state.personal ~= nil and state.personal.level or nil
    for index, button in ipairs(self.levelButtons) do
        local row = self.levelRows[index]
        local selected = row ~= nil and row.id == current
        button.backgroundColor = selected and { r = 0.35, g = 0.35, b = 0.35, a = 1 } or { r = 0, g = 0, b = 0, a = 1 }
        button.borderColor = selected and { r = 1, g = 1, b = 1, a = 1 } or { r = 0.7, g = 0.7, b = 0.7, a = 1 }
    end
    local enabled = state.personal ~= nil
    for _, button in ipairs(self.nudgeButtons) do button:setEnable(enabled) end
    for _, button in ipairs(self.levelButtons) do button:setEnable(enabled) end
    local top = self.y
    self:layout()
    self:setY(math.max(0, math.min(top, getCore():getScreenHeight() - self.height)))
end

--- Draws the header, score bar, section titles, kill lines and the footer message.
function ARE_RepEditorWindow:render()
    ISCollapsableWindow.render(self)
    if self.isCollapsed then return end
    local state = self.state
    if state == nil then
        self:drawText(getText("UI_ALifeRepEditor_Loading"), PAD, self.headerY, 1, 1, 1, 1, UIFont.Large)
        return
    end
    self:renderHeader(state)
    self:drawText(getText("UI_ALifeRepEditor_Nudge"), PAD, self.nudgeY + 4, 0.85, 0.85, 0.85, 1, UIFont.Medium)
    self:drawText(getText("UI_ALifeRepEditor_SetLevel"), PAD, self.levelY + 4, 0.85, 0.85, 0.85, 1, UIFont.Medium)
    self:renderKills(state)
    self:drawText(getText("UI_ALifeRepEditor_Factions"), PAD, self.factionsY, 1, 1, 1, 1, UIFont.Medium)
    self:renderFooter(state)
end

--- Draws the level name, score and the colored bar with a marker.
function ARE_RepEditorWindow:renderHeader(state)
    local low, high = state.scoreMin or -1000, state.scoreMax or 1000
    local levels = self.levelRows
    if state.personal == nil then
        self:drawText(getText("UI_ALifeRepEditor_PersonalOff"), PAD, self.headerY, 0.8, 0.8, 0.8, 1, UIFont.Medium)
        return
    end
    local index = Score.levelIndexAt(levels, state.personal.score)
    for i, row in ipairs(levels) do
        if row.id == state.personal.level then index = i end
    end
    local color = Look.levelColor(index, self.neutralIndex, #levels)
    local name = levels[index] ~= nil and (ProjectALife.RepLevels.name(levels[index].id) or levels[index].en) or "?"
    self:drawText(name, PAD, self.headerY, color[1], color[2], color[3], 1, UIFont.Large)
    self:drawText(getText("UI_ALifeRepEditor_Score", tostring(state.personal.score), tostring(low), tostring(high)),
        PAD, self.headerY + FONT_L + 4, 0.75, 0.75, 0.75, 1, UIFont.Small)
    local width = self.width - PAD * 2
    for i, row in ipairs(levels) do
        local bandLow, bandHigh = Score.rangeOf(levels, i, high)
        local x1 = PAD + Score.fraction(bandLow, low, high) * width
        local x2 = PAD + Score.fraction(bandHigh + 1, low, high) * width
        local c = Look.levelColor(i, self.neutralIndex, #levels)
        self:drawRect(x1, self.barY, math.max(1, x2 - x1 - 1), BAR_H, i == index and 0.9 or 0.45, c[1], c[2], c[3])
    end
    self:drawRectBorder(PAD, self.barY, width, BAR_H, 0.8, 0.6, 0.6, 0.6)
    local marker = PAD + Score.fraction(state.personal.score, low, high) * width
    self:drawRect(marker - 2, self.barY - 4, 4, BAR_H + 8, 1, 1, 1, 1)
end

--- Draws the recent kills section.
function ARE_RepEditorWindow:renderKills(state)
    self:drawText(getText("UI_ALifeRepEditor_Kills"), PAD, self.killsY, 1, 1, 1, 1, UIFont.Medium)
    self:drawText(getText("UI_ALifeRepEditor_KillsHint"), PAD, self.killsY + FONT_M + 2, 0.7, 0.7, 0.7, 1, UIFont.Small)
    local kills = state.kills or {}
    if #kills == 0 then
        self:drawText(getText("UI_ALifeRepEditor_NoKills"), PAD, self.killRowsY + 4, 0.6, 0.6, 0.6, 1, UIFont.Small)
        return
    end
    local textWidth = self.width - PAD * 3 - self.killButtons[1].width
    for slot, entry in ipairs(kills) do
        local y = self.killRowsY + (slot - 1) * KILL_ROW + math.floor((BTN_H - FONT_S) / 2)
        local text = entry.text
        if entry.undone then text = text .. " (" .. getText("UI_ALifeRepEditor_Undone") .. ")" end
        local shade = entry.undone and 0.5 or 0.95
        self:drawText(Look.fit(text, textWidth, function(t) return measure(UIFont.Small, t) end),
            PAD, y, shade, shade, shade, 1, UIFont.Small)
    end
end

--- Draws the last action's result and the paused note.
function ARE_RepEditorWindow:renderFooter(state)
    local y = self.footerY + 2
    local width = self.width - PAD * 3 - self.closeBottom.width
    if state.message ~= nil and state.message ~= "" then
        local r, g, b = 0.55, 0.9, 0.55
        if state.failed then r, g, b = 0.95, 0.5, 0.45 end
        self:drawText(Look.fit(state.message, width, function(t) return measure(UIFont.Small, t) end),
            PAD, y, r, g, b, 1, UIFont.Small)
    end
    if self.pauseState ~= nil and self.pauseState.paused then
        self:drawText(getText("UI_ALifeRepEditor_Paused"), PAD, y + FONT_S + 2, 0.6, 0.6, 0.6, 1, UIFont.Small)
    end
end

--- Sends a score nudge.
function ARE_RepEditorWindow:onNudge(delta)
    Transport.send("nudge", { delta = delta })
end

--- Sends a jump to a level.
function ARE_RepEditorWindow:onSetLevel(levelId)
    Transport.send("setLevel", { level = levelId })
end

--- Sends an undo for the kill in a slot.
function ARE_RepEditorWindow:onUndo(slot)
    local entry = self.state ~= nil and self.state.kills ~= nil and self.state.kills[slot] or nil
    if entry ~= nil then Transport.send("undoKill", { id = entry.id }) end
end

--- Sends forgive-everyone.
function ARE_RepEditorWindow:onForgiveAll()
    Transport.send("forgiveAll", {})
end

Transport.listen(function(state)
    local window = ARE_RepEditorWindow.instance
    if window ~= nil and type(state) == "table" then window:setState(state) end
end)

return ARE_RepEditorWindow
