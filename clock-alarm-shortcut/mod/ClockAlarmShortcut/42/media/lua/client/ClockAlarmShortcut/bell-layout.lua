--- Pure layout math for the alarm bell on the HUD clock. It repeats what
--- zombie.ui.Clock.renderDisplay does (Build 42.21) so the bell's rectangle
--- can be worked out without game globals, which keeps it unit-testable.
---
--- The clock draws four large digits with a colon after the second, then the
--- AM/PM marker, then the bell. The bell's position always includes the AM
--- marker's width, even in 24-hour mode where the marker is not drawn.
local BellLayout = {}

--- Pixel spacings from Clock.assignSmallOffsets and Clock.assignLargeOffsets.
BellLayout.SPACING = {
    small = { originX = 3, originY = 3, digit = 1, colon = 1, ampm = 1, bell = 1, bellVertical = 1 },
    large = { originX = 3, originY = 3, digit = 2, colon = 3, ampm = 3, bell = 5, bellVertical = 1 },
}

--- Texture size word the clock uses for its big row: "Medium" textures on the
--- small clock and "Large" textures on the large one.
BellLayout.TEXTURE_WORD = { small = "Medium", large = "Large" }

--- Texture sizes measured from media/ui/ClockAssets, used when the game
--- cannot hand back a texture.
BellLayout.FALLBACK_SIZES = {
    small = { digit = 9, colon = 4, am = 12, bellWidth = 19, bellHeight = 15 },
    large = { digit = 18, colon = 6, am = 22, bellWidth = 30, bellHeight = 29 },
}

--- Maps the game's clock size option (2 means large) to a layout key.
function BellLayout.sizeKey(clockSizeOption)
    if clockSizeOption == 2 then return "large" end
    return "small"
end

--- Lists the texture paths whose sizes decide where the bell sits.
function BellLayout.texturePaths(key)
    local word = BellLayout.TEXTURE_WORD[key]
    local base = "media/ui/ClockAssets/"
    return {
        digit = base .. "ClockDigits" .. word .. "0.png",
        colon = base .. "ClockDivide" .. word .. ".png",
        am = base .. "ClockAm" .. word .. ".png",
        bell = base .. "ClockAlarm" .. word .. "Set.png",
    }
end

--- Works out the bell's rectangle relative to the clock's top left corner.
function BellLayout.bellRect(spacing, sizes)
    local x = spacing.originX
    for i = 0, 3 do
        x = x + sizes.digit
        if i == 1 then
            x = x + spacing.colon + sizes.colon + spacing.colon
        elseif i < 3 then
            x = x + spacing.digit
        end
    end
    x = x + spacing.ampm + sizes.am + spacing.bell
    return {
        x = x,
        y = spacing.originY + spacing.bellVertical,
        width = sizes.bellWidth,
        height = sizes.bellHeight,
    }
end

--- Tells whether a point relative to the clock falls inside a rectangle.
function BellLayout.contains(rect, x, y)
    return x >= rect.x and x < rect.x + rect.width and y >= rect.y and y < rect.y + rect.height
end

ClockAlarmShortcut_BellLayout = BellLayout
return BellLayout
