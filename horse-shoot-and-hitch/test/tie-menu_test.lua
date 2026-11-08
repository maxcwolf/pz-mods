local Stubs = HSH_Stubs
local TieMenu = require("HorseShootAndHitch/tie-menu")
local TieHorseAction = require("HorseShootAndHitch/tie-horse-action")
local HorseManager = require("HorseMod/HorseManager")

--- Builds a lamp post and returns it with its square.
local function lampPost(x)
    local square = Stubs.square(x, 50, 0)
    return Stubs.object(square, "lighting_outdoor_01_1"), square
end

test("the tie action is allowed in the saddle so it can queue after dismounting", function()
    eq(Stubs.validActions["HorseShootAndHitch_TieHorseAction"], true)
end)

test("a rider next to a post gets Dismount and tie", function()
    local post, square = lampPost(2000)
    local horse = Stubs.horse({ x = square.x + 1.5, y = square.y + 0.5, reins = true })
    local player = Stubs.player({})
    Stubs.mounts.riders[player] = horse
    Stubs.currentPlayer = player
    local menu = Stubs.contextMenu()
    TieMenu.onFillWorldObjectContextMenu(0, menu, { post }, false)
    Stubs.mounts.riders[player] = nil
    eq(#menu.options, 1)
    eq(menu.options[1].name, "ContextMenu_HorseShootAndHitch_DismountAndTie(IGUI_HorseShootAndHitch_Post)")
    eq(menu.options[1].notAvailable, nil)
end)

test("choosing Dismount and tie queues the dismount, then the tie", function()
    local post, square = lampPost(2100)
    local horse = Stubs.horse({ x = square.x + 1.5, y = square.y + 0.5, reins = true })
    local player = Stubs.player({})
    Stubs.queue = {}
    Stubs.dismounts = {}
    TieMenu.onDismountAndTie(player, horse, post)
    eq(#Stubs.dismounts, 1)
    eq(Stubs.queue[#Stubs.queue].Type, "HorseShootAndHitch_TieHorseAction")
    eq(Stubs.queue[#Stubs.queue].post, post)
end)

test("a rider too far from the post gets no option", function()
    local post, square = lampPost(2200)
    local horse = Stubs.horse({ x = square.x + 6.5, y = square.y + 0.5, reins = true })
    local player = Stubs.player({})
    Stubs.mounts.riders[player] = horse
    Stubs.currentPlayer = player
    local menu = Stubs.contextMenu()
    TieMenu.onFillWorldObjectContextMenu(0, menu, { post }, false)
    Stubs.mounts.riders[player] = nil
    eq(#menu.options, 0)
end)

test("without reins or rope the option is greyed out with a reason", function()
    local post, square = lampPost(2300)
    local horse = Stubs.horse({ x = square.x + 1.5, y = square.y + 0.5 })
    local player = Stubs.player({})
    Stubs.mounts.riders[player] = horse
    Stubs.currentPlayer = player
    local menu = Stubs.contextMenu()
    TieMenu.onFillWorldObjectContextMenu(0, menu, { post }, false)
    Stubs.mounts.riders[player] = nil
    eq(menu.options[1].notAvailable, true)
    eq(menu.options[1].toolTip.name, "Tooltip_HorseShootAndHitch_NeedReinsOrRope")
end)

test("on foot, each loose horse near the post gets a Tie option", function()
    local post, square = lampPost(2400)
    local near1 = Stubs.horse({ x = square.x + 2.5, y = square.y + 0.5, name = "Dusty", reins = true })
    local far = Stubs.horse({ x = square.x + 9.5, y = square.y + 0.5, name = "Far" })
    HorseManager.horses = { near1, far }
    local player = Stubs.player({})
    Stubs.currentPlayer = player
    local menu = Stubs.contextMenu()
    TieMenu.onFillWorldObjectContextMenu(0, menu, { post }, false)
    HorseManager.horses = {}
    eq(#menu.options, 1)
    eq(menu.options[1].name, "ContextMenu_HorseShootAndHitch_TieTo(Dusty,IGUI_HorseShootAndHitch_Post)")
end)

test("clicking something that is not a fence, pole or tree adds nothing", function()
    local square = Stubs.square(2500, 50, 0)
    local wall = Stubs.object(square, "walls_exterior_house_01_0")
    local menu = Stubs.contextMenu()
    Stubs.currentPlayer = Stubs.player({})
    TieMenu.onFillWorldObjectContextMenu(0, menu, { wall }, false)
    eq(#menu.options, 0)
end)

test("the tie action refuses a horse that is too far from the post", function()
    local post, square = lampPost(2600)
    Stubs.square(square.x + 9, square.y, 0)
    local horse = Stubs.horse({ x = square.x + 9.5, y = square.y + 0.5, reins = true })
    local player = Stubs.player({})
    function player:getSquare() return square end
    local action = TieHorseAction:new(player, horse, post)
    eq(action:isValid(), false)
    horse.x = square.x + 2.5
    Stubs.square(square.x + 2, square.y, 0)
    eq(action:isValid(), true)
end)

test("completing the tie action ties the horse", function()
    local post, square = lampPost(2700)
    local horse = Stubs.horse({ x = square.x + 1.5, y = square.y + 0.5, reins = true })
    local player = Stubs.player({})
    TieHorseAction:new(player, horse, post):complete()
    eq(require("HorseShootAndHitch/tether-world").get(horse).cost, "reins")
end)
