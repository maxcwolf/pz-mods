--- Adds a "Starting Vehicle" button to the character creation screen's bottom
--- bar (left of Random) and arms the spawn when Play is pressed.
require "OptionScreens/CharacterCreationMain"
require "ISUI/ISButton"
require "ChooseStartingVehicle/state"
require "ChooseStartingVehicle/runtime"
require "ChooseStartingVehicle/VehicleWindow"
require "ChooseStartingVehicle/spawn"

CSV_Hooks = CSV_Hooks or {}

local UI_BORDER_SPACING = 10
local MAX_TITLE = 36

--- Returns the button text: the chosen vehicle's name, or the default title.
function CSV_Hooks.buttonTitle()
    local build = CSV_State.build
    local entry = build and build.vehicle and CSV_Runtime.entry(build.vehicle)
    if not entry then
        return getText("UI_CSV_Button")
    end
    local name = entry.displayName
    if #name > MAX_TITLE then
        name = string.sub(name, 1, MAX_TITLE - 3) .. "..."
    end
    return getText("UI_CSV_ButtonWith", name)
end

--- Resizes and re-places the button after its title changed.
function CSV_Hooks.layoutButton(screen)
    local button = screen.csvButton
    if not button or not screen.randomButton then
        return
    end
    local title = CSV_Hooks.buttonTitle()
    button:setTitle(title)
    local width = math.max(screen.randomButton:getWidth(), getTextManager():MeasureStringX(UIFont.Small, title) + 20)
    button:setWidth(width)
    button:setX(screen.randomButton:getX() - UI_BORDER_SPACING - width)
end

local originalCreate = CharacterCreationMain.create
--- Adds the button after vanilla builds the screen (not on the split-screen
--- co-op screen, whose Play button never reaches our hook).
function CharacterCreationMain:create()
    originalCreate(self)
    if self.Type == "CoopCharacterCreationMain" then
        return
    end
    CSV_State.load()
    local ref = self.randomButton or self.playButton
    local button = ISButton:new(0, ref.y, ref:getWidth(), ref:getHeight(), getText("UI_CSV_Button"), self, CharacterCreationMain.onCsvButton)
    button:initialise()
    button:instantiate()
    button:setAnchorLeft(false)
    button:setAnchorRight(true)
    button:setAnchorTop(false)
    button:setAnchorBottom(true)
    button:setTooltip(getText("UI_CSV_ButtonTip"))
    self:addChild(button)
    self.csvButton = button
    CSV_Hooks.layoutButton(self)
end

--- Opens the vehicle window.
function CharacterCreationMain:onCsvButton()
    local screen = self
    CSV_VehicleWindow.open(function()
        CSV_Hooks.layoutButton(screen)
    end)
end

local originalOption = CharacterCreationMain.onOptionMouseDown
--- Arms the spawn when Play is pressed and hides the window on Back or Play.
function CharacterCreationMain:onOptionMouseDown(button, x, y)
    if button and (button.internal == "NEXT" or button.internal == "BACK") then
        if button.internal == "NEXT" then
            CSV_State.markPending()
        end
        if CSV_VehicleWindow.instance then
            CSV_VehicleWindow.instance:close()
        end
    end
    return originalOption(self, button, x, y)
end
