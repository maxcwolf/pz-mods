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

--- Reads vanilla's saved builds, splitting each line at its first colon so a
--- build that wears modded clothing with namespaced body locations (keys such
--- as "alicesweaponsling:slingback") is no longer cut short.
function CharacterCreationMain.readSavedOutfitFile()
    local lines = {}
    local reader = getFileReader(CharacterCreationMain.savefile, true)
    if reader then
        local line = reader:readLine()
        while line ~= nil do
            table.insert(lines, line)
            line = reader:readLine()
        end
        reader:close()
    end
    return CSG_Builds.parseOutfitLines(lines)
end

--- Redraws the gear panel and the preview after the selection was replaced.
local function refreshGear(screen)
    if screen.csgPanel then
        screen.csgPanel:rebuild()
    end
    CSG_Preview.refresh(screen)
end

local originalSaveBuild = CharacterCreationMain.saveBuildStep2
--- Saves the current gear under the build name vanilla just saved.
function CharacterCreationMain:saveBuildStep2(button, joypadData, param2)
    originalSaveBuild(self, button, joypadData, param2)
    if button.internal == "CANCEL" then
        return
    end
    local name = button.parent and button.parent.entry and button.parent.entry:getText()
    if name and name ~= "" then
        CSG_State.saveBuild(name)
    end
end

local originalLoadOutfit = CharacterCreationMain.loadOutfit
--- Restores the gear saved with the build vanilla just loaded, when any.
function CharacterCreationMain:loadOutfit(box)
    originalLoadOutfit(self, box)
    local name = box and box.options and box.options[box.selected]
    if name and CSG_State.loadBuild(name) then
        refreshGear(self)
    end
end

local originalDeleteBuild = CharacterCreationMain.deleteBuildStep2
--- Forgets the gear of the build vanilla just deleted.
function CharacterCreationMain:deleteBuildStep2(button, joypadData)
    local name = self.savedBuilds and self.savedBuilds.options[self.savedBuilds.selected]
    originalDeleteBuild(self, button, joypadData)
    if button.internal ~= "NO" and name then
        CSG_State.deleteBuild(name)
    end
end

local originalSetDesc = CharacterCreationAvatar.setSurvivorDesc
--- Renders the chosen gear on the preview; falls back to the vanilla preview
--- when nothing is chosen or the live-character path fails.
function CharacterCreationAvatar:setSurvivorDesc(desc)
    if not CSG_Preview.apply(self, desc) then
        originalSetDesc(self, desc)
    end
end
