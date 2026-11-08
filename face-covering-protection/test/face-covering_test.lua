local F = FCP_FaceCovering

test("normalizeLocation lowercases and drops the base namespace", function()
    eq(F.normalizeLocation("base:Mask"), "mask")
    eq(F.normalizeLocation("base:maskeyes"), "maskeyes")
    eq(F.normalizeLocation("alice:GasMaskPouch"), "alice:gasmaskpouch")
    eq(F.normalizeLocation(nil), "")
end)

test("hasClothKeyword matches cloth covering names in any case", function()
    eq(F.hasClothKeyword("Hat_BalaclavaFull"), true)
    eq(F.hasClothKeyword("Scarf_Mask_Camo"), true)
    eq(F.hasClothKeyword("Hat_HeadSack_Burlap"), true)
    eq(F.hasClothKeyword("Hat_HockeyMask"), false)
    eq(F.hasClothKeyword("Hat_HalloweenMaskDevil"), false)
    eq(F.hasClothKeyword(nil), false)
end)

test("isCloth accepts cotton and denim but not leather", function()
    eq(F.isCloth({ name = "Hunter_Mask", fabric = "Cotton" }), true)
    eq(F.isCloth({ name = "Jean_Mask", fabric = "Denim" }), true)
    eq(F.isCloth({ name = "Hat_HockeyMask_Hide", fabric = "Leather" }), false)
    eq(F.isCloth({ name = "Vader_Mask" }), false)
end)

test("gas masks and respirators are filter masks whatever their defense", function()
    eq(F.classify({ name = "Hat_GasMask", bodyLocation = "base:maskeyes", defense = 25, takesFilter = true }), "filter")
    eq(F.classify({ name = "Hat_NBCmask", bodyLocation = "base:fullhat", defense = 0, takesFilter = true }), "filter")
    eq(F.classify({ name = "RetroGasMask", bodyLocation = "base:gorget", defense = 25, takesFilter = true }), "filter")
end)

test("items that already protect count as cloth coverings wherever they are worn", function()
    eq(F.classify({ name = "Hat_DustMask", bodyLocation = "base:mask", defense = 25 }), "cloth")
    eq(F.classify({ name = "Hat_ShemaghFull", bodyLocation = "base:fullhat", defense = 25 }), "cloth")
    eq(F.classify({ name = "Facemask", bodyLocation = "base:nose", defense = 15 }), "cloth")
end)

test("unprotected cloth worn over the face counts, by fabric or by name", function()
    eq(F.classify({ name = "Hat_BalaclavaFace", bodyLocation = "base:mask", defense = 0 }), "cloth")
    eq(F.classify({ name = "Hunter_Mask", bodyLocation = "base:Mask", defense = 0, fabric = "Cotton" }), "cloth")
    eq(F.classify({ name = "Hat_HeadSack_Cotton", bodyLocation = "base:fullhat", defense = 0 }), "cloth")
end)

test("hard masks and filterless legacy masks are not face coverings", function()
    eq(F.classify({ name = "Hat_HockeyMask", bodyLocation = "base:maskeyes", defense = 0 }), nil)
    eq(F.classify({ name = "Hat_HockeyMask_Hide", bodyLocation = "base:maskeyes", defense = 0, fabric = "Leather" }), nil)
    eq(F.classify({ name = "Hat_HalloweenMaskDevil", bodyLocation = "base:maskeyes", defense = 0 }), nil)
    eq(F.classify({ name = "WeldingMask", bodyLocation = "base:maskfull", defense = 0 }), nil)
    eq(F.classify({ name = "Hat_GasMask_nofilter", bodyLocation = "base:maskeyes", defense = 0 }), nil)
    eq(F.classify({ name = "Hat_BuildersRespirator_nofilter", bodyLocation = "base:mask", defense = 0 }), nil)
end)

test("cloth worn away from the face, helmets, faces and pouches are not face coverings", function()
    eq(F.classify({ name = "ShemaghScarf", bodyLocation = "base:scarf", defense = 0 }), nil)
    eq(F.classify({ name = "Hat_Bandana", bodyLocation = "base:hat", defense = 0, fabric = "Cotton" }), nil)
    eq(F.classify({ name = "Hat_CrashHelmetFULL", bodyLocation = "base:fullhat", defense = 0 }), nil)
    eq(F.classify({ name = "Face_Alice", bodyLocation = "spncc:face", defense = 0 }), nil)
    eq(F.classify({ name = "GasMaskPouchThigh", bodyLocation = "alice:gasmaskpouch", defense = 0 }), nil)
    eq(F.classify({ name = "Tshirt_White", bodyLocation = "base:tshirt", fabric = "Cotton" }), nil)
end)

test("clampMinimum falls back to the default and stays within 0 to 100", function()
    eq(F.clampMinimum(nil), 50)
    eq(F.clampMinimum("75"), 50)
    eq(F.clampMinimum(30), 30)
    eq(F.clampMinimum(-5), 0)
    eq(F.clampMinimum(250), 100)
end)

test("targetDefense raises weak cloth coverings and leaves the rest alone", function()
    eq(F.targetDefense({ name = "Hat_BandanaMask", bodyLocation = "base:mask", defense = 25 }, 50), 50)
    eq(F.targetDefense({ name = "Hat_BalaclavaFull", bodyLocation = "base:mask", defense = 0 }, 50), 50)
    eq(F.targetDefense({ name = "Hat_Sealed", bodyLocation = "base:maskeyes", defense = 80 }, 50), 80)
    eq(F.targetDefense({ name = "Hat_HockeyMask", bodyLocation = "base:maskeyes", defense = 0 }, 50), 0)
end)

test("targetDefense raises a filter mask unless it is worn with no filter", function()
    local gasMask = { name = "Hat_GasMask", bodyLocation = "base:maskeyes", defense = 25, takesFilter = true }
    eq(F.targetDefense(gasMask, 50, false), 50)
    eq(F.targetDefense(gasMask, 50, true), 25)
    local bandana = { name = "Hat_BandanaMask", bodyLocation = "base:mask", defense = 25 }
    eq(F.targetDefense(bandana, 50, true), 50)
end)

test("planPatches lists only the items whose value has to change", function()
    local patches = F.planPatches({
        { fullType = "Base.Hat_BandanaMask", name = "Hat_BandanaMask", bodyLocation = "base:mask", defense = 25 },
        { fullType = "Base.Hat_Sealed", name = "Hat_Sealed", bodyLocation = "base:mask", defense = 80 },
        { fullType = "Base.Hat_HockeyMask", name = "Hat_HockeyMask", bodyLocation = "base:maskeyes", defense = 0 },
        { fullType = "Base.Hat_DustMask", name = "Hat_DustMask", bodyLocation = "base:mask", defense = 25, current = 50 },
    }, 50)
    eq(#patches, 1)
    eq(patches[1].fullType, "Base.Hat_BandanaMask")
    eq(patches[1].defense, 50)
end)

test("planPatches restores the original value when the minimum drops", function()
    local patches = F.planPatches({
        { fullType = "Base.Hat_BandanaMask", name = "Hat_BandanaMask", bodyLocation = "base:mask", defense = 25, current = 50 },
    }, 0)
    eq(#patches, 1)
    eq(patches[1].defense, 25)
end)

test("planPatches drops a raised filter mask back when it is worn unfiltered", function()
    local infos = {
        { fullType = "Base.Hat_GasMask", name = "Hat_GasMask", bodyLocation = "base:maskeyes", defense = 25, current = 50, takesFilter = true },
        { fullType = "Base.Hat_BuildersRespirator", name = "Hat_BuildersRespirator", bodyLocation = "base:mask", defense = 25, current = 50, takesFilter = true },
    }
    local patches = F.planPatches(infos, 50, { ["Base.Hat_GasMask"] = true })
    eq(#patches, 1)
    eq(patches[1].fullType, "Base.Hat_GasMask")
    eq(patches[1].defense, 25)
end)

test("onlyCoverings keeps the face coverings of either kind", function()
    local kept = F.onlyCoverings({
        { fullType = "Base.Hat_GasMask", name = "Hat_GasMask", bodyLocation = "base:maskeyes", defense = 25, takesFilter = true },
        { fullType = "Base.Hat_BandanaMask", name = "Hat_BandanaMask", bodyLocation = "base:mask", defense = 25 },
        { fullType = "Base.Hat_HockeyMask", name = "Hat_HockeyMask", bodyLocation = "base:maskeyes", defense = 0 },
        { fullType = "Base.Tshirt_White", name = "Tshirt_White", bodyLocation = "base:tshirt", defense = 0 },
    })
    eq(#kept, 2)
    eq(kept[1].fullType, "Base.Hat_GasMask")
    eq(kept[2].fullType, "Base.Hat_BandanaMask")
end)
