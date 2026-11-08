require "ALifeRepEditor/hud-prefs"
local HudPrefs = ALifeRepEditor.HudPrefs

test("parse reads x, y and hidden", function()
    local prefs = HudPrefs.parse("120, 8,1")
    eq(prefs.x, 120); eq(prefs.y, 8); ok(prefs.hidden)
    eq(HudPrefs.parse("garbage"), nil); eq(HudPrefs.parse(nil), nil)
end)

test("format round-trips through parse", function()
    local prefs = HudPrefs.parse(HudPrefs.format({ x = 33.7, y = 4, hidden = false }))
    eq(prefs.x, 33); eq(prefs.y, 4); ok(not prefs.hidden)
end)

test("fit keeps the button on screen", function()
    local x, y = HudPrefs.fit(1900, -5, 100, 20, 1920, 1080)
    eq(x, 1820); eq(y, 0)
end)

test("defaultPosition puts the button just below the clock, right edges lined up", function()
    local x, y = HudPrefs.defaultPosition(100, 1920, { x = 1754, y = 10, width = 156, height = 62 })
    eq(x, 1810, "right edge at the clock's"); eq(y, 78, "6px under the clock")
    x, y = HudPrefs.defaultPosition(100, 1920, { x = 1829, y = 10, width = 81, height = 32 })
    eq(x, 1810, "small clock, same right edge"); eq(y, 48, "under the shorter clock")
end)

test("defaultPosition falls back to the vanilla clock spot without a usable clock", function()
    local x, y = HudPrefs.defaultPosition(100, 1920, nil)
    eq(x, 1810); eq(y, 78)
    x, y = HudPrefs.defaultPosition(100, 1920, { x = 0, y = 0, width = 0, height = 0 })
    eq(x, 1810, "unsized clock ignored"); eq(y, 78)
end)

test("keepRightEdge shifts the left edge by the width change", function()
    eq(HudPrefs.keepRightEdge(1810, 100, 130), 1780)
    eq(HudPrefs.keepRightEdge(1810, 100, 80), 1830)
end)
