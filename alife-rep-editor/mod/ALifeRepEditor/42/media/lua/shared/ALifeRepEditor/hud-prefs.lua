--- Pure reading, writing and screen-fitting of the on-screen button's saved
--- position and visibility ("x,y,hidden" in one line).
ALifeRepEditor = ALifeRepEditor or {}

local HudPrefs = {}
ALifeRepEditor.HudPrefs = HudPrefs

--- Parses a saved line into { x, y, hidden }, or nil for anything malformed.
function HudPrefs.parse(line)
    if type(line) ~= "string" then return nil end
    local x, y, hidden = string.match(line, "^%s*(-?%d+)%s*,%s*(-?%d+)%s*,%s*([01])%s*$")
    if x == nil then return nil end
    return { x = tonumber(x), y = tonumber(y), hidden = hidden == "1" }
end

--- Formats prefs as the one saved line.
function HudPrefs.format(prefs)
    return string.format("%d,%d,%d", math.floor(prefs.x or 0), math.floor(prefs.y or 0), prefs.hidden and 1 or 0)
end

--- Keeps a button of the given size fully on screen.
function HudPrefs.fit(x, y, width, height, screenWidth, screenHeight)
    local maxX, maxY = math.max(0, screenWidth - width), math.max(0, screenHeight - height)
    return math.max(0, math.min(maxX, math.floor(x))), math.max(0, math.min(maxY, math.floor(y)))
end

-- Where the vanilla watch clock sits when the game can't say: 10px from the
-- top-right corner, 62px tall at the large clock size.
HudPrefs.CLOCK_MARGIN = 10
HudPrefs.CLOCK_HEIGHT = 62
HudPrefs.GAP = 6

--- Returns true when a clock rectangle has a usable position and size.
function HudPrefs.usableClock(clock)
    return type(clock) == "table" and tonumber(clock.x) ~= nil and tonumber(clock.y) ~= nil
        and (tonumber(clock.width) or 0) > 0 and (tonumber(clock.height) or 0) > 0
end

--- Returns the default spot: just below the watch clock, right edges lined up.
function HudPrefs.defaultPosition(width, screenWidth, clock)
    if HudPrefs.usableClock(clock) then
        return math.floor(clock.x + clock.width - width), math.floor(clock.y + clock.height + HudPrefs.GAP)
    end
    return math.floor(screenWidth - HudPrefs.CLOCK_MARGIN - width),
        HudPrefs.CLOCK_MARGIN + HudPrefs.CLOCK_HEIGHT + HudPrefs.GAP
end

--- Returns the new left edge that keeps the right edge fixed when the width changes.
function HudPrefs.keepRightEdge(x, oldWidth, newWidth)
    return x + oldWidth - newWidth
end

return HudPrefs
