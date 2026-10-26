--- Wires the gear panel into the vanilla character creation screen.
require "OptionScreens/CharacterCreationMain"
require "OptionScreens/CharacterCreationAvatar"
require "ChooseStartingGear/GearPanel"
require "ChooseStartingGear/spawn"
require "ChooseStartingGear/preview"

CSG_Hooks = CSG_Hooks or {}

--- Creates the gear panel inside the clothing panel on first use.
local function ensurePanel(screen)
    if screen.csgPanel then
        return screen.csgPanel
    end
    local panel = CSG_GearPanel:new(0, 0, screen.clothingPanel:getWidth(), screen)
    panel:initialise()
    screen.clothingPanel:addChild(panel)
    screen.csgPanel = panel
    return panel
end

local originalArrange = CharacterCreationMain.arrangeClothingUI
--- Places the gear panel under the clothing rows whenever they are laid out.
function CharacterCreationMain:arrangeClothingUI()
    originalArrange(self)
    if not self.clothingPanel or not self.clothingCombo then
        return
    end
    local panel = ensurePanel(self)
    panel:setVisible(true)
    panel:relayout(self.yOffset)
end

local originalRemove = CharacterCreationMain.removeAllClothingWidgets
--- Hides the gear panel while vanilla rebuilds the clothing rows.
function CharacterCreationMain:removeAllClothingWidgets()
    originalRemove(self)
    if self.csgPanel then
        self.csgPanel:setVisible(false)
    end
end

local originalOption = CharacterCreationMain.onOptionMouseDown
--- Saves the selection and arms the spawn hook when Play is pressed.
function CharacterCreationMain:onOptionMouseDown(button, x, y)
    if button and button.internal == "NEXT" then
        CSG_State.markPending()
    end
    return originalOption(self, button, x, y)
end

local originalSetDesc = CharacterCreationAvatar.setSurvivorDesc
--- Renders the chosen gear on the preview; falls back to the vanilla preview
--- when nothing is chosen or the live-character path fails.
function CharacterCreationAvatar:setSurvivorDesc(desc)
    if not CSG_Preview.apply(self, desc) then
        originalSetDesc(self, desc)
    end
end
