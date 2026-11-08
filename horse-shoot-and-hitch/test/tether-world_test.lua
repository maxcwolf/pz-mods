local Stubs = HSH_Stubs
local TetherWorld = require("HorseShootAndHitch/tether-world")
local HorseManager = require("HorseMod/HorseManager")
local Mounts = require("HorseMod/Mounts")

--- Builds a post square with a low fence and a horse two tiles away.
local function scene(opts)
    opts = opts or {}
    local square = Stubs.square(opts.x or 100, opts.y or 200, 0)
    local post = Stubs.object(square, "fencing_01_3", { hoppable = true, name = opts.postName })
    local horse = Stubs.horse({ x = square.x + 2.5, y = square.y + 0.5, reins = opts.reins })
    local player = Stubs.player({ items = opts.items })
    return square, post, horse, player
end

test("tying with reins uses no rope and records the tie", function()
    local square, post, horse, player = scene({ reins = true, items = { "Base.Rope" } })
    eq(TetherWorld.tie(player, horse, post), true)
    local record = TetherWorld.get(horse)
    eq(record.cost, "reins")
    eq(record.x, square.x); eq(record.y, square.y); eq(record.sprite, "fencing_01_3")
    eq(player.inventory:count("Base.Rope"), 1, "rope kept")
    eq(horse:getData():getAttachedTree(), post, "vanilla tie set for the rope drawing")
end)

test("tying without reins takes one rope", function()
    local _, post, horse, player = scene({ items = { "Base.Rope", "Base.Rope" } })
    eq(TetherWorld.tie(player, horse, post), true)
    eq(TetherWorld.get(horse).cost, "rope")
    eq(player.inventory:count("Base.Rope"), 1)
end)

test("tying fails with neither reins nor rope", function()
    local _, post, horse, player = scene()
    eq(TetherWorld.tie(player, horse, post), false)
    eq(TetherWorld.get(horse), nil)
end)

test("an unnamed fence gets a readable name, a named one keeps its own", function()
    local _, post, horse, player = scene({ reins = true })
    TetherWorld.tie(player, horse, post)
    eq(post:getName(), "IGUI_HorseShootAndHitch_Fence")
    local _, named, horse2, player2 = scene({ reins = true, x = 300, postName = "Gate" })
    TetherWorld.tie(player2, horse2, named)
    eq(named:getName(), "Gate")
end)

test("tying a leashed horse takes it off the leash", function()
    local _, post, horse, player = scene({ reins = true })
    player.attached:add(horse)
    horse:getData():setAttachedPlayer(player)
    TetherWorld.tie(player, horse, post)
    eq(player.attached:contains(horse), false)
    eq(horse:getData():getAttachedPlayer(), nil)
end)

test("untying a rope tie hands the rope back", function()
    local _, post, horse, player = scene({ items = { "Base.Rope" } })
    TetherWorld.tie(player, horse, post)
    eq(TetherWorld.untie(horse, player), true)
    eq(player.inventory:count("Base.Rope"), 1)
    eq(TetherWorld.get(horse), nil)
    eq(horse:getData():getAttachedTree(), nil)
end)

test("untying a reins tie gives no rope", function()
    local _, post, horse, player = scene({ reins = true })
    TetherWorld.tie(player, horse, post)
    TetherWorld.untie(horse, player)
    eq(player.inventory:count("Base.Rope"), 0)
end)

test("untying with nobody there drops the rope at the post", function()
    local square, post, horse, player = scene({ items = { "Base.Rope" } })
    TetherWorld.tie(player, horse, post)
    TetherWorld.untie(horse, nil)
    eq(square.worldItems[1], "Base.Rope")
end)

test("after a reload the tie is re-linked to its post", function()
    local _, post, horse, player = scene({ reins = true, x = 400 })
    TetherWorld.tie(player, horse, post)
    horse:getData():setAttachedTree(nil)
    TetherWorld.restore(horse)
    eq(horse:getData():getAttachedTree(), post)
end)

test("a horse whose post was destroyed is freed and the rope left behind", function()
    local square, post, horse, player = scene({ items = { "Base.Rope" }, x = 500 })
    TetherWorld.tie(player, horse, post)
    square.objects:remove(post)
    horse:getData():setAttachedTree(nil)
    TetherWorld.restore(horse)
    eq(TetherWorld.get(horse), nil)
    eq(square.worldItems[1], "Base.Rope")
end)

test("restore waits while the post's square is not loaded", function()
    local square, post, horse, player = scene({ reins = true, x = 600 })
    TetherWorld.tie(player, horse, post)
    horse:getData():setAttachedTree(nil)
    Stubs.squares[square.x .. "," .. square.y .. ",0"] = nil
    TetherWorld.restore(horse)
    eq(TetherWorld.get(horse) ~= nil, true, "still tied")
end)

test("a horse inside the radius is left alone", function()
    local _, post, horse, player = scene({ reins = true, x = 700 })
    TetherWorld.tie(player, horse, post)
    local stops = horse.stops
    TetherWorld.enforce(horse, 2)
    eq(#horse.paths, 0)
    eq(horse.stops, stops)
end)

test("a horse past the radius is walked back toward the post", function()
    local square, post, horse, player = scene({ reins = true, x = 800 })
    TetherWorld.tie(player, horse, post)
    horse.x = square.x + 5.5
    TetherWorld.enforce(horse, 2)
    eq(#horse.paths, 1)
    eq(horse.paths[1][1], square.x + 1)
    eq(horse.paths[1][2], square.y)
end)

test("a horse found far away is put back next to the post", function()
    local square, post, horse, player = scene({ reins = true, x = 900 })
    TetherWorld.tie(player, horse, post)
    horse.x = square.x + 30.5
    TetherWorld.enforce(horse, 2)
    eq(#horse.paths, 0)
    eq(horse.x, square.x + 1.5)
end)

test("a horse with a rider is never pulled back", function()
    local square, post, horse, player = scene({ reins = true, x = 1000 })
    TetherWorld.tie(player, horse, post)
    horse.x = square.x + 5.5
    Stubs.mounts.horses[horse] = player
    TetherWorld.enforce(horse, 2)
    Stubs.mounts.horses[horse] = nil
    eq(#horse.paths, 0)
end)

test("the horse manager system checks every 20 ticks", function()
    local system = HorseManager.systems[1]
    eq(system ~= nil, true, "system registered")
    local square, post, horse, player = scene({ reins = true, x = 1100 })
    TetherWorld.tie(player, horse, post)
    horse.x = square.x + 5.5
    system.ticks = 0
    for _ = 1, 19 do system:update({ horse }, 0.016) end
    eq(#horse.paths, 0, "not yet")
    system:update({ horse }, 0.016)
    eq(#horse.paths, 1, "on the 20th tick")
end)

test("mounting a tied horse unties it and returns a rope", function()
    local _, post, horse, player = scene({ items = { "Base.Rope" }, x = 1200 })
    TetherWorld.tie(player, horse, post)
    Mounts.onMount:trigger(player, horse)
    eq(TetherWorld.get(horse), nil)
    eq(player.inventory:count("Base.Rope"), 1)
end)

test("vanilla Detach on a reins tie clears it without a free rope", function()
    local _, post, horse, player = scene({ reins = true, x = 1300 })
    TetherWorld.tie(player, horse, post)
    local before = ISAttachAnimalToTree.ropesGiven
    local action = setmetatable({ animal = horse, remove = true, character = player }, { __index = ISAttachAnimalToTree })
    action:complete()
    eq(TetherWorld.get(horse), nil)
    eq(ISAttachAnimalToTree.ropesGiven, before)
end)

test("vanilla Detach on a rope tie clears it and returns the rope once", function()
    local _, post, horse, player = scene({ items = { "Base.Rope" }, x = 1400 })
    TetherWorld.tie(player, horse, post)
    local before = ISAttachAnimalToTree.ropesGiven
    local action = setmetatable({ animal = horse, remove = true, character = player }, { __index = ISAttachAnimalToTree })
    action:complete()
    eq(TetherWorld.get(horse), nil)
    eq(ISAttachAnimalToTree.ropesGiven, before + 1)
end)

test("vanilla leash on a reins-tied horse clears the tie without a free rope", function()
    local _, post, horse, player = scene({ reins = true, x = 1500 })
    TetherWorld.tie(player, horse, post)
    local before = ISAttachAnimalToPlayer.ropesGiven
    local action = setmetatable({ animal = horse, remove = false, character = player }, { __index = ISAttachAnimalToPlayer })
    action:complete()
    eq(TetherWorld.get(horse), nil)
    eq(ISAttachAnimalToPlayer.ropesGiven, before)
end)

test("vanilla Detach on an animal this mod did not tie is untouched", function()
    local square = Stubs.square(1600, 0, 0)
    local tree = Stubs.object(square, "e_americanholly_1_0", { tree = true })
    local horse = Stubs.horse({})
    horse:getData():setAttachedTree(tree)
    local before = ISAttachAnimalToTree.ropesGiven
    local action = setmetatable({ animal = horse, remove = true }, { __index = ISAttachAnimalToTree })
    action:complete()
    eq(ISAttachAnimalToTree.ropesGiven, before + 1)
end)

test("findTiePoint prefers the post with the stored sprite", function()
    local square = Stubs.square(1700, 0, 0)
    Stubs.object(square, "lighting_outdoor_01_1")
    local fence = Stubs.object(square, "fencing_01_3", { hoppable = true })
    eq(TetherWorld.findTiePoint(square, "fencing_01_3"), fence)
end)

test("walls and furniture are not tie points", function()
    local square = Stubs.square(1800, 0, 0)
    local wall = Stubs.object(square, "walls_exterior_house_01_0")
    eq(TetherWorld.isTiePoint(wall), false)
    eq(TetherWorld.findTiePoint(square, nil), nil)
end)
