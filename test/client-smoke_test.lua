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
    for _, w in ipairs(panel.widgets) do if w.options then out[w.onChangeArgs[1]] = w end end
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
    eq(#CSG_State.entries, 10, "catalog size without hidden and moveables")
    local c = combos(panel)
    eq(c.primary ~= nil, true, "primary hand combo")
    eq(c.SmallBeltLeft ~= nil, true, "belt left combo")
    eq(c.AliceSling ~= nil, true, "sling combo from modded clothing")
    eq(#c.AliceSling.options, 2, "sling lists None + rifle")
    eq(#c.SmallBeltLeft.options, 3, "belt lists None + wrench + machete")
    eq(#c.Back.options, 2, "back with bag: rifle moves to bag model, crowbar blocked")
    eq(has(labels(panel), "ALICE Pack - Back   (UI_CSG_Weight 0.0 / 27)"), true, "bag header")
    eq(has(labels(panel), "Satchel - Satchel   (UI_CSG_Weight 0.0 / 12)"), true, "satchel header")
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
    buttonsTitled(panel, "UI_CSG_EditContents")[1]:click()
    local dialog = CSG_BagContentsDialog.instance
    eq(dialog ~= nil, true, "dialog created")
    eq(dialog.bagKey, key)
    eq(#dialog.catalogList.items, 10, "catalog lists everything with no filter")
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
    eq(#dialog.contentsList.items, 2)
    dialog.contentsList.selected = 1
    dialog:onAdjustClicked(nil, -1)
    eq(CSG_Selection.containerItems(CSG_State.selection, key)[1].count, 1, "-1 adjusts")
    eq(dialog.weightLabel.name, "UI_CSG_Weight 1.4 / 27", "weight label")
    eq(has(labels(panel), "ALICE Pack - Back   (UI_CSG_Weight 1.4 / 27)"), true, "panel header follows the dialog")
    eq(has(labels(panel), "1x Water Bottle, 2x Pop"), true, "panel summary")
    dialog.contentsList.selected = 2
    dialog:onRemoveClicked()
    eq(#CSG_Selection.containerItems(CSG_State.selection, key), 1)
    dialog:onEmptyClicked()
    eq(#CSG_Selection.containerItems(CSG_State.selection, key), 0)
    CSG_Selection.addToContainer(CSG_State.selection, key, "Base.Pop", 1)
    CSG_Selection.addToContainer(CSG_State.selection, key, "Base.WaterBottleFull", 2)
    dialog:changed()
end)

test("the preview renders the chosen gear on the avatar", function()
    local screen = Stubs.screen(worn({ "Base.Belt2", "Belt" }, { "Base.Bag_ALICEpack", "Back" }))
    local panel = panelOf(screen)
    local model = screen.avatarPanel.avatarPanel
    local avatar = MainScreen.instance.avatar
    eq(model.lastCharacter, avatar, "live character shown once the catalog is ready and gear is chosen")
    eq(#avatar.attachedRaw, 3, "three attached items on the preview")
    eq(avatar.primary:getFullType(), "Base.Crowbar")
    eq(avatar.wornSet ~= nil, true, "worn items copied from the desc")
    eq(avatar.copiedVisual, "visual")
    local c = combos(panel)
    c.Back:pick(nil)
    eq(#avatar.attachedRaw, 2, "clearing a slot updates the preview")
    panel:onClearAll()
    screen.avatarPanel:setSurvivorDesc(MainScreen.instance.desc)
    eq(model.lastCharacter, nil, "vanilla desc preview when nothing is chosen")
    eq(model.lastDesc, MainScreen.instance.desc)
    CSG_State.selection = CSG_Selection.deserialize("attach\tSmallBeltLeft\tBase.Wrench\nattach\tSmallBeltRight\tBase.Machete\nattach\tBack\tBase.AssaultRifle\nhand\tprimary\tBase.Crowbar\ncontainer\tBase.Bag_ALICEpack#1\tBase.Pop\t1\ncontainer\tBase.Bag_ALICEpack#1\tBase.WaterBottleFull\t2")
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

test("spawning without the slot skips the attachment and keeps the rest", function()
    CSG_State.selection = CSG_Selection.deserialize("attach\tAliceSling\tBase.AssaultRifle\nhand\tprimary\tBase.Machete")
    CSG_State.pending = true
    local player = Stubs.player(worn({ "Base.Belt2", "Belt" }))
    Stubs.currentPlayer = player
    local plan
    Events.OnNewGame.fire(player, nil)
    Events.OnTick.fire()
    eq(#player.hotbar.attached, 0)
    eq(player.primary:getFullType(), "Base.Machete")
end)

test("remembered selection survives a reload and prunes unknown items", function()
    Stubs.files["ChooseStartingGear_last.txt"] = "attach\tBack\tBase.Crowbar\nattach\tBack\tGone.Item\ncontainer\tBase.Bag_ALICEpack#1\tBase.Pop\t3"
    CSG_State.loaded = false
    CSG_State.load()
    eq(CSG_State.selection.attachments.Back, nil, "last line wins then pruned as unknown")
    eq(CSG_Selection.containerItems(CSG_State.selection, "Base.Bag_ALICEpack#1")[1].count, 3)
end)
