--- The Starting Vehicle window opened from the character creation screen,
--- laid out like the in-game mechanics window: the vehicle on the left (a 3D
--- view or the mechanics diagram), its name, paint and kind at the top right,
--- the parts in two category lists (doors, bodywork and lights on the right),
--- and the selected part's details with what to install below them. The
--- Vehicle and Trailer tabs edit the car and the trailer it tows; saved builds
--- sit along the top. ADR 0008.
require "ISUI/ISCollapsableWindow"
require "ISUI/ISLabel"
require "ISUI/ISButton"
require "ISUI/ISComboBox"
require "ISUI/ISTextEntryBox"
require "ISUI/ISTickBox"
require "ChooseStartingVehicle/state"
require "ChooseStartingVehicle/runtime"
require "ChooseStartingVehicle/CargoDialog"
require "ChooseStartingVehicle/PartList"
require "ChooseStartingVehicle/VehiclePreview"
require "ChooseStartingVehicle/MechanicsDiagram"
local Build = require("ChooseStartingVehicle/build")
local Catalog = require("ChooseStartingVehicle/catalog")
local Plan = require("ChooseStartingVehicle/plan")
local Overlay = require("ChooseStartingVehicle/overlay")
local PreviewPlan = require("ChooseStartingVehicle/preview-plan")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local PAD = 10
local GAP = 6
local BUTTON_HGT = FONT_HGT_SMALL + 10
local DEFAULT = "__default__"

CSV_VehicleWindow = ISCollapsableWindow:derive("CSV_VehicleWindow")

--- Returns the window size for the current screen.
local function windowSize()
    return math.min(1560, getCore():getScreenWidth() - 40), math.min(940, getCore():getScreenHeight() - 40)
end

--- Hides the cargo editor, whose stack list belongs to the build being replaced.
local function closeCargo()
    if CSV_CargoDialog.instance then
        CSV_CargoDialog.instance:setVisible(false)
    end
end

--- Returns a combo's selected data with the default sentinel as nil.
local function selectedData(combo)
    local data = combo:getOptionData(combo.selected)
    if data == DEFAULT then
        return nil
    end
    return data
end

--- Refills a combo and selects the option holding `value` (nil = default).
local function fillCombo(combo, options, value)
    combo:clear()
    for _, option in ipairs(options) do
        combo:addOptionWithData(option[1], option[2])
    end
    combo.selected = 1
    combo:selectData(value == nil and DEFAULT or value)
end

--- Returns the label shown for an entry in the vehicle combos.
local function entryLabel(entry)
    local tag = ""
    if entry.source == Catalog.SOURCE_KI5 then
        tag = " [KI5]"
    elseif entry.source == Catalog.SOURCE_MOD then
        tag = " [" .. getText("UI_CSV_ModTag") .. "]"
    end
    return entry.displayName .. tag
end

--- Opens (or re-shows) the window; `onChanged()` runs after every edit.
function CSV_VehicleWindow.open(onChanged)
    CSV_State.load()
    local window = CSV_VehicleWindow.instance
    if not window then
        local w, h = windowSize()
        window = CSV_VehicleWindow:new((getCore():getScreenWidth() - w) / 2, (getCore():getScreenHeight() - h) / 2, w, h)
        window:initialise()
        window:addToUIManager()
        CSV_VehicleWindow.instance = window
    end
    window.onChanged = onChanged
    window:refreshSaved()
    window:refreshAll()
    window:setVisible(true)
    window:bringToTop()
    return window
end

--- Creates the window.
function CSV_VehicleWindow:new(x, y, width, height)
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o:setTitle(getText("UI_CSV_WindowTitle"))
    o.sourceFilter = "all"
    o.tab = "vehicle"
    o.view = "3d"
    o.sameForAll = true
    o.selectedPartId = nil
    o.backgroundColor = { r = 0.08, g = 0.08, b = 0.08, a = 1 }
    o.leftWidth = math.max(330, math.min(640, math.floor(width * 0.4)))
    return o
end

--- Adds a small-font label.
function CSV_VehicleWindow:makeLabel(x, y, text, r, g, b)
    local label = ISLabel:new(x, y, BUTTON_HGT, text, r or 1, g or 1, b or 1, 1, UIFont.Small, true)
    label:initialise()
    self:addChild(label)
    return label
end

--- Adds a button sized to its title.
function CSV_VehicleWindow:makeButton(x, y, title, onClick, arg1, arg2)
    local width = getTextManager():MeasureStringX(UIFont.Small, title) + 20
    local button = ISButton:new(x, y, width, BUTTON_HGT, title, self)
    button:setOnClick(onClick, arg1, arg2)
    button:initialise()
    button:instantiate()
    self:addChild(button)
    return button
end

--- Adds a combo box; `onChange(self, combo, arg1, arg2)` runs on selection.
function CSV_VehicleWindow:makeCombo(x, y, w, onChange, arg1, arg2)
    local combo = ISComboBox:new(x, y, w, BUTTON_HGT, self, onChange, arg1, arg2)
    combo:initialise()
    self:addChild(combo)
    return combo
end

--- Builds the saved-builds bar, the left view, the info area, the lists, the
--- detail area and the bottom buttons.
function CSV_VehicleWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    self:setResizable(false)
    local tm = getTextManager()
    local y = self:titleBarHeight() + PAD
    local x = PAD

    local saved = self:makeLabel(x, y, getText("UI_CSV_Saved"))
    self.savedCombo = self:makeCombo(saved:getRight() + GAP, y, 200, nil)
    self.loadButton = self:makeButton(self.savedCombo:getRight() + GAP, y, getText("UI_CSV_Load"), CSV_VehicleWindow.onLoadClicked)
    self.deleteButton = self:makeButton(self.loadButton:getRight() + GAP, y, getText("UI_CSV_Delete"), CSV_VehicleWindow.onDeleteClicked)
    local saveAs = self:makeLabel(self.deleteButton:getRight() + PAD * 2, y, getText("UI_CSV_SaveAs"))
    self.nameEntry = ISTextEntryBox:new("", saveAs:getRight() + GAP, y, 180, BUTTON_HGT)
    self.nameEntry:initialise()
    self.nameEntry:instantiate()
    self:addChild(self.nameEntry)
    self.saveButton = self:makeButton(self.nameEntry:getRight() + GAP, y, getText("UI_CSV_Save"), CSV_VehicleWindow.onSaveClicked)
    self.statusLabel = self:makeLabel(self.saveButton:getRight() + PAD, y, "", 0.6, 0.9, 0.6)
    y = y + BUTTON_HGT + PAD

    local bottomY = self.height - PAD - BUTTON_HGT
    self.contentTop = y

    -- Left column: view switch, the 3D view or the diagram, view options.
    self.view3dButton = self:makeButton(x, y, getText("UI_CSV_View3D"), CSV_VehicleWindow.onViewClicked, "3d")
    self.diagramButton = self:makeButton(self.view3dButton:getRight() + GAP, y, getText("UI_CSV_ViewDiagram"), CSV_VehicleWindow.onViewClicked, "diagram")
    local viewTop = y + BUTTON_HGT + GAP
    local optionsY = bottomY - PAD - BUTTON_HGT
    local viewHeight = optionsY - GAP - viewTop
    self.preview = CSV_VehiclePreview:new(x, viewTop, self.leftWidth, viewHeight)
    self.preview:initialise()
    self:addChild(self.preview)
    self.diagram = CSV_MechanicsDiagram:new(x, viewTop, self.leftWidth, viewHeight, self)
    self.diagram:initialise()
    self:addChild(self.diagram)
    self.resetButton = self:makeButton(x, optionsY, getText("UI_CSV_ResetView"), CSV_VehicleWindow.onResetView)
    self.allModelsTick = ISTickBox:new(self.resetButton:getRight() + PAD, optionsY + 2, 200, BUTTON_HGT, "", self, CSV_VehicleWindow.onAllModelsTick)
    self.allModelsTick:initialise()
    self:addChild(self.allModelsTick)
    self.allModelsTick:addOption(getText("UI_CSV_AllModels"))
    self.allModelsTick:setWidthToFit()

    -- Right column.
    local rx = x + self.leftWidth + PAD * 2
    local rw = self.width - rx - PAD
    self.rightX, self.rightWidth = rx, rw
    self.vehicleTab = self:makeButton(rx, y, getText("UI_CSV_TabVehicle"), CSV_VehicleWindow.onTabClicked, "vehicle")
    self.trailerTab = self:makeButton(self.vehicleTab:getRight() + GAP, y, getText("UI_CSV_TabTrailer"), CSV_VehicleWindow.onTabClicked, "trailer")

    -- Info area: chooser row, then the name and kind (drawn), then paint.
    self.infoY = y + BUTTON_HGT + GAP
    local iy = self.infoY + PAD
    local labelW = math.max(tm:MeasureStringX(UIFont.Small, getText("UI_CSV_Vehicle")), tm:MeasureStringX(UIFont.Small, getText("UI_CSV_Trailer")),
        tm:MeasureStringX(UIFont.Small, getText("UI_CSV_PaintLabel"))) + PAD
    self.chooserLabel = self:makeLabel(rx + PAD, iy, getText("UI_CSV_Vehicle"))
    local showW = tm:MeasureStringX(UIFont.Small, getText("UI_CSV_Show")) + GAP
    local filterW = 150
    self.vehicleCombo = self:makeCombo(rx + PAD + labelW, iy, rw - PAD * 3 - labelW - showW - filterW - PAD, CSV_VehicleWindow.onVehicleChanged)
    self.trailerCombo = self:makeCombo(rx + PAD + labelW, iy, rw - PAD * 2 - labelW, CSV_VehicleWindow.onTrailerChanged)
    self.showLabel = self:makeLabel(self.vehicleCombo:getRight() + PAD, iy, getText("UI_CSV_Show"))
    self.sourceCombo = self:makeCombo(self.showLabel:getRight() + GAP, iy, filterW, CSV_VehicleWindow.onSourceChanged)
    fillCombo(self.sourceCombo, {
        { getText("UI_CSV_ShowAll"), "all" }, { getText("UI_CSV_ShowKI5"), Catalog.SOURCE_KI5 },
        { getText("UI_CSV_ShowGame"), Catalog.SOURCE_GAME }, { getText("UI_CSV_ShowMods"), Catalog.SOURCE_MOD },
    }, "all")
    iy = iy + BUTTON_HGT + GAP
    self.nameY = iy
    iy = iy + FONT_HGT_MEDIUM + FONT_HGT_SMALL + GAP * 2
    self.paintLabel = self:makeLabel(rx + PAD, iy, getText("UI_CSV_PaintLabel"))
    self.paintCombo = self:makeCombo(rx + PAD + labelW, iy, 200, CSV_VehicleWindow.onSkinChanged)
    self.tintLabel = self:makeLabel(self.paintCombo:getRight() + PAD * 2, iy, getText("UI_CSV_Tint"))
    self.tintCombo = self:makeCombo(self.tintLabel:getRight() + GAP, iy, 160, CSV_VehicleWindow.onColorChanged)
    self.infoHeight = iy + BUTTON_HGT + PAD - self.infoY

    -- Detail area at the bottom of the right column.
    local detailHeight = FONT_HGT_MEDIUM + BUTTON_HGT * 2 + GAP * 3 + PAD * 2
    self.detailY = bottomY - PAD - detailHeight
    self.detailHeight = detailHeight
    local dy = self.detailY + PAD + FONT_HGT_MEDIUM + GAP
    self.installLabel = self:makeLabel(rx + PAD, dy, getText("UI_CSV_Install"))
    self.installCombo = self:makeCombo(rx + PAD + labelW, dy, math.min(360, rw - labelW - PAD * 2), CSV_VehicleWindow.onInstallChanged)
    self.sameTick = ISTickBox:new(self.installCombo:getRight() + PAD, dy + 2, 200, BUTTON_HGT, "", self, CSV_VehicleWindow.onSameTick)
    self.sameTick:initialise()
    self:addChild(self.sameTick)
    self.sameTick:addOption("")
    self.sameTick:setSelected(1, true)
    dy = dy + BUTTON_HGT + GAP
    self.cargoLabel = self:makeLabel(rx + PAD, dy, "")
    self.cargoButton = self:makeButton(rx + PAD + labelW + 140, dy, getText("UI_CSV_Edit"), CSV_VehicleWindow.onEditCargo)

    -- The two part lists fill the space between.
    local listY = self.infoY + self.infoHeight + PAD
    local listH = self.detailY - PAD - listY
    local listW = math.floor((rw - PAD) / 2)
    self.leftList = CSV_PartList:new(rx, listY, listW, listH, self)
    self.leftList:initialise()
    self.leftList:instantiate()
    self:addChild(self.leftList)
    self.rightList = CSV_PartList:new(rx + listW + PAD, listY, rw - listW - PAD, listH, self)
    self.rightList:initialise()
    self.rightList:instantiate()
    self:addChild(self.rightList)

    self.clearButton = self:makeButton(PAD, bottomY, getText("UI_CSV_NoVehicle"), CSV_VehicleWindow.onClearClicked)
    self.doneButton = self:makeButton(0, bottomY, getText("UI_CSV_Done"), CSV_VehicleWindow.close)
    self.doneButton:setX(self.width - PAD - self.doneButton:getWidth())
end

--- Returns the build section the current tab edits (nil: no trailer yet).
function CSV_VehicleWindow:section()
    if self.tab == "trailer" then
        return CSV_State.build.trailer
    end
    return CSV_State.build
end

--- Returns the catalog entry the current tab shows, or nil.
function CSV_VehicleWindow:entry()
    local section = self:section()
    return section and CSV_Runtime.entry(section.vehicle) or nil
end

--- Returns the shown entry's part with this id, or nil.
function CSV_VehicleWindow:findPart(partId)
    local entry = self:entry()
    for _, part in ipairs(entry and entry.parts or {}) do
        if part.id == partId then
            return part
        end
    end
    return nil
end

--- Returns the stacks and editor title of the cargo a part holds, or nil.
function CSV_VehicleWindow:cargoFor(part)
    local entry = self:entry()
    if not part or not entry or not part.container then
        return nil
    end
    local roles = Plan.cargoParts(entry.parts)
    local build = CSV_State.build
    if self.tab == "trailer" then
        if roles.trunk == part.id and build.trailer then
            return build.trailer.cargo, getText("UI_CSV_TrailerCargoTitle", entry.displayName)
        end
        return nil
    end
    if roles.trunk == part.id then
        return build.trunk, getText("UI_CSV_TrunkTitle", entry.displayName)
    end
    if roles.glovebox == part.id then
        return build.glovebox, getText("UI_CSV_GloveBoxTitle", entry.displayName)
    end
    return nil
end

--- Returns a part's display state: chosen, none, default or fixed.
function CSV_VehicleWindow:partStateOf(partId)
    local part = self:findPart(partId)
    local section = self:section()
    if not part or not section then
        return "fixed"
    end
    return PreviewPlan.partState(part, Build.partChoice(section, partId))
end

--- Returns a color on the mechanics window's bad-to-good ramp.
function CSV_VehicleWindow:levelColor(level)
    local bad, good = getCore():getBadHighlitedColor(), getCore():getGoodHighlitedColor()
    return Overlay.mix({ r = bad:getR(), g = bad:getG(), b = bad:getB() }, { r = good:getR(), g = good:getG(), b = good:getB() }, level)
end

--- Returns a part's display name.
function CSV_VehicleWindow:partLabel(partId)
    local part = self:findPart(partId)
    return part and part.label or partId
end

--- Returns the item label of an option in a part's slot.
local function optionLabel(slot, itemType)
    for _, option in ipairs(slot and slot.options or {}) do
        if option.itemType == itemType then
            return option.label
        end
    end
    return itemType
end

--- Returns the right-hand text of a part row and its color.
function CSV_VehicleWindow:choiceText(part)
    local section = self:section()
    local state = section and PreviewPlan.partState(part, Build.partChoice(section, part.id)) or "fixed"
    local stacks = self:cargoFor(part)
    local cargo = stacks and #stacks > 0 and getText("UI_CSV_ItemCount", tostring(Build.stackTotal(stacks))) or nil
    if state == "fixed" then
        return cargo or "", 0.6, 0.6, 0.6
    end
    local color = self:levelColor(Overlay.stateLevel(state))
    if state == "none" then
        return getText("UI_CSV_NoneShort"), color.r, color.g, color.b
    end
    if state == "default" then
        return getText("UI_CSV_GameChoice"), color.r, color.g, color.b
    end
    local text = optionLabel(part.slot, Build.partChoice(section, part.id))
    if cargo then
        text = text .. ", " .. cargo
    end
    return text, color.r, color.g, color.b
end

--- Refills the saved builds combo.
function CSV_VehicleWindow:refreshSaved()
    local options = {}
    for _, build in ipairs(CSV_State.builds) do
        options[#options + 1] = { build.name, build.name }
    end
    if #options == 0 then
        options[1] = { getText("UI_CSV_NoSaved"), DEFAULT }
    end
    fillCombo(self.savedCombo, options, options[1][2])
end

--- Refills the vehicle (or trailer) chooser for the current tab.
function CSV_VehicleWindow:refreshChooser()
    local isTrailer = self.tab == "trailer"
    self.chooserLabel:setName(getText(isTrailer and "UI_CSV_Trailer" or "UI_CSV_Vehicle"))
    self.vehicleCombo:setVisible(not isTrailer)
    self.showLabel:setVisible(not isTrailer)
    self.sourceCombo:setVisible(not isTrailer)
    self.trailerCombo:setVisible(isTrailer)
    local build = CSV_State.build
    if isTrailer then
        local options = { { getText("UI_CSV_NoTrailer"), DEFAULT } }
        for _, trailer in ipairs(Catalog.filter(CSV_Runtime.list(), "all", true)) do
            options[#options + 1] = { entryLabel(trailer), trailer.name }
        end
        fillCombo(self.trailerCombo, options, build.trailer and build.trailer.vehicle or nil)
        return
    end
    local options = { { getText("UI_CSV_NoVehicle"), DEFAULT } }
    local found = false
    for _, entry in ipairs(Catalog.filter(CSV_Runtime.list(), self.sourceFilter, false)) do
        options[#options + 1] = { entryLabel(entry), entry.name }
        found = found or entry.name == build.vehicle
    end
    if build.vehicle and not found then
        local entry = Catalog.find(CSV_Runtime.list(), build.vehicle)
        if entry then
            options[#options + 1] = { entryLabel(entry), entry.name }
        end
    end
    fillCombo(self.vehicleCombo, options, build.vehicle)
end

--- Refills the paint and tint combos for the shown entry.
function CSV_VehicleWindow:refreshPaint()
    local entry, section = self:entry(), self:section()
    local paints = { { getText("UI_CSV_GameChoice"), DEFAULT } }
    for i, label in ipairs(entry and entry.skins or {}) do
        paints[#paints + 1] = { label, i - 1 }
    end
    fillCombo(self.paintCombo, paints, section and section.skin)
    local showTint = entry ~= nil and self.tab == "vehicle" and entry.source ~= Catalog.SOURCE_KI5
    self.paintLabel:setVisible(entry ~= nil)
    self.paintCombo:setVisible(entry ~= nil)
    self.tintLabel:setVisible(showTint)
    self.tintCombo:setVisible(showTint)
    if showTint then
        local tints = { { getText("UI_CSV_GameChoice"), DEFAULT } }
        for _, color in ipairs(Plan.COLORS) do
            tints[#tints + 1] = { getText("UI_CSV_Color_" .. color.key), color.key }
        end
        fillCombo(self.tintCombo, tints, section.color)
    end
end

--- Returns category groups with translated headings.
local function labeledGroups(groups)
    for _, group in ipairs(groups) do
        group.label = CSV_Runtime.categoryLabel(group.category)
    end
    return groups
end

--- Refills both part lists and keeps the selection when the part still exists.
function CSV_VehicleWindow:refreshLists()
    local entry = self:entry()
    local columns = Catalog.mechanicsColumns(entry and entry.parts or {})
    self.leftList:setGroups(labeledGroups(columns.left))
    self.rightList:setGroups(labeledGroups(columns.right))
    if not self:findPart(self.selectedPartId) then
        self.selectedPartId = nil
        local first = columns.left[1] or columns.right[1]
        if first then
            for _, part in ipairs(first.parts) do
                if part.slot then
                    self.selectedPartId = part.id
                    break
                end
            end
            self.selectedPartId = self.selectedPartId or first.parts[1].id
        end
    end
    self:markSelection()
end

--- Highlights the selected part in whichever list holds it.
function CSV_VehicleWindow:markSelection()
    if not self.leftList:select(self.selectedPartId) then
        self.leftList.selected = -1
    end
    if not self.rightList:select(self.selectedPartId) then
        self.rightList.selected = -1
    end
end

--- Shows the selected part's install choices and cargo editor.
function CSV_VehicleWindow:refreshDetail()
    local part = self:findPart(self.selectedPartId)
    local section = self:section()
    local slot = part and part.slot
    self.installLabel:setVisible(slot ~= nil)
    self.installCombo:setVisible(slot ~= nil)
    local many = slot ~= nil and #slot.partIds > 1
    self.sameTick:setVisible(many)
    if slot then
        local options = { { getText("UI_CSV_GameChoice"), DEFAULT } }
        if slot.allowNone then
            options[#options + 1] = { getText("UI_CSV_None"), Build.NONE }
        end
        for _, option in ipairs(slot.options) do
            options[#options + 1] = { option.label, option.itemType }
        end
        fillCombo(self.installCombo, options, Build.partChoice(section, part.id))
        if many then
            local text = getText("UI_CSV_SameForAll", slot.label, tostring(#slot.partIds))
            self.sameTick.options[1] = text
            self.sameTick.optionsIndex[1] = text
            self.sameTick:setWidthToFit()
            self.sameTick:setSelected(1, self.sameForAll)
        end
    end
    local stacks = self:cargoFor(part)
    self.cargoLabel:setVisible(stacks ~= nil)
    self.cargoButton:setVisible(stacks ~= nil)
    if stacks then
        self.cargoLabel:setName(getText("UI_CSV_CargoCount", tostring(Build.stackTotal(stacks))))
    end
end

--- Updates the 3D view and the diagram for the current tab.
function CSV_VehicleWindow:refreshView()
    local entry = self:entry()
    self.preview:setVisible(self.view == "3d")
    self.diagram:setVisible(self.view == "diagram")
    self.resetButton:setVisible(self.view == "3d")
    self.allModelsTick:setVisible(self.view == "3d")
    self.preview:show(entry, self:section())
    self.diagram:setEntry(entry)
end

--- Refreshes everything for the current build and tab.
function CSV_VehicleWindow:refreshAll()
    self:refreshChooser()
    self:refreshPaint()
    self:refreshLists()
    self:refreshDetail()
    self:refreshView()
end

--- Draws the frames of the info and detail areas, the vehicle's name and
--- kind, and the selected part's name.
function CSV_VehicleWindow:render()
    ISCollapsableWindow.render(self)
    if self.isCollapsed then
        return
    end
    local rx, rw = self.rightX, self.rightWidth
    local border = self.borderColor
    self:drawRectBorder(rx, self.infoY, rw, self.infoHeight, 1, border.r, border.g, border.b)
    self:drawRectBorder(rx, self.detailY, rw, self.detailHeight, 1, border.r, border.g, border.b)
    local tabX = self.tab == "trailer" and self.trailerTab or self.vehicleTab
    self:drawRect(tabX:getX(), tabX:getBottom(), tabX:getWidth(), 2, 1, 0.9, 0.8, 0.5)

    local entry = self:entry()
    if entry then
        self:drawText(entry.displayName, rx + PAD, self.nameY, 1, 1, 1, 1, UIFont.Medium)
        local kind = getText("UI_CSV_Mechanics", getText("IGUI_VehicleType_" .. tostring(entry.mechanicType or 1)))
        local source = getText(entry.source == Catalog.SOURCE_KI5 and "UI_CSV_SourceKI5" or entry.source == Catalog.SOURCE_GAME and "UI_CSV_SourceGame" or "UI_CSV_SourceMod")
        self:drawText(kind .. "  |  " .. source .. "  |  " .. entry.name, rx + PAD, self.nameY + FONT_HGT_MEDIUM + 2, 0.7, 0.7, 0.7, 1, UIFont.Small)
    else
        local hint = self.tab == "trailer" and "UI_CSV_PickTrailer" or "UI_CSV_PickVehicle"
        self:drawText(getText(hint), rx + PAD, self.nameY + 4, 0.7, 0.7, 0.7, 1, UIFont.Small)
    end

    local part = self:findPart(self.selectedPartId)
    if part then
        self:drawText(part.label, rx + PAD, self.detailY + PAD, 1, 1, 1, 1, UIFont.Medium)
        if not part.slot then
            self:drawText(getText(self:cargoFor(part) and "UI_CSV_StoragePart" or "UI_CSV_FixedPart"), self.installCombo:getX(),
                self.installCombo:getY() + 4, 0.7, 0.7, 0.7, 1, UIFont.Small)
        end
    elseif entry then
        self:drawText(getText("UI_CSV_SelectPart"), rx + PAD, self.detailY + PAD, 0.7, 0.7, 0.7, 1, UIFont.Small)
    end
    if self.view == "3d" and self.preview:isFallback() then
        self:drawText(getText("UI_CSV_PreviewFallback"), self.preview:getX() + 6, self.preview:getY() + 6, 0.9, 0.7, 0.4, 1, UIFont.Small)
    end
end

--- Runs after every edit: remember the build and tell the owner.
function CSV_VehicleWindow:changed()
    CSV_State.saveLast(false)
    self.statusLabel:setName("")
    if self.onChanged then
        self.onChanged()
    end
end

--- Selects a part from a list or the diagram.
function CSV_VehicleWindow:selectPart(partId)
    self.selectedPartId = partId
    self:markSelection()
    self:refreshDetail()
end

--- Switches between the 3D view and the diagram.
function CSV_VehicleWindow:onViewClicked(button, view)
    self.view = view
    self:refreshView()
end

--- Turns the 3D camera back to its start.
function CSV_VehicleWindow:onResetView()
    self.preview:resetView()
end

--- "Show every part model" toggled.
function CSV_VehicleWindow:onAllModelsTick(index, selected)
    self.preview:setShowAll(selected == true, self:entry(), self:section())
end

--- Switches between editing the vehicle and the trailer.
function CSV_VehicleWindow:onTabClicked(button, tab)
    if self.tab ~= tab then
        self.tab = tab
        self.selectedPartId = nil
        closeCargo()
        self:refreshAll()
    end
end

--- Source filter changed.
function CSV_VehicleWindow:onSourceChanged(combo)
    self.sourceFilter = selectedData(combo) or "all"
    self:refreshChooser()
end

--- Vehicle changed: a new build for it, keeping the cargo and trailer.
function CSV_VehicleWindow:onVehicleChanged(combo)
    local old = CSV_State.build
    if selectedData(combo) == old.vehicle then
        return
    end
    local fresh = Build.new(selectedData(combo))
    fresh.trunk = old.trunk
    fresh.glovebox = old.glovebox
    fresh.trailer = old.trailer
    CSV_State.build = fresh
    self.selectedPartId = nil
    closeCargo()
    self:refreshAll()
    self:changed()
end

--- Trailer changed: a fresh trailer section, keeping its cargo.
function CSV_VehicleWindow:onTrailerChanged(combo)
    local name = selectedData(combo)
    local build = CSV_State.build
    if name == (build.trailer and build.trailer.vehicle or nil) then
        return
    end
    closeCargo()
    if name then
        local cargo = build.trailer and build.trailer.cargo or {}
        build.trailer = Build.newTrailer(name)
        build.trailer.cargo = cargo
    else
        build.trailer = nil
    end
    self.selectedPartId = nil
    self:refreshAll()
    self:changed()
end

--- Paint changed.
function CSV_VehicleWindow:onSkinChanged(combo)
    local section = self:section()
    if section then
        section.skin = selectedData(combo)
        self.preview:show(self:entry(), section)
        self:changed()
    end
end

--- Tint changed.
function CSV_VehicleWindow:onColorChanged(combo)
    CSV_State.build.color = selectedData(combo)
    self:changed()
end

--- The selected part's install choice changed.
function CSV_VehicleWindow:onInstallChanged(combo)
    local part = self:findPart(self.selectedPartId)
    local section = self:section()
    if part and part.slot and section then
        Build.setPartChoice(section, part.id, selectedData(combo), part.slot, self.sameForAll)
        self.preview:show(self:entry(), section)
        self:changed()
    end
end

--- "Same for all" toggled.
function CSV_VehicleWindow:onSameTick(index, selected)
    self.sameForAll = selected == true
end

--- Opens the cargo editor for the selected part's cargo.
function CSV_VehicleWindow:onEditCargo()
    local stacks, title = self:cargoFor(self:findPart(self.selectedPartId))
    if not stacks then
        return
    end
    local owner = self
    CSV_CargoDialog.open(title, stacks, function()
        owner:refreshDetail()
        owner:changed()
    end)
end

--- Saves the build under the typed name.
function CSV_VehicleWindow:onSaveClicked()
    local name = string.match(self.nameEntry:getInternalText() or "", "^%s*(.-)%s*$")
    if name == "" or Build.isEmpty(CSV_State.build) then
        self.statusLabel:setName(getText("UI_CSV_NeedNameAndVehicle"))
        return
    end
    CSV_State.saveAs(name)
    self:refreshSaved()
    self.savedCombo:selectData(name)
    self.statusLabel:setName(getText("UI_CSV_SavedAs", name))
end

--- Loads the build picked in the saved combo.
function CSV_VehicleWindow:onLoadClicked()
    local name = selectedData(self.savedCombo)
    if not name then
        return
    end
    closeCargo()
    local notes = CSV_State.loadNamed(name)
    self.nameEntry:setText(name)
    self.selectedPartId = nil
    self:refreshAll()
    self:changed()
    if notes and #notes > 0 then
        self.statusLabel:setName(getText("UI_CSV_SomeDropped", tostring(#notes)))
    end
end

--- Deletes the build picked in the saved combo.
function CSV_VehicleWindow:onDeleteClicked()
    local name = selectedData(self.savedCombo)
    if name then
        CSV_State.deleteNamed(name)
        self:refreshSaved()
    end
end

--- Clears the vehicle so none spawns.
function CSV_VehicleWindow:onClearClicked()
    closeCargo()
    CSV_State.build = Build.new(nil)
    self.tab = "vehicle"
    self.selectedPartId = nil
    self:refreshAll()
    self:changed()
end

--- Hides the window and any cargo editor.
function CSV_VehicleWindow:close()
    self:setVisible(false)
    closeCargo()
end
