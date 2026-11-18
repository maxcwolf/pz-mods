--- Tests for editing a crew member's skills and gear, against A-Life's real
--- companion, weapon and shell-state code.
local World = ARE_World
local Hooks = ALifeRepEditor.Hooks
local Crew = ALifeRepEditor.Crew

local Bodies = ARE_Bodies
local ITEMS, makeItem, stand, body = Bodies.ITEMS, Bodies.makeItem, Bodies.stand, Bodies.body

--- Builds a world with Pia in the player's crew, loaded beside them, and returns world and body.
local function crewWorld()
    local world = World.new()
    ProjectALife.Watchdog = { bindings = {} }
    Crew.adapters = { itemInfo = function(itemType) return ITEMS[itemType] end }
    stand(world.player, 10, 10)
    World.addNpc("p1", "ash", "g1", "Pia")
    local shell = body("p1", 11, 10)
    local state = Hooks.handle(world.player, "personJoinCrew", { uid = "p1" })
    ok(not state.failed, state.message)
    return world, shell
end

--- Undoes the crew world's changes to shared A-Life modules.
local function cleanUp()
    ProjectALife.Watchdog = nil
    Crew.adapters = {}
end

--- Returns the companion skills A-Life holds for an NPC.
local function skills(uid)
    return ProjectALife.ActorRegistry.read(uid).memory.companion.state.skills
end

test("the Crew tab lists your crew and picks the first one", function()
    local world = crewWorld()
    World.addNpc("p2", "ash", "g2", "Abe")
    body("p2", 12, 10)
    Hooks.handle(world.player, "personJoinCrew", { uid = "p2" })
    local state = Hooks.handle(world.player, "refresh", {})
    eq(#state.crewMembers, 2); eq(state.crewMembers[1].name, "Abe Doe")
    eq(state.crewPick, "p2"); eq(state.crewMember.name, "Abe Doe")
    state = Hooks.handle(world.player, "refresh", { crew = "p1" })
    eq(state.crewPick, "p1"); ok(state.crewMember.loaded)
    eq(state.crewMember.skills.firstAid, 0)
    eq(state.crewMember.ratings.strength, Crew.ratingFallback, "no profile, so the fallback")
    cleanUp()
end)

test("skills are set in A-Life's companion state, kept between 0 and 10", function()
    local world = crewWorld()
    local state = Hooks.handle(world.player, "crewSkill", { crew = "p1", skill = "firstAid", delta = 3 })
    ok(not state.failed, state.message)
    eq(state.message, "Pia Doe: First aid 0 -> 3.")
    eq(skills("p1").firstAid, 3); eq(state.crewMember.skills.firstAid, 3)
    local rules = ProjectALife.CompanionRules
    ok(rules.canDo(ProjectALife.ActorRegistry.read("p1").memory.companion.state, "treat_player",
        { ["Base.Bandage"] = true }), "A-Life now lets them bandage you")
    Hooks.handle(world.player, "crewSkill", { crew = "p1", skill = "firstAid", delta = 50 })
    eq(skills("p1").firstAid, 10)
    ok(Hooks.handle(world.player, "crewSkill", { crew = "p1", skill = "flying", delta = 1 }).failed)
    cleanUp()
end)

test("fighting stats land on the body now and on A-Life's plan when it reloads", function()
    local world, shell = crewWorld()
    local state = Hooks.handle(world.player, "crewRating", { crew = "p1", rating = "aiming", delta = 3 })
    ok(not state.failed, state.message)
    eq(state.message, "Pia Doe: Accuracy 5 -> 8.")
    eq(shell.data.ProjectALifeAiming, 8); eq(shell.variables.ALifeAiming, "8")
    eq(state.crewMember.ratings.aiming, 8)
    local plan = { strength = 1, aiming = 1, clothing = {} }
    eq(Crew.overlay(plan, ProjectALife.ActorRegistry.read("p1")).aiming, 8)
    eq(plan.strength, 1, "strength untouched until set")
    state = Hooks.handle(world.player, "crewMaxAll", { crew = "p1" })
    ok(not state.failed, state.message)
    eq(skills("p1").music, 10); eq(shell.data.ProjectALifeStrength, 10); eq(state.crewMember.ratings.strength, 10)
    cleanUp()
end)

test("A-Life's own plan builder picks up saved stats through the hook", function()
    local world = crewWorld()
    Hooks.handle(world.player, "crewRating", { crew = "p1", rating = "strength", delta = 4 })
    local hydrator = ProjectALife.ProfileHydrator
    local catalog = ProjectALife.Catalog.current
    catalog.npcs = { p_ash = { id = "p_ash", general = { name = "Guard", faction = "ash", strength = 2, aiming = 3 } } }
    local record = ProjectALife.ActorRegistry.read("p1")
    local ran, plan = pcall(hydrator.plan, record)
    catalog.npcs = {}
    ok(ran, tostring(plan))
    ok(type(plan) == "table", "A-Life built a plan")
    eq(plan.strength, 9); eq(plan.aiming, 3)
    cleanUp()
end)

test("giving a gun hands it over, holds it, allows guns and adds ammo", function()
    local world, shell = crewWorld()
    local state = Hooks.handle(world.player, "crewGive", { crew = "p1", item = "Base.Shotgun" })
    ok(not state.failed, state.message)
    eq(state.message, "Pia Doe is holding the Shotgun, with 60 rounds.")
    local gun = shell.inventory.items.list[1]
    eq(gun.data.ProjectALifeWeaponSlot, "primary"); ok(gun.data.ProjectALifeActiveWeapon)
    eq(shell.data.ProjectALifePrimaryAmmoUnits, 60); eq(shell.data.ProjectALifeFirearmsAuthored, true)
    eq(state.crewMember.weapon.name, "Shotgun"); eq(state.crewMember.weapon.spare, 60)
    eq(state.crewMember.items[1].equipped, true)
    state = Hooks.handle(world.player, "crewAmmo", { crew = "p1", rounds = 40 })
    eq(state.message, "Gave Pia Doe 40 rounds; 100 spare now.")
    local plan = Crew.overlay({ firearmsAuthored = false }, ProjectALife.ActorRegistry.read("p1"))
    ok(plan.firearmsAuthored, "guns stay allowed after a reload")
    cleanUp()
end)

test("a melee weapon can be swapped in and a held weapon taken back", function()
    local world, shell = crewWorld()
    Hooks.handle(world.player, "crewGive", { crew = "p1", item = "Base.Pistol" })
    local state = Hooks.handle(world.player, "crewGive", { crew = "p1", item = "Base.Axe" })
    eq(state.message, "Pia Doe is holding the Axe.")
    eq(state.crewMember.weapon.name, "Axe")
    local pistol
    for _, row in ipairs(state.crewMember.items) do
        if row.name == "M9 Pistol" then pistol = row end
    end
    eq(shell.inventory.items.list[1].data.ProjectALifeWeaponSlot, "secondary")
    state = Hooks.handle(world.player, "crewEquip", { crew = "p1", id = pistol.id })
    ok(not state.failed, state.message); eq(state.crewMember.weapon.name, "M9 Pistol")
    state = Hooks.handle(world.player, "crewRemove", { crew = "p1", id = pistol.id })
    eq(state.message, "Took the M9 Pistol from Pia Doe.")
    eq(#shell.inventory.items.list, 1)
    eq(Hooks.handle(world.player, "crewAmmo", { crew = "p1", rounds = 10 }).message, "Pia Doe isn't holding a gun.")
    cleanUp()
end)

test("other items are carried, kept by A-Life when the body unloads, and taken back as a stack", function()
    local world, shell = crewWorld()
    local state = Hooks.handle(world.player, "crewGive", { crew = "p1", item = "Base.Bandage", count = 4 })
    eq(state.message, "Gave Pia Doe 4 x Bandage.")
    eq(#shell.inventory.items.list, 4); ok(shell.inventory.items.list[1].data.ProjectALifeScavenged)
    eq(state.crewMember.items[1].count, 4)
    state = Hooks.handle(world.player, "crewRemove", { crew = "p1", id = state.crewMember.items[1].id })
    eq(state.message, "Took 4 x Bandage from Pia Doe."); eq(#shell.inventory.items.list, 0)
    ok(Hooks.handle(world.player, "crewGive", { crew = "p1", item = "Base.Nope" }).failed)
    cleanUp()
end)

test("clothing is worn with A-Life's redress, saved for reloads and pinned against the seasons", function()
    local world, shell = crewWorld()
    shell.data.ProjectALifeClothingTypes = { "Base.Cap", "Base.Tee" }
    shell.data.ProjectALifeClothingTints = { "red", "" }
    local hydrator = ProjectALife.ProfileHydrator
    local redress = hydrator.redress
    local dressed
    hydrator.redress = function(target, outfit) dressed = outfit; return target == shell end
    Crew.adapters.itemInfo = function(itemType) return ITEMS[itemType] end
    local state = Hooks.handle(world.player, "crewGive", { crew = "p1", item = "Base.Beret" })
    ok(not state.failed, state.message)
    eq(state.message, "Pia Doe is wearing the Beret.")
    eq(#dressed, 2); eq(dressed[1].itemType, "Base.Tee"); eq(dressed[2].itemType, "Base.Beret")
    local record = ProjectALife.ActorRegistry.read("p1")
    ok(hydrator.wardrobePinned(record), "A-Life's seasonal wardrobe leaves it alone")
    eq(Crew.overlay({ clothing = {} }, record).clothing[2].itemType, "Base.Beret")
    local beret = makeItem("Base.Beret")
    beret.data.ProjectALifeAuthoredClothing = true
    shell.inventory.items.list[#shell.inventory.items.list + 1] = beret
    state = Hooks.handle(world.player, "crewRemove", { crew = "p1", id = beret.id })
    eq(state.message, "Pia Doe took off the Beret."); eq(#dressed, 1)
    Crew.saved("p1", true).outfit = { { itemType = "Base.Beret" } }
    state = Hooks.handle(world.player, "crewRemove", { crew = "p1", id = beret.id })
    eq(state.message, "Pia Doe needs to keep at least one piece of clothing on.")
    Crew.forget("p1")
    ok(not hydrator.wardrobePinned(record), "forgetting unpins")
    hydrator.redress = redress
    cleanUp()
end)

test("only your loaded crew members can be edited", function()
    local world, shell = crewWorld()
    World.addNpc("p2", "ash", "g2", "Abe")
    body("p2", 12, 10)
    eq(Hooks.handle(world.player, "crewSkill", { crew = "p2", skill = "music", delta = 1 }).message, "Abe Doe isn't in your crew.")
    eq(Hooks.handle(world.player, "crewSkill", { crew = "nobody", skill = "music", delta = 1 }).message,
        "That person isn't around any more.")
    ProjectALife.Watchdog.bindings["p1"] = nil
    local state = Hooks.handle(world.player, "crewGive", { crew = "p1", item = "Base.Axe" })
    eq(state.message, "Pia Doe is too far away to hand things to; get closer and try again.")
    ok(not Hooks.handle(world.player, "crewSkill", { crew = "p1", skill = "music", delta = 1 }).failed,
        "skills can still be set while they're away")
    eq(#state.crewMember.items, 0); ok(not state.crewMember.loaded)
    ok(shell ~= nil)
    cleanUp()
end)
