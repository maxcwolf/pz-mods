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
