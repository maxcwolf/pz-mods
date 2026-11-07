local C = CSG_Catalog

test("moduleOf extracts module", function()
    eq(C.moduleOf("Base.Axe"), "Base")
    eq(C.moduleOf("farming.HandShovel"), "farming")
    eq(C.moduleOf("NoDot"), "")
end)

test("buildEntries drops hidden, obsolete and moveables, sorts by name", function()
    local entries = C.buildEntries({
        { fullType = "Base.Zebra", displayName = "Zebra" },
        { fullType = "Base.Apple", displayName = "Apple" },
        { fullType = "Base.Ghost", displayName = "Ghost", hidden = true },
        { fullType = "Base.Old", displayName = "Old", obsolete = true },
        { fullType = "Moveables.Sofa", displayName = "Sofa" },
        { fullType = "Base.Mov_Chair", displayName = "Chair" },
    })
    eq(#entries, 2)
    eq(entries[1].fullType, "Base.Apple")
    eq(entries[2].fullType, "Base.Zebra")
end)

test("buildEntries disambiguates duplicate names with module", function()
    local entries = C.buildEntries({
        { fullType = "Base.Axe", displayName = "Axe" },
        { fullType = "Mod.Axe", displayName = "Axe" },
        { fullType = "Base.Saw", displayName = "Saw" },
    })
    eq(entries[1].label, "Axe [Base]")
    eq(entries[2].label, "Axe [Mod]")
    eq(entries[3].label, "Saw")
end)

test("filter matches every word against label and full type", function()
    local entries = C.buildEntries({
        { fullType = "Base.WaterBottleFull", displayName = "Water Bottle" },
        { fullType = "Base.Pop", displayName = "Pop" },
    })
    eq(#C.filter(entries, ""), 2)
    eq(#C.filter(entries, "water bot"), 1)
    eq(#C.filter(entries, "bottlefull"), 1)
    eq(#C.filter(entries, "water pop"), 0)
end)

test("byFullType indexes entries", function()
    local map = C.byFullType(C.buildEntries({ { fullType = "Base.Pop", displayName = "Pop" } }))
    eq(map["Base.Pop"].displayName, "Pop")
end)

test("filter by category and categories list", function()
    local entries = C.buildEntries({
        { fullType = "Base.Pop", displayName = "Pop", category = "Food" },
        { fullType = "Base.Axe", displayName = "Axe", category = "Weapon" },
        { fullType = "Base.Rope", displayName = "Rope" },
    })
    eq(#C.filter(entries, "", "Food"), 1)
    eq(#C.filter(entries, "pop", "Weapon"), 0)
    eq(#C.filter(entries, nil, nil), 3)
    local cats = C.categories(entries)
    eq(#cats, 3)
    eq(cats[1], "Food")
    eq(cats[3], "Weapon")
end)

test("bagLocations groups wearable containers by location", function()
    local entries = C.buildEntries({
        { fullType = "Base.Bag_Big", displayName = "Big Bag", isContainer = true, equipLocation = "Back" },
        { fullType = "Base.Bag_Small", displayName = "Small Bag", isContainer = true, equipLocation = "Back" },
        { fullType = "Base.Fanny", displayName = "Fanny", isContainer = true, equipLocation = "FannyPackFront" },
        { fullType = "Base.Box", displayName = "Box", isContainer = true },
        { fullType = "Base.Axe", displayName = "Axe", equipLocation = "Back" },
    })
    local groups = C.bagLocations(entries)
    eq(#groups, 2)
    eq(groups[1].location, "Back")
    eq(#groups[1].entries, 2)
    eq(groups[2].location, "FannyPackFront")
end)

test("buildEntries keeps ammo facts and holdsAmmo reads them", function()
    local entries = C.buildEntries({
        { fullType = "Base.Pistol", displayName = "Pistol", maxAmmo = 15, isFirearm = true, isWeapon = true },
        { fullType = "Base.9mmClip", displayName = "Magazine", maxAmmo = 15 },
        { fullType = "Base.Axe", displayName = "Axe", isWeapon = true },
    })
    eq(entries[1].maxAmmo, 0, "axe")
    eq(C.holdsAmmo(entries[1]), false)
    eq(entries[2].maxAmmo, 15, "magazine")
    eq(C.holdsAmmo(entries[2]), true)
    eq(entries[3].isFirearm, true, "pistol")
    eq(C.holdsAmmo(entries[3]), true)
end)

test("partsFor groups parts that mount on a firearm by part type", function()
    local entries = C.buildEntries({
        { fullType = "Base.RedDot", displayName = "Red Dot", partType = "Scope", mountOn = { "Base.Pistol" } },
        { fullType = "Base.x2Scope", displayName = "2x Scope", partType = "Scope", mountOn = { "Base.Pistol", "Base.Rifle" } },
        { fullType = "Base.Laser", displayName = "Laser", partType = "Canon", mountOn = {} },
        { fullType = "Base.Pistol", displayName = "Pistol", isFirearm = true },
    })
    local groups = C.partsFor(entries, "Base.Pistol")
    eq(#groups, 2)
    eq(groups[1].partType, "Canon", "sorted by part type")
    eq(groups[1].entries[1].fullType, "Base.Laser", "empty MountOn fits any firearm")
    eq(groups[2].partType, "Scope")
    eq(#groups[2].entries, 2)
    local rifle = C.partsFor(entries, "Base.Rifle")
    eq(#rifle, 2)
    eq(#rifle[2].entries, 1, "only the 2x scope mounts on the rifle")
    eq(#C.partsFor(entries, "Base.Shotgun"), 1, "shotgun gets only the universal laser")
end)
