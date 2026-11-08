local BellLayout = ClockAlarmShortcut_BellLayout

test("size option 2 is the large clock, anything else the small one", function()
    eq(BellLayout.sizeKey(2), "large")
    eq(BellLayout.sizeKey(1), "small")
    eq(BellLayout.sizeKey(nil), "small")
end)

test("small clock bell sits at 61,4 and is 19 by 15", function()
    local rect = BellLayout.bellRect(BellLayout.SPACING.small, BellLayout.FALLBACK_SIZES.small)
    eq(rect.x, 61, "x")
    eq(rect.y, 4, "y")
    eq(rect.width, 19, "width")
    eq(rect.height, 15, "height")
end)

test("small clock bell fits inside the 81 pixel background", function()
    local rect = BellLayout.bellRect(BellLayout.SPACING.small, BellLayout.FALLBACK_SIZES.small)
    eq(rect.x + rect.width <= 81, true, "right edge")
end)

test("large clock bell sits at 121,4 and is 30 by 29", function()
    local rect = BellLayout.bellRect(BellLayout.SPACING.large, BellLayout.FALLBACK_SIZES.large)
    eq(rect.x, 121, "x")
    eq(rect.y, 4, "y")
    eq(rect.width, 30, "width")
    eq(rect.height, 29, "height")
end)

test("large clock bell fits inside the 156 pixel background", function()
    local rect = BellLayout.bellRect(BellLayout.SPACING.large, BellLayout.FALLBACK_SIZES.large)
    eq(rect.x + rect.width <= 156, true, "right edge")
end)

test("wider digits push the bell right by four digit widths", function()
    local sizes = { digit = 10, colon = 4, am = 12, bellWidth = 19, bellHeight = 15 }
    local rect = BellLayout.bellRect(BellLayout.SPACING.small, sizes)
    eq(rect.x, 65, "x")
end)

test("texture paths use Medium for the small clock and Large for the large one", function()
    eq(BellLayout.texturePaths("small").bell, "media/ui/ClockAssets/ClockAlarmMediumSet.png")
    eq(BellLayout.texturePaths("large").digit, "media/ui/ClockAssets/ClockDigitsLarge0.png")
    eq(BellLayout.texturePaths("large").colon, "media/ui/ClockAssets/ClockDivideLarge.png")
    eq(BellLayout.texturePaths("small").am, "media/ui/ClockAssets/ClockAmMedium.png")
end)

test("contains accepts the top left corner and rejects the far edges", function()
    local rect = { x = 10, y = 5, width = 4, height = 3 }
    eq(BellLayout.contains(rect, 10, 5), true, "corner")
    eq(BellLayout.contains(rect, 13, 7), true, "last pixel")
    eq(BellLayout.contains(rect, 14, 7), false, "right edge")
    eq(BellLayout.contains(rect, 13, 8), false, "bottom edge")
    eq(BellLayout.contains(rect, 9, 6), false, "left of it")
end)
