local E = CSG_PartEffects

--- Label lookup that returns the bare key, like the test getText.
local function label(key) return key end

test("effects lists only what a part changes, in a fixed order", function()
    local list = E.effects({ weightModifier = 0.6, hitChance = 5, aimingTime = -10, damage = 0 })
    eq(#list, 3)
    eq(list[1].key, "HitChance")
    eq(list[1].text, "+5")
    eq(list[2].key, "AimingTime")
    eq(list[2].text, "-10")
    eq(list[3].key, "Weight")
    eq(list[3].text, "+0.6")
end)

test("sight range, light and decimals read naturally", function()
    local list = E.effects({ minSight = 4, maxSight = 12.0, light = 15, spread = -0.4, recoilDelay = -2.0 })
    local byKey = {}
    for _, e in ipairs(list) do byKey[e.key] = e.text end
    eq(byKey.Sight, "4-12", "sight range as a span")
    eq(byKey.Light, "15", "light distance has no sign")
    eq(byKey.Spread, "-0.4")
    eq(byKey.RecoilDelay, "-2", "whole floats drop the decimal")
    eq(#E.effects({}), 0)
    eq(#E.effects(nil), 0)
end)

test("summary and tooltip format the effects", function()
    local stats = { hitChance = 5, aimingTime = -10, weightModifier = 0.6 }
    eq(E.summary(stats, label), "HitChance +5, AimingTime -10, Weight +0.6")
    eq(E.summary({}, label), "")
    eq(E.tooltip(stats, label, "A laser."), "A laser. <LINE> <LINE> HitChance +5 <LINE> AimingTime -10 <LINE> Weight +0.6")
    eq(E.tooltip({}, label, nil), "")
    eq(E.tooltip(stats, label, nil), "HitChance +5 <LINE> AimingTime -10 <LINE> Weight +0.6")
end)
