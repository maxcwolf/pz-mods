local S = FCP_Stubs
local P = FCP_Patch

--- Resets the fake world to a small mix of vanilla-like and modded items.
local function freshWorld(minimum)
    P.originals = {}
    P.tracked = nil
    S.server = false
    S.localPlayers = {}
    S.onlinePlayers = {}
    SandboxVars = { FaceCoveringProtection = { MinimumDefense = minimum } }
    S.setItems({
        S.scriptItem("Base.Hat_BandanaMask", ItemType.CLOTHING, "base:mask", 25, { fabric = "Cotton" }),
        S.scriptItem("Base.Hat_ShemaghFull", ItemType.CLOTHING, "base:fullhat", 25),
        S.scriptItem("Base.Hat_BalaclavaFull", ItemType.CLOTHING, "base:mask", 0),
        S.scriptItem("Tomb.Hunter_Mask", ItemType.CLOTHING, "base:mask", 0, { fabric = "Cotton" }),
        S.scriptItem("Base.Hat_GasMask", ItemType.CLOTHING, "base:maskeyes", 25, { tags = { ItemTag.GAS_MASK } }),
        S.scriptItem("Base.Hat_NBCmask", ItemType.CLOTHING, "base:fullhat", 0, { tags = { ItemTag.GAS_MASK } }),
        S.scriptItem("Base.Hat_BuildersRespirator", ItemType.CLOTHING, "base:mask", 25, { tags = { ItemTag.RESPIRATOR } }),
        S.scriptItem("Brita.M40GasMask", ItemType.CLOTHING, "base:maskeyes", 80, { tags = { ItemTag.GAS_MASK } }),
        S.scriptItem("Base.Hat_GasMask_nofilter", ItemType.CLOTHING, "base:maskeyes", 0),
        S.scriptItem("Base.Hat_HockeyMask", ItemType.CLOTHING, "base:maskeyes", 0),
        S.scriptItem("Base.Hat_HockeyMask_Hide", ItemType.CLOTHING, "base:maskeyes", 0, { fabric = "Leather" }),
        S.scriptItem("Base.WeldingMask", ItemType.CLOTHING, "base:maskfull", 0),
        S.scriptItem("Base.Hat_Bandana", ItemType.CLOTHING, "base:hat", 0, { fabric = "Cotton" }),
        S.scriptItem("Base.Tshirt_White", ItemType.CLOTHING, "base:tshirt", 0, { fabric = "Cotton" }),
        S.scriptItem("Base.Bracelet", ItemType.CLOTHING, nil, 0),
        S.scriptItem("Base.BandanaBox", ItemType.NORMAL, "base:mask", 0),
    })
end

test("the patch runs on world load and re-syncs every minute and on clothing changes", function()
    eq(S.handlers.OnInitGlobalModData[1], P.apply)
    eq(S.handlers.EveryOneMinute[1], P.sync)
    eq(S.handlers.OnClothingUpdated[1], P.sync)
end)

test("apply raises cloth coverings and filter masks to the sandbox minimum", function()
    freshWorld(50)
    eq(P.apply(), 7)
    eq(S.find("Base.Hat_BandanaMask").defense, 50)
    eq(S.find("Base.Hat_ShemaghFull").defense, 50)
    eq(S.find("Base.Hat_BalaclavaFull").defense, 50)
    eq(S.find("Tomb.Hunter_Mask").defense, 50)
    eq(S.find("Base.Hat_GasMask").defense, 50)
    eq(S.find("Base.Hat_NBCmask").defense, 50)
    eq(S.find("Base.Hat_BuildersRespirator").defense, 50)
end)

test("apply leaves hard masks, filterless masks, stronger masks and other items alone", function()
    freshWorld(50)
    P.apply()
    eq(S.find("Base.Hat_HockeyMask").defense, 0)
    eq(S.find("Base.Hat_HockeyMask_Hide").defense, 0)
    eq(S.find("Base.WeldingMask").defense, 0)
    eq(S.find("Base.Hat_GasMask_nofilter").defense, 0)
    eq(S.find("Brita.M40GasMask").defense, 80)
    eq(S.find("Base.Hat_Bandana").defense, 0)
    eq(S.find("Base.Tshirt_White").defense, 0)
    eq(S.find("Base.Bracelet").defense, 0)
    eq(S.find("Base.BandanaBox").defense, 0)
end)

test("apply uses 50 when the sandbox option is missing", function()
    freshWorld(nil)
    SandboxVars = {}
    P.apply()
    eq(S.find("Base.Hat_BandanaMask").defense, 50)
end)

test("sync does nothing before a world has loaded", function()
    freshWorld(50)
    eq(P.sync(), 0)
    eq(S.find("Base.Hat_BandanaMask").defense, 25)
end)

test("syncing again changes nothing", function()
    freshWorld(50)
    P.apply()
    eq(P.sync(), 0)
    eq(S.find("Base.Hat_BandanaMask").doParamCalls, 1)
end)

test("a gas mask worn with a filter, charged or spent, keeps the minimum", function()
    freshWorld(50)
    P.apply()
    S.localPlayers = { S.player({ S.wornClothing("Base.Hat_GasMask", true), S.wornClothing("Base.Tshirt_White", false) }) }
    eq(P.sync(), 0)
    eq(S.find("Base.Hat_GasMask").defense, 50)
end)

test("a gas mask worn with no filter drops to its own value until one is fitted", function()
    freshWorld(50)
    P.apply()
    local mask = S.wornClothing("Base.Hat_GasMask", false)
    S.localPlayers = { S.player({ mask, S.wornClothing("Base.Hat_BandanaMask", false) }) }
    eq(P.sync(), 1)
    eq(S.find("Base.Hat_GasMask").defense, 25)
    eq(S.find("Base.Hat_BuildersRespirator").defense, 50)
    eq(S.find("Base.Hat_BandanaMask").defense, 50)
    mask.filter = true
    eq(P.sync(), 1)
    eq(S.find("Base.Hat_GasMask").defense, 50)
end)

test("taking off a filterless mask restores the minimum for that type", function()
    freshWorld(50)
    P.apply()
    S.localPlayers = { S.player({ S.wornClothing("Base.Hat_NBCmask", false) }) }
    P.sync()
    eq(S.find("Base.Hat_NBCmask").defense, 0)
    S.localPlayers = { S.player({}) }
    P.sync()
    eq(S.find("Base.Hat_NBCmask").defense, 50)
end)

test("on a server the online players are checked instead of local ones", function()
    freshWorld(50)
    P.apply()
    S.server = true
    S.localPlayers = { S.player({ S.wornClothing("Base.Hat_BuildersRespirator", false) }) }
    S.onlinePlayers = { S.player({ S.wornClothing("Base.Hat_GasMask", false) }) }
    P.sync()
    eq(S.find("Base.Hat_GasMask").defense, 25)
    eq(S.find("Base.Hat_BuildersRespirator").defense, 50)
end)

test("loading a world with a different minimum re-applies from the original values", function()
    freshWorld(50)
    P.apply()
    SandboxVars.FaceCoveringProtection.MinimumDefense = 0
    P.apply()
    eq(S.find("Base.Hat_BandanaMask").defense, 25)
    eq(S.find("Base.Hat_BalaclavaFull").defense, 0)
    SandboxVars.FaceCoveringProtection.MinimumDefense = 90
    P.apply()
    eq(S.find("Base.Hat_BandanaMask").defense, 90)
    eq(S.find("Brita.M40GasMask").defense, 90)
end)
