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

test("choices update the selection, the bag rows and the saved file", function()
    local screen = Stubs.screen(worn({ "Base.Belt2", "Belt" }, { "Base.Bag_ALICEpack", "Back" }))
    local panel = panelOf(screen)
    local c = combos(panel)
    c.SmallBeltLeft:pick("Base.Wrench")
    c.SmallBeltRight:pick("Base.Machete")
    c.Back:pick("Base.AssaultRifle")
    c.primary:pick("Base.Crowbar")
    local key = "Base.Bag_ALICEpack#1"
    panel:onContainerAdd("Base.Pop", key)
    panel:onContainerAdd("Base.Pop", key)
    panel:onContainerAdd("Base.WaterBottleFull", key)
    eq(CSG_State.selection.attachments.SmallBeltLeft, "Base.Wrench")
    eq(CSG_Selection.containerItems(CSG_State.selection, key)[1].count, 2)
    eq(has(labels(panel), "ALICE Pack - Back   (UI_CSG_Weight 1.4 / 27)"), true, "weight updates")
    eq(has(labels(panel), "2x Pop"), true)
    -- the search box lists matches and picking one adds it
    local search
    for _, w in ipairs(panel.widgets) do if w.entry then search = w end end
    search.entry:type("wat")
    eq(#search.list.items, 1)
    search.list:clickRow(1)
    eq(CSG_Selection.containerItems(CSG_State.selection, key)[2].count, 2, "water bottle added via search")
    eq(Stubs.files["ChooseStartingGear_last.txt"] ~= nil, true, "selection saved")
    -- minus / remove buttons
    for _, w in ipairs(panel.widgets) do if w.title == "-" and w.arg1.fullType == "Base.Pop" then w:click(); break end end
    eq(CSG_Selection.containerItems(CSG_State.selection, key)[1].count, 1)
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
