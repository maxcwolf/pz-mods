--- The People tab: a searchable list of every NPC with an opinion of you,
--- and for the one you pick, their opinion bar with Adjust and Set to
--- buttons, plus Forget me, Calm down, Make hostile, Join my crew and, for
--- someone in your crew, Skills and gear (which opens the Crew tab).
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISScrollingListBox"
require "ISUI/ISTextEntryBox"
require "ALifeRepEditor/opinion-bands"
require "ALifeRepEditor/people-rows"
require "ALifeRepEditor/score"
require "ALifeRepEditor/look"

local Bands = ALifeRepEditor.OpinionBands
local Rows = ALifeRepEditor.PeopleRows
local Score = ALifeRepEditor.Score
local Look = ALifeRepEditor.Look

local TM = getTextManager()
local FONT_S = TM:getFontHeight(UIFont.Small)
local FONT_M = TM:getFontHeight(UIFont.Medium)
local FONT_L = TM:getFontHeight(UIFont.Large)
local GAP = 6
local PAD = 14
local BTN_H = FONT_M + 8
local BAR_H = 14
local ROW_H = FONT_M + FONT_S + 16
local ROWS_SHOWN = 5
local NUDGES = { -25, -5, 5, 25 }

ARE_PeopleView = ISPanel:derive("ARE_PeopleView")

--- Returns the width of text in a font.
local function measure(font, text)
    return TM:MeasureStringX(font, tostring(text))
end

--- Creates the panel; window is the editor window that sends commands.
function ARE_PeopleView:new(x, y, width, window)
    local o = ISPanel.new(self, x, y, width, 100)
    o.background = false
    o.window = window
    o.state = nil
    o.selectedUid = nil
    o.query = ""
    o.bandButtons = {}
    o.bandKey = nil
    return o
end

--- Adds a medium-font button sized to its title that calls onClick(self, arg).
function ARE_PeopleView:makeButton(title, onClick, arg)
    local button = ISButton:new(0, 0, measure(UIFont.Medium, title) + 20, BTN_H, title, self, onClick)
    button.font = UIFont.Medium
    button.arg1 = arg
    button.onclick = function(target, clicked) onClick(target, clicked.arg1) end
    button:initialise()
    button:instantiate()
    self:addChild(button)
    return button
end

--- Builds the search box, the list and the edit buttons.
function ARE_PeopleView:createChildren()
    local search = ISTextEntryBox:new("", 0, 0, math.min(320, self.width), FONT_M + 8)
    search:initialise()
    search:instantiate()
    if search.setClearButton then search:setClearButton(true) end
    if search.setPlaceholderText then search:setPlaceholderText(getText("UI_ALifeRepEditor_PeopleSearch")) end
    search.onTextChange = function() self:onSearch() end
    self:addChild(search)
    self.searchBox = search

    local list = ISScrollingListBox:new(0, 0, self.width, ROW_H * ROWS_SHOWN)
    list:initialise()
    list:instantiate()
    list.itemheight = ROW_H
    list.font = UIFont.Medium
    list.drawBorder = true
    list.view = self
    list.doDrawItem = ARE_PeopleView.drawPersonRow
    list.drawSelection = function() end
    list.drawMouseOverHighlight = function() end
    list.onMouseDown = ARE_PeopleView.onListMouseDown
    self:addChild(list)
    self.list = list

    self.nudgeButtons = {}
    for _, delta in ipairs(NUDGES) do
        self.nudgeButtons[#self.nudgeButtons + 1] = self:makeButton(Score.signed(delta), self.onNudge, delta)
    end
    self.forgetButton = self:makeButton(getText("UI_ALifeRepEditor_Forget"), self.onForget)
    self.calmButton = self:makeButton(getText("UI_ALifeRepEditor_Calm"), self.onCalm)
    self.hostileButton = self:makeButton(getText("UI_ALifeRepEditor_Hostile"), self.onHostile)
    self.crewButton = self:makeButton(getText("UI_ALifeRepEditor_JoinCrew"), self.onCrew)
    self.crewButton:setWidth(math.max(measure(UIFont.Medium, getText("UI_ALifeRepEditor_JoinCrew")),
        measure(UIFont.Medium, getText("UI_ALifeRepEditor_LeaveCrew"))) + 20)
    self.gearButton = self:makeButton(getText("UI_ALifeRepEditor_SkillsAndGear"), self.onGear)
    self:ensureBandButtons(Bands.fromLabels(nil))
    self:layout()
end

--- Returns the opinion bands from the last state, or A-Life's usual ones.
function ARE_PeopleView:bands()
    local bands = self.state ~= nil and self.state.opinionBands or nil
    return type(bands) == "table" and #bands > 0 and bands or Bands.fromLabels(nil)
end

--- Makes one Set to button per opinion band, rebuilding them if the bands change.
function ARE_PeopleView:ensureBandButtons(bands)
    local parts = {}
    for _, band in ipairs(bands) do parts[#parts + 1] = tostring(band.min) .. "=" .. band.label end
    local key = table.concat(parts, ";")
    if key == self.bandKey then return end
    for _, button in ipairs(self.bandButtons) do
        button:setVisible(false)
        if self.removeChild then self:removeChild(button) end
    end
    self.bandButtons = {}
    local neutral = Look.neutralIndex(bands)
    for index, band in ipairs(bands) do
        local button = self:makeButton(band.label, self.onSetBand, index)
        local color = Look.levelColor(index, neutral, #bands)
        button.textColor = { r = color[1], g = color[2], b = color[3], a = 1 }
        self.bandButtons[index] = button
    end
    self.bandKey = key
end

--- Returns the selected person's entry from the last state, or nil.
function ARE_PeopleView:selected()
    local people = self.state ~= nil and self.state.people or nil
    local index = Rows.indexOf(people, self.selectedUid)
    return index ~= nil and people[index] or nil
end

--- Places the controls for the current width and sets the panel's height.
function ARE_PeopleView:layout()
    local y = 0
    self.searchBox:setX(0)
    self.searchBox:setY(y)
    y = y + self.searchBox.height + GAP
    self.list:setX(0)
    self.list:setY(y)
    self.list:setWidth(self.width)
    y = y + self.list.height + PAD

    self.headerY = y
    y = y + FONT_L + 4 + FONT_S + GAP
    self.barY = y
    y = y + BAR_H + GAP
    self.noteY = y
    y = y + (FONT_S + 2) * 2 + GAP

    self.labelWidth = math.max(measure(UIFont.Medium, getText("UI_ALifeRepEditor_Nudge")),
        measure(UIFont.Medium, getText("UI_ALifeRepEditor_SetTo"))) + 12
    self.nudgeY = y
    local x = self.labelWidth
    for _, button in ipairs(self.nudgeButtons) do
        button:setX(x)
        button:setY(y)
        x = x + button.width + GAP
    end
    y = y + BTN_H + GAP

    self.bandY = y
    local widths = {}
    for index, button in ipairs(self.bandButtons) do widths[index] = button.width end
    local places, rowCount = Look.wrap(widths, self.width - self.labelWidth, GAP)
    for index, button in ipairs(self.bandButtons) do
        button:setX(self.labelWidth + places[index].x)
        button:setY(y + places[index].row * (BTN_H + GAP))
    end
    y = y + rowCount * (BTN_H + GAP) + GAP

    local actions = { self.forgetButton, self.calmButton, self.hostileButton, self.crewButton, self.gearButton }
    widths = {}
    for index, button in ipairs(actions) do widths[index] = button.width end
    places, rowCount = Look.wrap(widths, self.width - self.labelWidth, GAP)
    for index, button in ipairs(actions) do
        button:setX(self.labelWidth + places[index].x)
        button:setY(y + places[index].row * (BTN_H + GAP))
    end
    y = y + rowCount * (BTN_H + GAP) - GAP
    self:setHeight(y)
end

--- Rebuilds the list from the last state and the search text.
function ARE_PeopleView:refreshList()
    local list = self.list
    list:clear()
    local shown = Rows.filter(self.state ~= nil and self.state.people or {}, self.query)
    for _, person in ipairs(shown) do list:addItem(person.name, person) end
    self.shownCount = #shown
end

--- Takes a fresh state: keeps the selection, or picks the person the state focuses on.
function ARE_PeopleView:setState(state)
    self.state = state
    if type(state.focus) == "string" then self.selectedUid = state.focus end
    if self.selectedUid ~= nil and Rows.indexOf(state.people, self.selectedUid) == nil then self.selectedUid = nil end
    self:ensureBandButtons(self:bands())
    self:refreshList()
    if type(state.focus) == "string" then self:reveal(state.focus) end
    local person = self:selected()
    local enabled = person ~= nil and state.peopleOn == true
    for _, button in ipairs(self.nudgeButtons) do button:setEnable(enabled) end
    for _, button in ipairs(self.bandButtons) do button:setEnable(enabled) end
    self.forgetButton:setEnable(enabled and person.met == true)
    self.calmButton:setEnable(person ~= nil and (person.hostile == true or person.wary == true))
    self.hostileButton:setEnable(person ~= nil and person.hostile ~= true)
    local inCrew = person ~= nil and person.crew == "yours"
    self.crewButton:setTitle(getText(inCrew and "UI_ALifeRepEditor_LeaveCrew" or "UI_ALifeRepEditor_JoinCrew"))
    self.crewButton:setEnable(person ~= nil and state.crewOn == true and person.crew ~= "other")
    self.gearButton:setEnable(inCrew and state.crewOn == true)
    self:layout()
end

--- Scrolls the list so a person's row shows.
function ARE_PeopleView:reveal(uid)
    for index, item in ipairs(self.list.items or {}) do
        if item.item.uid == uid then
            if self.list.ensureVisible then self.list:ensureVisible(index) end
            return index
        end
    end
    return nil
end

--- Selects a person by uid and refreshes the buttons.
function ARE_PeopleView:select(uid)
    self.selectedUid = uid
    if self.state ~= nil then
        self.state.focus = nil
        self:setState(self.state)
    end
    self:reveal(uid)
end

--- Filters the list as the search text changes.
function ARE_PeopleView:onSearch()
    self.query = self.searchBox:getText() or ""
    self:refreshList()
end

--- Draws one person: name and opinion on top, faction and stance below.
function ARE_PeopleView.drawPersonRow(list, y, item, alt)
    local view = list.view
    local person = item.item
    local selected = person.uid == view.selectedUid
    if selected then
        list:drawRect(0, y, list:getWidth(), ROW_H - 1, 0.35, 0.3, 0.45, 0.65)
    elseif alt then
        list:drawRect(0, y, list:getWidth(), ROW_H - 1, 0.12, 0.5, 0.5, 0.5)
    end
    local bands = view:bands()
    local index = Bands.indexAt(bands, person.value)
    local color = Look.levelColor(index, Look.neutralIndex(bands), #bands)
    local opinion = getText("UI_ALifeRepEditor_Opinion", person.label, Rows.signed(person.value))
    local opinionWidth = measure(UIFont.Medium, opinion)
    local right = list:getWidth() - 22
    list:drawText(Look.fit(person.name, right - opinionWidth - 30, function(t) return measure(UIFont.Medium, t) end),
        10, y + 6, 1, 1, 1, 1, UIFont.Medium)
    list:drawText(opinion, right - opinionWidth, y + 6, color[1], color[2], color[3], 1, UIFont.Medium)
    local subtitle = Rows.subtitle(person)
    if person.hostile then subtitle = subtitle .. "; " .. getText("UI_ALifeRepEditor_Grudge") end
    list:drawText(Look.fit(subtitle, right - 10, function(t) return measure(UIFont.Small, t) end),
        10, y + 8 + FONT_M, 0.7, 0.7, 0.7, 1, UIFont.Small)
    return y + ROW_H
end

--- Selects the clicked person.
function ARE_PeopleView.onListMouseDown(list, x, y)
    local index = list:rowAt(x, y)
    local item = index > 0 and list.items[index] or nil
    if item == nil then return end
    getSoundManager():playUISound("UIActivateButton")
    list.view:select(item.item.uid)
end

--- Draws the count, the selected person's header, bar and notes, and the row labels.
function ARE_PeopleView:render()
    ISPanel.render(self)
    local state = self.state
    if state == nil or state.unavailable then return end
    if state.peopleOn ~= true then
        self:drawText(getText("UI_ALifeRepEditor_PeopleOff"), 0, self.headerY, 0.8, 0.8, 0.8, 1, UIFont.Medium)
        return
    end
    local count = getText("UI_ALifeRepEditor_PeopleCount", tostring(#(state.people or {})))
    if state.crewOn == true then
        count = count .. "    " .. getText("UI_ALifeRepEditor_CrewCount", tostring(state.crewSize or 0), tostring(state.crewMax or 5))
    end
    self:drawText(count, self.searchBox.width + PAD, 4, 0.7, 0.7, 0.7, 1, UIFont.Small)
    if #(state.people or {}) == 0 then
        self:drawText(getText("UI_ALifeRepEditor_PeopleNone"), 10, self.list.y + 8, 0.6, 0.6, 0.6, 1, UIFont.Small)
    elseif (self.shownCount or 0) == 0 then
        self:drawText(getText("UI_ALifeRepEditor_PeopleNoMatch"), 10, self.list.y + 8, 0.6, 0.6, 0.6, 1, UIFont.Small)
    end
    self:drawText(getText("UI_ALifeRepEditor_Nudge"), 0, self.nudgeY + 4, 0.85, 0.85, 0.85, 1, UIFont.Medium)
    self:drawText(getText("UI_ALifeRepEditor_SetTo"), 0, self.bandY + 4, 0.85, 0.85, 0.85, 1, UIFont.Medium)
    local person = self:selected()
    if person == nil then
        self:drawText(getText("UI_ALifeRepEditor_PeoplePick"), 0, self.headerY, 0.75, 0.75, 0.75, 1, UIFont.Medium)
        return
    end
    self:renderPerson(state, person)
end

--- Draws the selected person's name, standing, opinion bar and notes.
function ARE_PeopleView:renderPerson(state, person)
    local bands = self:bands()
    local neutral = Look.neutralIndex(bands)
    local low, high = tonumber(state.opinionMin) or Bands.MIN, tonumber(state.opinionMax) or Bands.MAX
    local index = Bands.indexAt(bands, person.value)
    local color = Look.levelColor(index, neutral, #bands)
    local width = self.width
    self:drawText(Look.fit(person.name, width, function(t) return measure(UIFont.Large, t) end),
        0, self.headerY, 1, 1, 1, 1, UIFont.Large)
    local nameWidth = measure(UIFont.Large, person.name)
    local opinion = getText("UI_ALifeRepEditor_Opinion", person.label, Rows.signed(person.value))
    if nameWidth + measure(UIFont.Medium, opinion) + PAD * 2 < width then
        self:drawText(opinion, nameWidth + PAD, self.headerY + FONT_L - FONT_M, color[1], color[2], color[3], 1, UIFont.Medium)
    end
    local parts = { Rows.subtitle(person) }
    if not person.met then parts[#parts + 1] = getText("UI_ALifeRepEditor_Stranger") end
    if person.hostile then parts[#parts + 1] = getText("UI_ALifeRepEditor_Grudge") end
    if person.wary then parts[#parts + 1] = getText("UI_ALifeRepEditor_Wary") end
    local subtitle = ""
    for _, part in ipairs(parts) do
        if part ~= "" then subtitle = subtitle == "" and part or (subtitle .. "; " .. part) end
    end
    self:drawText(Look.fit(subtitle, width, function(t) return measure(UIFont.Small, t) end),
        0, self.headerY + FONT_L + 4, 0.75, 0.75, 0.75, 1, UIFont.Small)

    for i = 1, #bands do
        local bandLow, bandHigh = Bands.rangeOf(bands, i, high)
        local x1 = Score.fraction(bandLow, low, high) * width
        local x2 = Score.fraction(bandHigh + 1, low, high) * width
        local c = Look.levelColor(i, neutral, #bands)
        self:drawRect(x1, self.barY, math.max(1, x2 - x1 - 1), BAR_H, i == index and 0.9 or 0.45, c[1], c[2], c[3])
    end
    self:drawRectBorder(0, self.barY, width, BAR_H, 0.8, 0.6, 0.6, 0.6)
    local base = Score.fraction(person.base, low, high) * width
    self:drawRect(base - 1, self.barY + BAR_H - 5, 2, 7, 0.9, 0.2, 0.2, 0.2)
    local marker = Score.fraction(person.value, low, high) * width
    self:drawRect(marker - 2, self.barY - 4, 4, BAR_H + 8, 1, 1, 1, 1)

    local y = self.noteY
    local decay = tonumber(state.opinionDecay)
    if decay ~= nil and decay > 0 and person.value ~= person.base then
        local drift = getText("UI_ALifeRepEditor_Drift", Bands.labelAt(bands, person.base), Rows.signed(person.base),
            tostring(decay))
        self:drawText(Look.fit(drift, width, function(t) return measure(UIFont.Small, t) end),
            0, y, 0.65, 0.65, 0.65, 1, UIFont.Small)
        y = y + FONT_S + 2
    end
    if type(person.why) == "string" and person.why ~= "" then
        self:drawText(Look.fit(getText("UI_ALifeRepEditor_Why", person.why), width,
            function(t) return measure(UIFont.Small, t) end), 0, y, 0.65, 0.65, 0.65, 1, UIFont.Small)
    end
end

--- Sends a command about the selected person.
function ARE_PeopleView:sendForSelected(command, args)
    if self.selectedUid == nil then return end
    local payload = args or {}
    payload.uid = self.selectedUid
    self.window:send(command, payload)
end

--- Moves the selected person's opinion.
function ARE_PeopleView:onNudge(delta)
    self:sendForSelected("personNudge", { delta = delta })
end

--- Jumps the selected person's opinion to a band.
function ARE_PeopleView:onSetBand(index)
    self:sendForSelected("personSetBand", { band = index })
end

--- Asks the selected person to join the player's crew, or to leave it.
function ARE_PeopleView:onCrew()
    local person = self:selected()
    self:sendForSelected(person ~= nil and person.crew == "yours" and "personLeaveCrew" or "personJoinCrew")
end

--- Opens the Crew tab on the selected person.
function ARE_PeopleView:onGear()
    if self.selectedUid ~= nil and self.window.openCrew ~= nil then self.window:openCrew(self.selectedUid) end
end

--- Makes the selected person forget the player.
function ARE_PeopleView:onForget()
    self:sendForSelected("personForget")
end

--- Ends the selected person's personal grudge.
function ARE_PeopleView:onCalm()
    self:sendForSelected("personCalm")
end

--- Makes the selected person personally hostile.
function ARE_PeopleView:onHostile()
    self:sendForSelected("personHostile")
end

return ARE_PeopleView
