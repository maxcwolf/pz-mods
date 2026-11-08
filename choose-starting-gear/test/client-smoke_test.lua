local Stubs = dofile((arg[0]:match("^(.*)/test/run%.lua$") or ".") .. "/test/harness/pz-stubs.lua")
Stubs.root = arg[0]:match("^(.*)/test/run%.lua$") or "."
require "ChooseStartingGear/hooks"

local function worn(...)
    local list = {}
    for _, spec in ipairs({ ... }) do
        table.insert(list, { item = Stubs.item(spec[1]), location = spec[2] })
    end
    return list
end

local function panelOf(screen)
    screen:arrangeClothingUI()
    local panel = screen.csgPanel
    while not CSG_State.catalogReady() do panel:update() end
    return panel
end

local function labels(panel)
    local out = {}
    for _, w in ipairs(panel.widgets) do if w.name then table.insert(out, w.name) end end
    return out
end

local function combos(panel)
    local out = {}
    for _, w in ipairs(panel.widgets) do if w.onChangeArgs then out[w.onChangeArgs[1]] = w end end
    return out
end

local function bagButtons(panel)
    local out = {}
    for _, w in ipairs(panel.widgets) do if w.isBagButton then table.insert(out, w) end end
    return out
end

local function has(list, value)
    for _, v in ipairs(list) do if v == value then return true end end
    return false
end

test("panel loads, builds catalog and lists slots for worn belt and sling", function()
    CSG_State.entries = nil; CSG_State.entryMap = nil; CSG_State.build = nil; CSG_State.loaded = false
    CSG_State.selection = CSG_Selection.new()
    local screen = Stubs.screen(worn({ "Base.Belt2", "Belt" }, { "alice.Sling", "SlingFront" }, { "Base.Bag_ALICEpack", "Back" }, { "Base.Bag_Satchel", "Satchel" }))
    local panel = panelOf(screen)
    eq(#CSG_State.entries, 16, "catalog size without hidden and moveables")
    local c = combos(panel)
    eq(c.primary ~= nil, true, "primary hand combo")
    eq(c.SmallBeltLeft ~= nil, true, "belt left combo")
    eq(c.AliceSling ~= nil, true, "sling combo from modded clothing")
    eq(#c.AliceSling.options, 2, "sling lists None + rifle")
    eq(#c.SmallBeltLeft.options, 3, "belt lists None + wrench + machete")
    eq(#c.Back.options, 2, "back with bag: rifle moves to bag model, crowbar blocked")
    local bags = bagButtons(panel)
    eq(#bags, 2, "one button per worn bag")
    eq(bags[1].title, "ALICE Pack (Back)  -  0 UI_CSG_Items, 0.0 / 27", "bag header")
    eq(bags[2].title, "Satchel (Satchel)  -  0 UI_CSG_Items, 0.0 / 12", "satchel header")
    eq(screen.clothingPanel.scrollHeight > 200, true, "scroll height extended")
end)

local function buttonsTitled(panel, title)
    local out = {}
    for _, w in ipairs(panel.widgets) do if w.title == title then table.insert(out, w) end end
    return out
end

test("choices update the selection, the bag summary and the saved file", function()
    local screen = Stubs.screen(worn({ "Base.Belt2", "Belt" }, { "Base.Bag_ALICEpack", "Back" }))
    local panel = panelOf(screen)
    local c = combos(panel)
    c.SmallBeltLeft:pick("Base.Wrench")
    c.SmallBeltRight:pick("Base.Machete")
    c.Back:pick("Base.AssaultRifle")
    c.primary:pick("Base.Crowbar")
    eq(CSG_State.selection.attachments.SmallBeltLeft, "Base.Wrench")
    eq(Stubs.files["ChooseStartingGear_last.txt"] ~= nil, true, "selection saved")
    -- the edit button opens the dialog on this bag
    local key = "Base.Bag_ALICEpack#1"
    eq(bagButtons(panel)[1].title, "ALICE Pack (Back)  -  0 UI_CSG_Items, 0.0 / 27", "bag row is a big titled button")
    bagButtons(panel)[1]:click()
    local dialog = CSG_BagContentsDialog.instance
    eq(dialog ~= nil, true, "dialog created")
    eq(dialog.bagKey, key)
    eq(#dialog.catalogList.items, 16, "catalog lists everything with no filter")
    dialog.categoryCombo:selectData("Food")
    dialog:onFilterChanged()
    eq(#dialog.catalogList.items, 2, "category filter")
    dialog.searchEntry:type("wat")
    eq(#dialog.catalogList.items, 1, "search within category")
    dialog.qtyEntry:setText("2")
    dialog.catalogList:doubleClickRow(1)
    eq(CSG_Selection.containerItems(CSG_State.selection, key)[1].count, 2, "double-click adds the quantity")
    dialog.searchEntry:type("")
    dialog.catalogList.selected = 1
    dialog:onAddClicked()
    eq(#CSG_Selection.containerItems(CSG_State.selection, key), 2, "add button adds the highlighted row")
    dialog:onQuickAdd(nil, 5)
    eq(CSG_Selection.containerItems(CSG_State.selection, key)[2].count, 7, "+5 quick add")
    dialog:onQuickAdd(nil, 1)
    dialog.contentsList.selected = 2
    dialog:onAdjustClicked(nil, -1)
    dialog:onAdjustClicked(nil, -5)
    eq(#dialog.contentsList.items, 2)
    dialog.contentsList.selected = 1
    dialog:onAdjustClicked(nil, -1)
    eq(CSG_Selection.containerItems(CSG_State.selection, key)[1].count, 1, "-1 adjusts")
    eq(dialog.weightLabel.name, "UI_CSG_Weight 1.4 / 27", "weight label")
    eq(bagButtons(panel)[1].title, "ALICE Pack (Back)  -  3 UI_CSG_Items, 1.4 / 27", "bag button follows the dialog")
    dialog.contentsList.selected = 2
    dialog:onRemoveClicked()
    eq(#CSG_Selection.containerItems(CSG_State.selection, key), 1)
    dialog:onEmptyClicked()
    eq(#CSG_Selection.containerItems(CSG_State.selection, key), 0)
    CSG_Selection.addToContainer(CSG_State.selection, key, "Base.Pop", 1)
    CSG_Selection.addToContainer(CSG_State.selection, key, "Base.WaterBottleFull", 2)
    dialog:changed()
end)

test("the preview renders attached gear on one hidden player and only re-syncs on change", function()
    local screen = Stubs.screen(worn({ "Base.Belt2", "Belt" }, { "Base.Bag_ALICEpack", "Back" }))
    CSG_Preview.key = nil
    CSG_Preview.player = nil
    local built = Stubs.playersBuilt
    local panel = panelOf(screen)
    local model = screen.avatarPanel.avatarPanel
    local avatar = model.lastCharacter
    eq(avatar ~= nil, true, "live character shown once the catalog is ready and gear is chosen")
    eq(avatar, CSG_Preview.player)
    eq(Stubs.playersBuilt, built + 1, "one preview player created")
    eq(#avatar.attachedRaw, 3, "three attached items on the preview")
    eq(avatar.primary, nil, "hand items are not equipped on the preview")
    eq(avatar.copiedLook ~= nil, true, "look copied from the desc")
    eq(avatar.wornSet ~= nil, true, "worn items taken from the desc")
    local resets = avatar.resets
    for _ = 1, 50 do screen.avatarPanel:setSurvivorDesc(MainScreen.instance.desc) end
    eq(avatar.resets, resets, "mouse-move re-renders do not re-sync")
    eq(Stubs.playersBuilt, built + 1, "and never create another player")
    MainScreen.instance.desc.look.hair = "Mohawk"
    screen.avatarPanel:setSurvivorDesc(MainScreen.instance.desc)
    eq(avatar.resets, resets + 1, "a hair change re-syncs the preview")
    local c = combos(panel)
    c.Back:pick(nil)
    eq(#avatar.attachedRaw, 2, "clearing a slot updates the preview")
    panel:onClearAll()
    screen.avatarPanel:setSurvivorDesc(MainScreen.instance.desc)
    eq(model.lastCharacter, nil, "vanilla desc preview when nothing is chosen")
    eq(model.lastDesc, MainScreen.instance.desc)
    CSG_State.selection = CSG_Selection.deserialize("attach\tSmallBeltLeft\tBase.Wrench\nattach\tSmallBeltRight\tBase.Machete\nattach\tBack\tBase.AssaultRifle\nhand\tprimary\tBase.Crowbar\ncontainer\tBase.Bag_ALICEpack#1\tBase.Pop\t1\ncontainer\tBase.Bag_ALICEpack#1\tBase.WaterBottleFull\t2")
end)

test("bags can be chosen from the panel and then filled", function()
    local screen = Stubs.screen(worn({ "Base.Belt2", "Belt" }))
    local panel = panelOf(screen)
    local c = combos(panel)
    eq(c.Back ~= nil and c.Satchel ~= nil, true, "one bag combo per location")
    eq(#c.Satchel.options, 2, "None + satchel")
    eq(has(labels(panel), "UI_CSG_NoBags"), true, "hint before any bag is worn")
    c.Satchel:pick("Base.Bag_Satchel")
    eq(MainScreen.instance.desc:getWornItem("Satchel"):getFullType(), "Base.Bag_Satchel", "desc now wears the satchel")
    eq(screen.synced, 1, "vanilla combos told to re-sync")
    eq(#bagButtons(panel), 1, "a bag button appeared for the satchel")
    eq(combos(panel).Satchel.selected, 2, "bag combo shows the worn bag after rebuild")
    combos(panel).Satchel:pick(nil)
    eq(MainScreen.instance.desc:getWornItem("Satchel"), nil)
    eq(#bagButtons(panel), 0)
end)

test("pressing play then spawning applies gear through the hotbar", function()
    local screen = Stubs.screen(worn({ "Base.Belt2", "Belt" }, { "Base.Bag_ALICEpack", "Back" }))
    screen:onOptionMouseDown({ internal = "NEXT" })
    eq(CSG_State.pending, true)
    local player = Stubs.player(worn({ "Base.Belt2", "Belt" }, { "Base.Bag_ALICEpack", "Back" }))
    Stubs.currentPlayer = player
    Events.OnNewGame.fire(player, nil)
    Events.OnTick.fire()
    eq(CSG_State.pending, false)
    eq(#player.hotbar.attached, 3, "wrench, machete and rifle attached")
    local byType = {}
    for _, a in ipairs(player.hotbar.attached) do byType[a.slotType] = a end
    eq(byType.SmallBeltLeft.slot, "Wrench Left")
    eq(byType.SmallBeltRight.slot, "Belt Right Upside")
    eq(byType.Back.slot, "Back Rifle", "hotbar applies the bag replacement itself")
    eq(player.primary:getFullType(), "Base.Crowbar")
    local bag
    for _, w in ipairs(player.worn) do if w.item:getFullType() == "Base.Bag_ALICEpack" then bag = w.item end end
    eq(#bag.contents, 3, "one pop and two water bottles in the bag")
end)

test("spawning puts on clothing the desc wore but the player is missing, then attaches to it", function()
    CSG_State.selection = CSG_Selection.deserialize("attach\tAliceSling\tBase.AssaultRifle\nhand\tprimary\tBase.Machete\ncontainer\tBase.Bag_Satchel#1\tBase.Pop\t2")
    local screen = Stubs.screen(worn({ "Base.Belt2", "Belt" }, { "alice.Sling", "SlingFront" }, { "Base.Bag_Satchel", "Satchel" }))
    screen:onOptionMouseDown({ internal = "NEXT" })
    eq(#CSG_State.wornAtPlay, 3, "worn clothing snapshotted at Play")
    MainScreen.instance.desc = nil
    local player = Stubs.player(worn({ "Base.Belt2", "Belt" }))
    Stubs.currentPlayer = player
    Events.OnNewGame.fire(player, nil)
    Events.OnTick.fire()
    eq(#player.worn, 3, "sling and satchel were put on")
    eq(player.worn[2].location, "SlingFront", "clothing worn at its body location")
    eq(player.worn[3].location:getTranslationName(), "Satchel", "bag worn at its equip location")
    eq(#player.hotbar.attached, 1, "rifle attached to the sling that was just put on")
    eq(player.hotbar.attached[1].slotType, "AliceSling")
    eq(player.primary:getFullType(), "Base.Machete")
    local satchel = player.worn[3].item
    eq(#satchel.contents, 2, "satchel filled")
end)

test("gear whose slot is still missing is retried a little later", function()
    CSG_State.selection = CSG_Selection.deserialize("attach\tAliceSling\tBase.AssaultRifle")
    local screen = Stubs.screen(worn({ "Base.Belt2", "Belt" }))
    screen:onOptionMouseDown({ internal = "NEXT" })
    local player = Stubs.player(worn({ "Base.Belt2", "Belt" }))
    Stubs.currentPlayer = player
    Events.OnNewGame.fire(player, nil)
    Events.OnTick.fire()
    eq(#player.hotbar.attached, 0, "nothing to attach to yet")
    table.insert(player.worn, { item = Stubs.item("alice.Sling"), location = "SlingFront" })
    for _ = 1, 119 do Events.OnTick.fire() end
    eq(#player.hotbar.attached, 0, "not retried before the delay")
    Events.OnTick.fire()
    eq(#player.hotbar.attached, 1, "retried once the sling is worn")
    for _ = 1, 130 do Events.OnTick.fire() end
    eq(#player.hotbar.attached, 1, "retried only once")
end)

test("remembered selection survives a reload and prunes unknown items", function()
    Stubs.files["ChooseStartingGear_last.txt"] = "attach\tBack\tBase.Crowbar\nattach\tBack\tGone.Item\ncontainer\tBase.Bag_ALICEpack#1\tBase.Pop\t3"
    CSG_State.loaded = false
    CSG_State.load()
    eq(CSG_State.selection.attachments.Back, nil, "last line wins then pruned as unknown")
    eq(CSG_Selection.containerItems(CSG_State.selection, "Base.Bag_ALICEpack#1")[1].count, 3)
end)

test("the saved outfits reader keeps modded body locations whose keys contain colons", function()
    local value = "gender=1;Jacket=Base.Jacket;alicesweaponsling:slingback=alice.Sling;tks:KnifeSheathBack=Base.Knife;"
    Stubs.files["saved_outfits.txt"] = "VERSION=1\nMax Wolf:" .. value .. "\n"
    eq(CharacterCreationMain.readSavedOutfitFile()["Max Wolf"], value)
end)

test("saving, loading and deleting a vanilla build carries the gear with it", function()
    Stubs.files["saved_outfits.txt"] = nil
    Stubs.files["ChooseStartingGear_builds.txt"] = nil
    local screen = Stubs.screen(worn({ "Base.Belt2", "Belt" }, { "Base.Bag_ALICEpack", "Back" }))
    local panel = panelOf(screen)
    CSG_State.selection = CSG_Selection.deserialize("attach\tSmallBeltLeft\tBase.Wrench\ncontainer\tBase.Bag_ALICEpack#1\tBase.Pop\t2")
    local function saveButton(internal, name)
        return { internal = internal, parent = { entry = { getText = function() return name end } } }
    end
    screen:saveBuildStep2(saveButton("CANCEL", "Nope"))
    eq(Stubs.files["ChooseStartingGear_builds.txt"], nil, "cancel writes nothing")
    screen:saveBuildStep2(saveButton("OK", "Max Wolf"))
    eq(CSG_State.readBuilds()["Max Wolf"].attachments.SmallBeltLeft, "Base.Wrench", "gear stored under the build name")
    CSG_State.selection = CSG_Selection.new()
    panel:rebuild()
    eq(combos(panel).SmallBeltLeft:getOptionData(combos(panel).SmallBeltLeft.selected), nil)
    screen:loadOutfit(screen.savedBuilds)
    eq(CSG_State.selection.attachments.SmallBeltLeft, "Base.Wrench", "gear restored with the build")
    eq(CSG_Selection.containerItems(CSG_State.selection, "Base.Bag_ALICEpack#1")[1].count, 2)
    eq(combos(panel).SmallBeltLeft:getOptionData(combos(panel).SmallBeltLeft.selected), "Base.Wrench", "panel shows the restored gear")
    eq(Stubs.files["ChooseStartingGear_last.txt"]:find("Base.Wrench", 1, true) ~= nil, true, "restored gear becomes the remembered selection")
    screen.savedBuilds.options = { "Max Wolf", "Plain" }
    screen.savedBuilds.selected = 2
    screen:loadOutfit(screen.savedBuilds)
    eq(CSG_State.selection.attachments.SmallBeltLeft, "Base.Wrench", "a build saved without gear keeps the current gear")
    screen.savedBuilds.selected = 1
    screen:deleteBuildStep2({ internal = "NO" })
    eq(CSG_State.readBuilds()["Max Wolf"] ~= nil, true, "declining the delete keeps the gear")
    screen:deleteBuildStep2({ internal = "YES" })
    eq(CSG_State.readBuilds()["Max Wolf"], nil, "gear removed with the build")
end)

test("firearms and magazines spawn fully loaded unless the option is off", function()
    local function spawn()
        local screen = Stubs.screen(worn({ "Base.Bag_ALICEpack", "Back" }))
        screen:onOptionMouseDown({ internal = "NEXT" })
        local player = Stubs.player(worn({ "Base.Bag_ALICEpack", "Back" }))
        Stubs.currentPlayer = player
        Events.OnNewGame.fire(player, nil)
        Events.OnTick.fire()
        return player, player.worn[1].item.contents
    end
    CSG_State.selection = CSG_Selection.deserialize("hand\tprimary\tBase.Shotgun\ncontainer\tBase.Bag_ALICEpack#1\tBase.9mmClip\t2\ncontainer\tBase.Bag_ALICEpack#1\tBase.Pistol\t1\ncontainer\tBase.Bag_ALICEpack#1\tBase.Pop\t1")
    local player, contents = spawn()
    eq(#contents, 4)
    eq(contents[1].ammoState.count, 15, "magazine filled")
    eq(contents[2].ammoState.count, 15, "second magazine filled")
    eq(contents[3].ammoState.count, 15, "pistol loaded")
    eq(contents[3].ammoState.containsClip, true, "pistol has its magazine inserted")
    eq(contents[3].ammoState.chambered, true, "pistol has a round chambered")
    eq(contents[4].ammoState.count, nil, "pop is left alone")
    eq(player.primary.ammoState.count, 6, "shotgun in hand loaded")
    eq(player.primary.ammoState.containsClip, nil, "shotgun has no magazine")
    eq(player.primary.ammoState.chambered, nil, "shotgun has no chamber flag")
    CSG_Selection.setOption(CSG_State.selection, "loaded", false)
    player, contents = spawn()
    eq(contents[1].ammoState.count, nil, "magazine empty with the option off")
    eq(contents[3].ammoState.containsClip, nil, "pistol untouched with the option off")
    eq(player.primary.ammoState.count, nil)
end)

test("the panel's loaded tick box drives the option and saves it", function()
    CSG_State.selection = CSG_Selection.new()
    local screen = Stubs.screen(worn({ "Base.Belt2", "Belt" }))
    local panel = panelOf(screen)
    eq(panel.loadedTick ~= nil, true, "tick box present")
    eq(panel.loadedTick:isSelected(1), true, "on by default")
    panel.loadedTick:toggle(1)
    eq(CSG_State.selection.options.loaded, false)
    eq(Stubs.files["ChooseStartingGear_last.txt"], "option\tloaded\t0", "saved")
    panel:rebuild()
    eq(panel.loadedTick:isSelected(1), false, "rebuild keeps the choice")
    panel.loadedTick:toggle(1)
    eq(CSG_State.selection.options.loaded, true)
end)

test("every panel widget draws with the Java object that is attached to the panel", function()
    CSG_State.selection = CSG_Selection.new()
    local screen = Stubs.screen(worn({ "Base.Belt2", "Belt" }, { "Base.Bag_ALICEpack", "Back" }))
    local panel = panelOf(screen)
    eq(#bagButtons(panel), 1)
    for _, w in ipairs(panel.widgets) do
        eq(w.javaObject, w.attachedJavaObject, (w.title or w.name or "widget") .. " java object")
        eq(w.instantiations, 1, (w.title or w.name or "widget") .. " instantiated once")
    end
end)

local function partCombos(panel)
    local out = {}
    for _, w in ipairs(panel.widgets) do if w.csgPartKey then out[w.csgPartKey] = w end end
    return out
end

test("firearm attachments are chosen per firearm on the panel and fitted at spawn", function()
    CSG_State.selection = CSG_Selection.new()
    local screen = Stubs.screen(worn({ "Base.Bag_ALICEpack", "Back" }))
    local panel = panelOf(screen)
    eq(has(labels(panel), "UI_CSG_FirearmParts"), true, "section heading")
    eq(has(labels(panel), "UI_CSG_NoFirearms"), true, "hint before any firearm is chosen")
    combos(panel).primary:pick("Base.Pistol")
    local parts = partCombos(panel)
    eq(parts["Base.Pistol|Scope"] ~= nil, true, "scope combo for the pistol after choosing it")
    eq(#parts["Base.Pistol|Scope"].options, 3, "None + red dot + 2x scope")
    eq(#parts["Base.Pistol|Canon"].options, 2, "None + laser")
    local redDot
    for _, o in ipairs(parts["Base.Pistol|Scope"].options) do if o.data == "Base.RedDot" then redDot = o end end
    eq(redDot.text, "Red Dot Sight  (UI_CSG_Effect_Sight 2-10, UI_CSG_Effect_AimingTime -10, UI_CSG_Effect_Weight +0.2)", "effects shown in the option itself")
    eq(redDot.tooltip:find("UI_CSG_Effect_AimingTime -10", 1, true) ~= nil, true, "and in its tooltip")
    parts["Base.Pistol|Scope"]:pick("Base.RedDot")
    parts["Base.Pistol|Canon"]:pick("Base.Laser")
    eq(CSG_Selection.weaponParts(CSG_State.selection, "Base.Pistol").Scope, "Base.RedDot")
    eq(Stubs.files["ChooseStartingGear_last.txt"]:find("part\tBase.Pistol\tScope\tBase.RedDot", 1, true) ~= nil, true, "saved")
    CSG_Selection.addToContainer(CSG_State.selection, "Base.Bag_ALICEpack#1", "Base.Pistol", 2)
    CSG_Selection.addToContainer(CSG_State.selection, "Base.Bag_ALICEpack#1", "Base.Shotgun", 1)
    CSG_Selection.setWeaponPart(CSG_State.selection, "Base.Shotgun", "Scope", "Base.RedDot")
    panel:rebuild()
    local scope = partCombos(panel)["Base.Pistol|Scope"]
    eq(scope:getOptionData(scope.selected), "Base.RedDot", "rebuild shows the chosen scope")
    eq(partCombos(panel)["Base.Shotgun|Scope"], nil, "no scope row: nothing in the list mounts a scope on the shotgun")
    eq(partCombos(panel)["Base.Shotgun|Canon"] ~= nil, true)

    screen:onOptionMouseDown({ internal = "NEXT" })
    local player = Stubs.player(worn({ "Base.Bag_ALICEpack", "Back" }))
    Stubs.currentPlayer = player
    Events.OnNewGame.fire(player, nil)
    Events.OnTick.fire()
    local held = player.primary
    eq(held.parts.Scope.item:getFullType(), "Base.RedDot", "held pistol has its sight")
    eq(held.parts.Canon.item:getFullType(), "Base.Laser", "and its laser")
    eq(held.parts.Scope.chr, player, "attached by the player, like the vanilla upgrade action")
    eq(held.parts.Scope.applyStats, true, "with the part's stat changes")
    eq(held.parts.Scope.ammoWhenAttached, nil, "parts go on before the gun is loaded")
    eq(held.ammoState.count, 15, "and the gun is still loaded")
    local contents = player.worn[1].item.contents
    eq(contents[1].parts.Scope.item:getFullType(), "Base.RedDot", "every pistol in the bag gets the parts")
    eq(contents[2].parts.Scope.item:getFullType(), "Base.RedDot")
    eq(contents[3].parts.Scope, nil, "a part that does not mount on the shotgun is skipped")
end)
