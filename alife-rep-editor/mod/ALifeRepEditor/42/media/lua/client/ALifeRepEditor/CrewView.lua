--- The Crew tab: pick someone in your crew, set A-Life's nine companion
--- skills and their strength and accuracy, see what they're holding and
--- carrying, and give them any item in the game (weapons are held, clothing
--- is worn).
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISScrollingListBox"
require "ISUI/ISTextEntryBox"
require "ALifeRepEditor/crew-rows"
require "ALifeRepEditor/item-info"
require "ALifeRepEditor/look"

local Rows = ALifeRepEditor.CrewRows
local Info = ALifeRepEditor.ItemInfo
local Look = ALifeRepEditor.Look

local TM = getTextManager()
local FONT_S = TM:getFontHeight(UIFont.Small)
local FONT_M = TM:getFontHeight(UIFont.Medium)
local FONT_L = TM:getFontHeight(UIFont.Large)
local GAP = 6
local PAD = 14
local BTN_H = FONT_M + 8
local ROW_H = FONT_S + 16
local LIST_ROWS = 4
local AMMO = { 30, 120 }

ARE_CrewView = ISPanel:derive("ARE_CrewView")

--- Returns the width of text in a font.
local function measure(font, text)
    return TM:MeasureStringX(font, tostring(text))
end

--- Returns the levels the grid shows: the nine skills, then strength and accuracy.
function ARE_CrewView.entries()
    local entries = {}
    for _, id in ipairs(Rows.SKILLS) do
        entries[#entries + 1] = { kind = "skill", id = id, label = getText("UI_ALifeRepEditor_Skill_" .. id), max = Rows.SKILL_MAX }
    end
    for _, id in ipairs(Rows.RATINGS) do
        entries[#entries + 1] = { kind = "rating", id = id, label = getText("UI_ALifeRepEditor_Rating_" .. id), max = Rows.RATING_MAX }
    end
    return entries
end

--- Creates the panel; window is the editor window that sends commands.
function ARE_CrewView:new(x, y, width, window)
    local o = ISPanel.new(self, x, y, width, 100)
    o.background = false
    o.window = window
    o.state = nil
    o.selectedUid = nil
    o.memberButtons = {}
    o.memberKey = nil
    o.query = ""
    return o
end

--- Adds a medium-font button sized to its title that calls onClick(self, arg).
function ARE_CrewView:makeButton(title, onClick, arg)
    local button = ISButton:new(0, 0, measure(UIFont.Medium, title) + 20, BTN_H, title, self, onClick)
    button.font = UIFont.Medium
    button.arg1 = arg
    button.onclick = function(target, clicked) onClick(target, clicked.arg1) end
    button:initialise()
    button:instantiate()
    self:addChild(button)
    return button
end

--- Makes a scrolling list whose rows draw their own small buttons.
function ARE_CrewView:makeList(draw, mouseDown)
    local list = ISScrollingListBox:new(0, 0, self.width, ROW_H * LIST_ROWS)
    list:initialise()
    list:instantiate()
    list.itemheight = ROW_H
    list.font = UIFont.Small
    list.drawBorder = true
    list.view = self
    list.doDrawItem = draw
    list.drawSelection = function() end
    list.drawMouseOverHighlight = function() end
    list.onMouseDown = mouseDown
    self:addChild(list)
    return list
end

--- Builds the skill buttons, gear lists and item search.
function ARE_CrewView:createChildren()
    self.entries = ARE_CrewView.entries()
    self.minusButtons, self.plusButtons = {}, {}
    for index, entry in ipairs(self.entries) do
        self.minusButtons[index] = self:makeButton("-", self.onStep, { entry = entry, delta = -1 })
        self.plusButtons[index] = self:makeButton("+", self.onStep, { entry = entry, delta = 1 })
    end
    self.maxButton = self:makeButton(getText("UI_ALifeRepEditor_MaxAll"), self.onMaxAll)
    self.ammoButtons = {}
    for _, rounds in ipairs(AMMO) do
        self.ammoButtons[#self.ammoButtons + 1] = self:makeButton(getText("UI_ALifeRepEditor_Ammo", tostring(rounds)), self.onAmmo, rounds)
    end
    self.carryList = self:makeList(ARE_CrewView.drawCarryRow, ARE_CrewView.onCarryMouseDown)
    local search = ISTextEntryBox:new("", 0, 0, math.min(320, self.width), FONT_M + 8)
    search:initialise()
    search:instantiate()
    if search.setClearButton then search:setClearButton(true) end
    if search.setPlaceholderText then search:setPlaceholderText(getText("UI_ALifeRepEditor_ItemSearch")) end
    search.onTextChange = function() self:onSearch() end
    self:addChild(search)
    self.searchBox = search
    self.resultList = self:makeList(ARE_CrewView.drawResultRow, ARE_CrewView.onResultMouseDown)
    self:layout()
end

--- Makes one button per crew member, rebuilding them when the crew changes.
function ARE_CrewView:ensureMemberButtons(members)
    local parts = {}
    for _, member in ipairs(members) do parts[#parts + 1] = member.uid .. "=" .. member.name end
    local key = table.concat(parts, ";")
    if key == self.memberKey then return end
    for _, button in ipairs(self.memberButtons) do
        button:setVisible(false)
        if self.removeChild then self:removeChild(button) end
    end
    self.memberButtons = {}
    for index, member in ipairs(members) do
        self.memberButtons[index] = self:makeButton(member.name, self.onPick, member.uid)
    end
    self.memberKey = key
end

--- Returns the picked crew member's details from the last state, or nil.
function ARE_CrewView:member()
    local member = self.state ~= nil and self.state.crewMember or nil
    if type(member) ~= "table" or member.uid ~= self.selectedUid then return nil end
    return member
end

--- Returns the cell width of the two-column level grid.
function ARE_CrewView:cellWidth()
    return math.floor((self.width - GAP * 2) / 2)
end

--- Places the controls for the current width and sets the panel's height.
function ARE_CrewView:layout()
    local y = 0
    local widths = {}
    for index, button in ipairs(self.memberButtons) do widths[index] = button.width end
    local places, rowCount = Look.wrap(widths, self.width, GAP)
    for index, button in ipairs(self.memberButtons) do
        button:setX(places[index].x)
        button:setY(y + places[index].row * (BTN_H + GAP))
    end
    y = y + (#self.memberButtons > 0 and rowCount * (BTN_H + GAP) or FONT_M + GAP) + GAP

    self.headerY = y
    y = y + FONT_L + 4 + FONT_S + GAP

    self.skillsY = y
    self.maxButton:setX(self.width - self.maxButton.width)
    self.maxButton:setY(y)
    y = y + BTN_H + GAP
    local cell = self:cellWidth()
    self.cells = {}
    local skillCount = #Rows.SKILLS
    local skillRows = math.ceil(skillCount / 2)
    for index, _ in ipairs(self.entries) do
        local column, row, top
        if index <= skillCount then
            column, row, top = (index - 1) % 2, math.floor((index - 1) / 2), y
        else
            column, row, top = (index - skillCount - 1) % 2, 0, y + skillRows * (BTN_H + GAP) + FONT_M + GAP * 2
        end
        local x = column * (cell + GAP * 2)
        local cellY = top + row * (BTN_H + GAP)
        local plus, minus = self.plusButtons[index], self.minusButtons[index]
        plus:setX(x + cell - plus.width)
        plus:setY(cellY)
        minus:setX(plus.x - GAP - minus.width)
        minus:setY(cellY)
        self.cells[index] = { x = x, y = cellY, right = minus.x - GAP }
    end
    self.fightingY = y + skillRows * (BTN_H + GAP) + GAP
    y = self.fightingY + FONT_M + GAP + BTN_H + GAP + PAD

    self.gearY = y
    local x = self.width
    for index = #self.ammoButtons, 1, -1 do
        local button = self.ammoButtons[index]
        x = x - button.width
        button:setX(x)
        button:setY(y)
        x = x - GAP
    end
    y = y + BTN_H + GAP
    self.carryList:setX(0)
    self.carryList:setY(y)
    self.carryList:setWidth(self.width)
    y = y + self.carryList.height + PAD

    self.giveY = y
    y = y + FONT_M + GAP
    self.searchBox:setX(0)
    self.searchBox:setY(y)
    y = y + self.searchBox.height + GAP
    self.resultList:setX(0)
    self.resultList:setY(y)
    self.resultList:setWidth(self.width)
    y = y + self.resultList.height
    self:setHeight(y)
end

--- Takes a fresh state: keeps the picked member, or takes the one the server picked.
function ARE_CrewView:setState(state)
    self.state = state
    local members = type(state.crewMembers) == "table" and state.crewMembers or {}
    self:ensureMemberButtons(members)
    self.selectedUid = state.crewPick
    for index, button in ipairs(self.memberButtons) do
        local picked = members[index] ~= nil and members[index].uid == self.selectedUid
        button.backgroundColor = picked and { r = 0.35, g = 0.35, b = 0.35, a = 1 } or { r = 0, g = 0, b = 0, a = 1 }
        button.borderColor = picked and { r = 1, g = 1, b = 1, a = 1 } or { r = 0.6, g = 0.6, b = 0.6, a = 1 }
    end
    local member = self:member()
    local levels = member ~= nil and self:levels(member) or {}
    for index, entry in ipairs(self.entries) do
        local level = levels[index]
        self.minusButtons[index]:setEnable(level ~= nil and level > 0)
        self.plusButtons[index]:setEnable(level ~= nil and level < entry.max)
    end
    self.maxButton:setEnable(member ~= nil)
    local gun = member ~= nil and member.loaded and type(member.weapon) == "table" and member.weapon.gun == true
    for _, button in ipairs(self.ammoButtons) do button:setEnable(gun) end
    self.carryList:clear()
    for _, row in ipairs(member ~= nil and member.items or {}) do self.carryList:addItem(row.name, row) end
    self:refreshResults()
    self:layout()
end

--- Returns the picked member's level for each grid entry.
function ARE_CrewView:levels(member)
    local levels = {}
    for index, entry in ipairs(self.entries) do
        local source = entry.kind == "skill" and member.skills or member.ratings
        levels[index] = type(source) == "table" and tonumber(source[entry.id]) or nil
    end
    return levels
end

--- Fills the result list from the search text.
function ARE_CrewView:refreshResults()
    self.resultList:clear()
    self.results = Rows.search(Info.catalog(), self.query)
    for _, item in ipairs(self.results) do self.resultList:addItem(item.name, item) end
end

--- Searches the game's items as the search text changes.
function ARE_CrewView:onSearch()
    self.query = self.searchBox:getText() or ""
    self:refreshResults()
end

--- Returns true when the picked member's body is loaded, so gear can change.
function ARE_CrewView:canHand()
    local member = self:member()
    return member ~= nil and member.loaded == true
end

--- Returns the small buttons drawn on a row as { label, action } pairs.
function ARE_CrewView.rowActions(list, row)
    if list == list.view.resultList then
        local action = Rows.giveAction(row.kind)
        if action == "equip" then return { { getText("UI_ALifeRepEditor_Hold"), "give" } } end
        if action == "wear" then return { { getText("UI_ALifeRepEditor_Wear"), "give" } } end
        return { { getText("UI_ALifeRepEditor_Give"), "give" }, { getText("UI_ALifeRepEditor_GiveTen"), "giveTen" } }
    end
    local actions = {}
    if row.weapon and not row.equipped then actions[#actions + 1] = { getText("UI_ALifeRepEditor_Hold"), "equip" } end
    actions[#actions + 1] = { getText(row.worn and "UI_ALifeRepEditor_TakeOff" or "UI_ALifeRepEditor_Remove"), "remove" }
    return actions
end

--- Returns the rectangles of a row's buttons, right-aligned, relative to the row.
function ARE_CrewView.rowButtons(list, row)
    local rects = {}
    local right = list:getWidth() - 22
    local height = FONT_S + 6
    local y = math.floor((ROW_H - height) / 2)
    local actions = ARE_CrewView.rowActions(list, row)
    for index = #actions, 1, -1 do
        local width = measure(UIFont.Small, actions[index][1]) + 16
        right = right - width
        rects[index] = { x = right, y = y, w = width, h = height, label = actions[index][1], action = actions[index][2] }
        right = right - GAP
    end
    return rects, right
end

--- Draws one small button inside a list, dimmed when disabled and lit on hover.
local function drawRowButton(list, rect, top, enabled)
    local mouseX, mouseY = list:getMouseX(), list:getMouseY()
    local hover = enabled and list:isMouseOver() and mouseX >= rect.x and mouseX < rect.x + rect.w
        and mouseY >= top + rect.y and mouseY < top + rect.y + rect.h
    list:drawRect(rect.x, top + rect.y, rect.w, rect.h, enabled and (hover and 0.55 or 0.3) or 0.1, 0.35, 0.35, 0.35)
    list:drawRectBorder(rect.x, top + rect.y, rect.w, rect.h, enabled and 0.8 or 0.3, 0.7, 0.7, 0.7)
    local shade = enabled and 1 or 0.4
    list:drawTextCentre(rect.label, rect.x + rect.w / 2, top + rect.y + 3, shade, shade, shade, 1, UIFont.Small)
end

--- Draws a carried item: name, count or what it's for, and Hold / Remove.
function ARE_CrewView.drawCarryRow(list, y, item, alt)
    local row = item.item
    if alt then list:drawRect(0, y, list:getWidth(), ROW_H - 1, 0.12, 0.5, 0.5, 0.5) end
    local rects, left = ARE_CrewView.rowButtons(list, row)
    local text = row.name
    if (tonumber(row.count) or 1) > 1 then text = text .. "  x" .. tostring(row.count) end
    if row.equipped then text = text .. "  (" .. getText("UI_ALifeRepEditor_TagHolding") .. ")" end
    if row.worn then text = text .. "  (" .. getText("UI_ALifeRepEditor_TagWearing") .. ")" end
    local shade = row.equipped and 1 or 0.85
    list:drawText(Look.fit(text, left - 16, function(t) return measure(UIFont.Small, t) end), 10, y + 8, shade, shade, shade, 1, UIFont.Small)
    local enabled = list.view:canHand()
    for _, rect in ipairs(rects) do drawRowButton(list, rect, y, enabled) end
    return y + ROW_H
end

--- Draws a search result: name, kind and type, and its give button(s).
function ARE_CrewView.drawResultRow(list, y, item, alt)
    local row = item.item
    if alt then list:drawRect(0, y, list:getWidth(), ROW_H - 1, 0.12, 0.5, 0.5, 0.5) end
    local rects, left = ARE_CrewView.rowButtons(list, row)
    local kind = row.kind == "weapon" and (row.firearm and "UI_ALifeRepEditor_KindGun" or "UI_ALifeRepEditor_KindWeapon")
        or row.kind == "clothing" and "UI_ALifeRepEditor_KindClothing" or "UI_ALifeRepEditor_KindItem"
    local text = row.name .. "  -  " .. getText(kind) .. "  -  " .. row.type
    list:drawText(Look.fit(text, left - 16, function(t) return measure(UIFont.Small, t) end), 10, y + 8, 0.9, 0.9, 0.9, 1, UIFont.Small)
    local enabled = list.view:canHand()
    for _, rect in ipairs(rects) do drawRowButton(list, rect, y, enabled) end
    return y + ROW_H
end

--- Returns the button under a click in a list, with its row, or nil.
local function clickedButton(list, x, y)
    local index = list:rowAt(x, y)
    local item = index > 0 and list.items[index] or nil
    if item == nil then return nil end
    local localY = y - list:topOfItem(index)
    for _, rect in ipairs((ARE_CrewView.rowButtons(list, item.item))) do
        if x >= rect.x and x < rect.x + rect.w and localY >= rect.y and localY < rect.y + rect.h then return rect, item.item end
    end
    return nil
end

--- Turns a click on a carried item's button into Hold or Remove.
function ARE_CrewView.onCarryMouseDown(list, x, y)
    local rect, row = clickedButton(list, x, y)
    if rect == nil or not list.view:canHand() then return end
    getSoundManager():playUISound("UIActivateButton")
    list.view:send(rect.action == "equip" and "crewEquip" or "crewRemove", { id = row.id })
end

--- Turns a click on a search result's button into Give, Give 10, Hold or Wear.
function ARE_CrewView.onResultMouseDown(list, x, y)
    local rect, row = clickedButton(list, x, y)
    if rect == nil or not list.view:canHand() then return end
    getSoundManager():playUISound("UIActivateButton")
    list.view:send("crewGive", { item = row.type, count = rect.action == "giveTen" and 10 or 1 })
end

--- Sends a command about the picked crew member.
function ARE_CrewView:send(command, args)
    if self.selectedUid == nil then return end
    local payload = args or {}
    payload.crew = self.selectedUid
    self.window:send(command, payload)
end

--- Picks a crew member and asks the server for their details.
function ARE_CrewView:onPick(uid)
    self.selectedUid = uid
    self.window:send("refresh", { crew = uid })
end

--- Moves one skill or fighting stat by one.
function ARE_CrewView:onStep(arg)
    local entry = arg.entry
    if entry.kind == "skill" then
        self:send("crewSkill", { skill = entry.id, delta = arg.delta })
    else
        self:send("crewRating", { rating = entry.id, delta = arg.delta })
    end
end

--- Sets every skill and fighting stat to the top.
function ARE_CrewView:onMaxAll()
    self:send("crewMaxAll")
end

--- Adds spare rounds for the held gun.
function ARE_CrewView:onAmmo(rounds)
    self:send("crewAmmo", { rounds = rounds })
end

--- Draws the headings, the picked member's name, each level, the held weapon and empty-list notes.
function ARE_CrewView:render()
    ISPanel.render(self)
    local state = self.state
    if state == nil or state.unavailable then return end
    if state.crewOn ~= true then
        self:drawText(getText("UI_ALifeRepEditor_CrewOff"), 0, 0, 0.8, 0.8, 0.8, 1, UIFont.Medium)
        return
    end
    local member = self:member()
    if member == nil then
        self:drawText(getText("UI_ALifeRepEditor_CrewNone"), 0, 0, 0.8, 0.8, 0.8, 1, UIFont.Medium)
        return
    end
    local width = self.width
    self:drawText(Look.fit(member.name, width, function(t) return measure(UIFont.Large, t) end), 0, self.headerY, 1, 1, 1, 1, UIFont.Large)
    local note = member.loaded and getText("UI_ALifeRepEditor_CrewHint")
        or getText("UI_ALifeRepEditor_CrewAway", member.name)
    self:drawText(Look.fit(note, width, function(t) return measure(UIFont.Small, t) end), 0, self.headerY + FONT_L + 4,
        0.7, 0.7, 0.7, 1, UIFont.Small)

    self:drawText(getText("UI_ALifeRepEditor_CrewSkills"), 0, self.skillsY + 4, 1, 1, 1, 1, UIFont.Medium)
    self:drawText(getText("UI_ALifeRepEditor_CrewFighting"), 0, self.fightingY, 1, 1, 1, 1, UIFont.Medium)
    local levels = self:levels(member)
    for index, entry in ipairs(self.entries) do
        local cell = self.cells[index]
        local level = levels[index]
        local value = (level ~= nil and tostring(level) or "-") .. "/" .. tostring(entry.max)
        local valueWidth = measure(UIFont.Medium, value)
        self:drawText(value, cell.right - valueWidth, cell.y + 4, 0.55, 0.85, 1, 1, UIFont.Medium)
        self:drawText(Look.fit(entry.label, cell.right - valueWidth - cell.x - GAP * 2,
            function(t) return measure(UIFont.Medium, t) end), cell.x, cell.y + 4, 0.9, 0.9, 0.9, 1, UIFont.Medium)
        local fill = level ~= nil and level / entry.max or 0
        self:drawRect(cell.x, cell.y + BTN_H - 3, (cell.right - cell.x) * fill, 2, 0.8, 0.45, 0.7, 0.95)
    end

    self:drawText(getText("UI_ALifeRepEditor_CrewGear"), 0, self.gearY + 4, 1, 1, 1, 1, UIFont.Medium)
    local weapon = member.weapon
    local holding
    if type(weapon) ~= "table" then
        holding = getText("UI_ALifeRepEditor_HoldingNothing")
    elseif weapon.gun then
        holding = getText("UI_ALifeRepEditor_HoldingGun", weapon.name, tostring(weapon.loaded or 0), tostring(weapon.spare or 0))
    else
        holding = getText("UI_ALifeRepEditor_Holding", weapon.name)
    end
    local gearLabel = measure(UIFont.Medium, getText("UI_ALifeRepEditor_CrewGear")) + PAD
    local ammoLeft = self.ammoButtons[1] ~= nil and self.ammoButtons[1].x or width
    self:drawText(Look.fit(holding, ammoLeft - gearLabel - PAD, function(t) return measure(UIFont.Small, t) end),
        gearLabel, self.gearY + 6, 0.8, 0.8, 0.8, 1, UIFont.Small)
    if #(member.items or {}) == 0 then
        self:drawText(getText("UI_ALifeRepEditor_CarryNone"), 10, self.carryList.y + 8, 0.6, 0.6, 0.6, 1, UIFont.Small)
    end
    self:drawText(getText("UI_ALifeRepEditor_GiveTitle"), 0, self.giveY, 1, 1, 1, 1, UIFont.Medium)
    if #self.query >= Rows.SEARCH_MIN and #(self.results or {}) == 0 then
        self:drawText(getText("UI_ALifeRepEditor_ItemNoMatch"), 10, self.resultList.y + 8, 0.6, 0.6, 0.6, 1, UIFont.Small)
    end
end

return ARE_CrewView
