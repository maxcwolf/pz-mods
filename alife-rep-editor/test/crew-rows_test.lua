--- Tests for the Crew tab's pure rules.
require "ALifeRepEditor/crew-rows"
require "ALifeRepEditor/item-info"
local Rows = ALifeRepEditor.CrewRows
local Info = ALifeRepEditor.ItemInfo

test("crew levels are whole numbers kept between 0 and the top", function()
    eq(Rows.clamp(4.6, 10), 5); eq(Rows.clamp(-3, 10), 0); eq(Rows.clamp(14, 10), 10); eq(Rows.clamp(nil, 10), 0)
    ok(Rows.isSkill("firstAid")); ok(not Rows.isSkill("strength"))
    ok(Rows.isRating("strength")); ok(Rows.isRating("aiming")); ok(not Rows.isRating("music"))
end)

test("weapons go in A-Life's slots and each item kind has its own give action", function()
    eq(Rows.slotFor({ firearm = false }), "melee")
    eq(Rows.slotFor({ firearm = true, twoHanded = true }), "primary")
    eq(Rows.slotFor({ firearm = true }), "secondary")
    eq(Rows.slotFor(nil), "melee")
    eq(Rows.giveAction("weapon"), "equip"); eq(Rows.giveAction("clothing"), "wear"); eq(Rows.giveAction("item"), "carry")
end)

test("wearing something replaces what's on the same spot, and taking it off keeps the rest", function()
    local spots = { ["Base.Cap"] = "Hat", ["Base.Beret"] = "Hat", ["Base.Tee"] = "Tshirt" }
    local where = function(itemType) return spots[itemType] end
    local outfit = Rows.wearInto({ { itemType = "Base.Cap", tint = "red" }, { itemType = "Base.Tee", tint = "" } },
        "Base.Beret", "Hat", where)
    eq(#outfit, 2); eq(outfit[1].itemType, "Base.Tee"); eq(outfit[2].itemType, "Base.Beret")
    eq(#Rows.wearInto(outfit, "Base.Beret", nil, where), 2, "the same item isn't worn twice")
    local rest, found = Rows.takeOff(outfit, "Base.Tee")
    ok(found); eq(#rest, 1); eq(rest[1].itemType, "Base.Beret")
    local _, missing = Rows.takeOff(outfit, "Base.Boots")
    ok(not missing)
end)

test("item search needs two letters, puts names that start with the text first, and caps the list", function()
    local catalog = {
        { type = "Base.Axe", name = "Axe" }, { type = "Base.HandAxe", name = "Hand Axe" },
        { type = "Base.WoodAxe", name = "Wood Axe" }, { type = "Base.Pistol", name = "M9 Pistol" },
    }
    eq(#Rows.search(catalog, "a"), 0)
    local found = Rows.search(catalog, " AXE ")
    eq(#found, 3); eq(found[1].name, "Axe"); eq(found[2].name, "Hand Axe")
    eq(Rows.search(catalog, "pistol")[1].type, "Base.Pistol", "matches the type too")
    eq(#Rows.search(catalog, "axe", 2), 2)
end)

test("saved crew edits are laid over A-Life's plan for the body", function()
    local plan = { strength = 3, aiming = 2, firearmsAuthored = false, clothing = { { itemType = "Base.Tee" } } }
    Rows.applyOverrides(plan, { strength = 9, aiming = 14, firearms = true, outfit = { { itemType = "Base.Beret" } } })
    eq(plan.strength, 9); eq(plan.aiming, 10); ok(plan.firearmsAuthored)
    eq(#plan.clothing, 1); eq(plan.clothing[1].itemType, "Base.Beret")
    local untouched = { strength = 3, clothing = { 1 } }
    Rows.applyOverrides(untouched, { outfit = {} })
    eq(untouched.strength, 3); eq(#untouched.clothing, 1, "an empty outfit leaves A-Life's clothing alone")
    eq(Rows.applyOverrides(nil, {}), nil)
end)

test("carried items list the held weapon first and stack the rest", function()
    local rows = Rows.carryRows({
        { id = "1", type = "Base.Bandage", name = "Bandage" }, { id = "2", type = "Base.Bandage", name = "Bandage" },
        { id = "3", type = "Base.Axe", name = "Axe", weapon = true },
        { id = "4", type = "Base.Pistol", name = "Pistol", weapon = true, equipped = true },
        { id = "5", type = "Base.Tee", name = "T-shirt", worn = true },
    })
    eq(#rows, 4); eq(rows[1].name, "Pistol"); eq(rows[2].name, "Axe"); eq(rows[3].count, 2); eq(rows[4].name, "T-shirt")
end)

test("refusals name the person and the item, even with a % in them", function()
    eq(Rows.refusal("not_yours", "Pia"), "Pia isn't in your crew.")
    eq(Rows.refusal("unknown_item", "Pia", "Base.Nope"), "There's no item called Base.Nope in this game.")
    eq(Rows.refusal("no_gun", "100% Pia"), "100% Pia isn't holding a gun.")
    eq(Rows.refusal("weird"), "Couldn't do that (weird).")
end)

test("item scripts are read into weapon, gun and clothing details, skipping retired items", function()
    local function script(fields)
        local object = {}
        for name, value in pairs(fields) do object[name] = function() return value end end
        return object
    end
    local gun = Info.fromScript(script({ getFullName = "Base.Shotgun", getDisplayName = "Shotgun", getTypeString = "Weapon",
        getMaxAmmo = 6, isTwoHandWeapon = true }))
    eq(gun.kind, "weapon"); ok(gun.firearm); ok(gun.twoHanded)
    local axe = Info.fromScript(script({ getFullName = "Base.Axe", getDisplayName = "Axe", getTypeString = "Weapon", getMaxAmmo = 0 }))
    ok(not axe.firearm)
    local cap = Info.fromScript(script({ getFullName = "Base.Cap", getDisplayName = "Cap", getTypeString = "Clothing",
        getBodyLocation = "Hat" }))
    eq(cap.kind, "clothing"); eq(cap.location, "Hat")
    eq(Info.fromScript(script({ getFullName = "Base.Old", getObsolete = true })), nil)
    eq(Info.fromScript(script({ getFullName = "Base.Pen", getTypeString = "Normal" })).name, "Base.Pen", "falls back to the type")
    eq(Info.kindOf("base:clothing"), "clothing")
    local typed = script({ getFullName = "Base.Bat", getDisplayName = "Bat",
        getItemType = { toString = function() return "base:weapon" end } })
    eq(Info.fromScript(typed).kind, "weapon", "Build 42's getItemType() is read first")
end)
