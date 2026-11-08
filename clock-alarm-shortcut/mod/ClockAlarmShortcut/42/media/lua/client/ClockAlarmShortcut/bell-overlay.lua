--- An invisible UI element laid over the alarm bell on the HUD clock. The
--- clock is a Java element that ignores right-clicks, so this catches them
--- and opens the vanilla Set Alarm Time dialog. Left-clicks pass straight
--- through, so the clock still turns the alarm on and off as before.
---
--- The overlay sits at the back of the UI list: any window dragged over the
--- clock gets its clicks first, and only clicks that nothing else wants
--- reach the bell.
require "ISUI/ISUIElement"
require "ISUI/ISAlarmClockDialog"
require "ClockAlarmShortcut/bell-layout"
require "ClockAlarmShortcut/alarm-finder"

local BellLayout = ClockAlarmShortcut_BellLayout
local AlarmFinder = ClockAlarmShortcut_AlarmFinder

ClockAlarmShortcut_BellOverlay = ISUIElement:derive("ClockAlarmShortcut_BellOverlay")
local Overlay = ClockAlarmShortcut_BellOverlay

--- Bell rectangles per clock size, measured once from the game's textures.
Overlay.rects = {}

--- Reads one texture's size, or nil when the game has no such texture.
local function textureSize(path)
    local texture = getTexture(path)
    if texture == nil then return nil end
    return texture:getWidth(), texture:getHeight()
end

--- Measures the clock textures for one size, falling back to known sizes.
function Overlay.measure(key)
    local fallback = BellLayout.FALLBACK_SIZES[key]
    local paths = BellLayout.texturePaths(key)
    local digit = textureSize(paths.digit)
    local colon = textureSize(paths.colon)
    local am = textureSize(paths.am)
    local bellWidth, bellHeight = textureSize(paths.bell)
    return {
        digit = digit or fallback.digit,
        colon = colon or fallback.colon,
        am = am or fallback.am,
        bellWidth = bellWidth or fallback.bellWidth,
        bellHeight = bellHeight or fallback.bellHeight,
    }
end

--- Returns the bell rectangle for one clock size, caching it.
function Overlay.rectFor(key)
    if Overlay.rects[key] == nil then
        Overlay.rects[key] = BellLayout.bellRect(BellLayout.SPACING[key], Overlay.measure(key))
    end
    return Overlay.rects[key]
end

--- Creates the overlay with no size; it sizes itself to the bell each frame.
function Overlay:new()
    local o = ISUIElement.new(self, 0, 0, 0, 0)
    o.anchorLeft = true
    o.anchorTop = true
    o.rightPressed = false
    o.dialog = nil
    return o
end

--- Moves and sizes the overlay to cover the bell, or shrinks it to nothing
--- while the clock is hidden.
function Overlay:syncToClock()
    local clock = UIManager.getClock()
    if clock == nil or not clock:isVisible() then
        self:setWidth(0)
        self:setHeight(0)
        return
    end
    local rect = Overlay.rectFor(BellLayout.sizeKey(getCore():getOptionClockSize()))
    self:setX(clock:getX() + rect.x)
    self:setY(clock:getY() + rect.y)
    self:setWidth(rect.width)
    self:setHeight(rect.height)
end

--- Keeps the overlay on the bell; it draws nothing.
function Overlay:prerender()
    self:syncToClock()
end

--- Draws nothing, so the vanilla bell shows through.
function Overlay:render()
end

--- Lets left-clicks through to the clock.
function Overlay:onMouseDown(x, y)
    return false
end

--- Lets left-click releases through to the clock.
function Overlay:onMouseUp(x, y)
    return false
end

--- Lets mouse movement through.
function Overlay:onMouseMove(dx, dy)
    return false
end

--- Starts a right-click when there is an alarm to set; otherwise lets the
--- click through untouched.
function Overlay:onRightMouseDown(x, y)
    if AlarmFinder.find() == nil then return false end
    self.rightPressed = true
    return true
end

--- Opens the dialog when a right-click that began on the bell ends on it.
function Overlay:onRightMouseUp(x, y)
    if not self.rightPressed then return false end
    self.rightPressed = false
    local alarm, playerNum = AlarmFinder.find()
    if alarm then self:openDialog(alarm, playerNum) end
    return true
end

--- Forgets a right-click that was dragged off the bell.
function Overlay:onRightMouseUpOutside(x, y)
    self.rightPressed = false
end

--- Opens the vanilla Set Alarm Time dialog the way the inventory menu does,
--- or brings the open one forward instead of stacking a second.
function Overlay:openDialog(alarm, playerNum)
    if self.dialog and self.dialog:isVisible() then
        self.dialog:bringToTop()
        return
    end
    local modal = ISAlarmClockDialog:new(0, 0, 230, 160, playerNum, alarm)
    modal:initialise()
    modal:addToUIManager()
    if JoypadState.players[playerNum + 1] then
        modal.prevFocus = getPlayerInventory(playerNum)
        setJoypadFocus(playerNum, modal)
    end
    self.dialog = modal
end

--- Adds one overlay per game session, at the back of the UI list.
function Overlay.install()
    local overlay = Overlay:new()
    overlay:initialise()
    overlay:addToUIManager()
    overlay:backMost()
    Overlay.instance = overlay
    print("[ClockAlarmShortcut] bell overlay installed")
end

Events.OnGameStart.Add(Overlay.install)
