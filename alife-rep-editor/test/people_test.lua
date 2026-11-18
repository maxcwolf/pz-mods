--- Tests for editing one NPC's relationship, against A-Life's real opinion code.
local World = ARE_World
local Hooks = ALifeRepEditor.Hooks
local People = ALifeRepEditor.People

--- Returns the person with a uid from a window state.
local function person(state, uid)
    for _, entry in ipairs(state.people or {}) do
        if entry.uid == uid then return entry end
    end
    return nil
end

test("the People list holds everyone with an opinion of you, not the dead or strangers", function()
    local world = World.new()
    local met = World.addNpc("p1", "ash", "g1", "Pia")
    World.addNpc("p2", "ash", "g2", "Sam")
    local dead = World.addNpc("p3", "civ", "g3", "Ned")
    ProjectALife.NpcOpinion.note("gift", met, world.player)
    ProjectALife.NpcOpinion.note("gift", dead, world.player)
    ProjectALife.ActorRegistry.records["p3"].lifecycle = "dead"
    local state = Hooks.handle(world.player, "refresh", {})
    ok(state.peopleOn, "opinions on")
    eq(#state.opinionBands, 7)
    local pia = person(state, "p1")
    ok(pia ~= nil, "met NPC listed")
    eq(pia.name, "Pia Doe"); eq(pia.factionName, "Ashguard"); ok(pia.met)
    eq(pia.label, ProjectALife.NpcOpinion.labelOf(pia.value))
    eq(person(state, "p2"), nil, "a stranger is not listed")
    eq(person(state, "p3"), nil, "the dead are not listed")
end)

test("focusing a stranger lists them first, with their stance", function()
    local world = World.new()
    ProjectALife.NpcOpinion.note("gift", World.addNpc("p1", "ash", "g1", "Pia"), world.player)
    World.addNpc("p2", "blk", "g2", "Sam")
    local state = Hooks.handle(world.player, "refresh", { focus = "p2" })
    eq(state.focus, "p2")
    eq(state.people[1].uid, "p2", "focused first")
    ok(not state.people[1].met, "not met yet")
    eq(state.people[1].stance, "hostile", "Blacktop is hostile by default")
end)

test("adjusting a person moves their opinion and leaves a reason A-Life shows", function()
    local world = World.new()
    World.addNpc("p1", "ash", "g1", "Pia")
    local before = ProjectALife.NpcOpinion.valueOf(ProjectALife.ActorRegistry.read("p1"), world.player)
    local state = Hooks.handle(world.player, "personNudge", { uid = "p1", delta = 25 })
    ok(not state.failed, state.message)
    eq(World.opinion(world, "p1").v, before + 25)
    eq(World.opinion(world, "p1").why, People.WARMED)
    eq(person(state, "p1").value, before + 25, "the window sees the new value")
    ok(string.find(state.message, "Pia Doe:", 1, true) == 1, state.message)
    Hooks.handle(world.player, "personNudge", { uid = "p1", delta = -500 })
    eq(World.opinion(world, "p1").v, -100, "kept inside -100..100")
    eq(World.opinion(world, "p1").why, People.SOURED)
    local payload = ProjectALife.NpcOpinion.payload(ProjectALife.ActorRegistry.read("p1"), world.player)
    eq(payload.label, "Hates you"); eq(payload.reason, People.SOURED)
end)

test("setting a relationship jumps to the middle of that label", function()
    local world = World.new()
    World.addNpc("p1", "ash", "g1", "Pia")
    local state = Hooks.handle(world.player, "personSetBand", { uid = "p1", band = 6 })
    ok(not state.failed, state.message)
    eq(World.opinion(world, "p1").v, 56)
    eq(person(state, "p1").label, "Trusts you")
    ok(Hooks.handle(world.player, "personSetBand", { uid = "p1", band = 99 }).failed, "unknown band refused")
end)

test("a set opinion still drifts back the way A-Life drifts it", function()
    local world = World.new()
    local record = World.addNpc("p1", "ash", "g1", "Pia")
    Hooks.handle(world.player, "personSetBand", { uid = "p1", band = 7 })
    local now = ProjectALife.NpcOpinion.valueOf(ProjectALife.ActorRegistry.read("p1"), world.player)
    World.advance(24 * 5)
    local later = ProjectALife.NpcOpinion.valueOf(ProjectALife.ActorRegistry.read("p1"), world.player)
    ok(later < now, "drifted down over five days: " .. now .. " -> " .. later)
    ok(record ~= nil)
end)

test("forget turns a person back into a stranger", function()
    local world = World.new()
    World.addNpc("p1", "ash", "g1", "Pia")
    Hooks.handle(world.player, "personSetBand", { uid = "p1", band = 1 })
    ok(World.opinion(world, "p1") ~= nil)
    local state = Hooks.handle(world.player, "personForget", { uid = "p1" })
    ok(not state.failed, state.message)
    eq(World.opinion(world, "p1"), nil, "row gone")
    ok(not person(state, "p1").met, "still shown while focused, as a stranger")
    ok(string.find(Hooks.handle(world.player, "personForget", { uid = "p1" }).message, "already", 1, true) ~= nil)
end)

test("calm down clears a personal grudge and make hostile sets one", function()
    local world = World.new()
    local record = World.addNpc("p1", "ash", "g1", "Pia")
    local state = Hooks.handle(world.player, "personHostile", { uid = "p1" })
    ok(not state.failed, state.message)
    record = ProjectALife.ActorRegistry.read("p1")
    eq(record.memory.hostileToPlayerKeys[world.key], true)
    ok(person(state, "p1").hostile, "window sees the grudge")
    eq(person(state, "p1").stance, "hostile")
    ProjectALife.ActorRegistry.update("p1", record.revision, function(fresh)
        fresh.memory.carefulPlayerKeys = { [world.key] = getTimestampMs() + 60000 }
    end)
    state = Hooks.handle(world.player, "personCalm", { uid = "p1" })
    ok(not state.failed, state.message)
    record = ProjectALife.ActorRegistry.read("p1")
    eq(record.memory.hostileToPlayerKeys[world.key], nil)
    eq(record.memory.carefulPlayerKeys[world.key], nil)
    eq(person(state, "p1").stance, "neutral", "back to Ashguard's usual")
end)

test("calming someone whose faction is hostile says to forgive the faction", function()
    local world = World.new()
    World.addNpc("p1", "blk", "g1", "Sam")
    local state = Hooks.handle(world.player, "personCalm", { uid = "p1" })
    ok(string.find(state.message, "faction is still hostile", 1, true) ~= nil, state.message)
end)

test("person commands refuse missing or dead NPCs and opinions switched off", function()
    local world = World.new()
    local record = World.addNpc("p1", "ash", "g1", "Pia")
    ok(Hooks.handle(world.player, "personNudge", { uid = "nobody", delta = 5 }).failed)
    record.lifecycle = "dead"
    ok(Hooks.handle(world.player, "personSetBand", { uid = "p1", band = 3 }).failed)
    record.lifecycle = "active"
    SandboxVars.ALife.Reputation_NpcOpinion = false
    local state = Hooks.handle(world.player, "personNudge", { uid = "p1", delta = 5 })
    SandboxVars.ALife.Reputation_NpcOpinion = nil
    ok(state.failed); eq(state.message, People.OFF)
    ok(not state.peopleOn); eq(#state.people, 0)
end)

--- Stands the player at a spot, as an IsoPlayer would report it.
local function stand(player, x, y)
    function player:getX() return x end
    function player:getY() return y end
    function player:getZ() return 0 end
end

--- Loads an NPC's body at a spot, the way A-Life's watchdog binds it, and returns it.
local function body(uid, x, y)
    local shell = { x = x, y = y, data = {} }
    function shell:getX() return self.x end
    function shell:getY() return self.y end
    function shell:getZ() return 0 end
    function shell:isDead() return false end
    function shell:getModData() return self.data end
    ProjectALife.Watchdog = ProjectALife.Watchdog or { bindings = {} }
    ProjectALife.Watchdog.bindings[uid] = { shell = shell }
    return shell
end

--- Swaps A-Life's bring-near (which needs real map squares) for one that steps the body beside the player.
local function walkOver()
    ALifeRepEditor.Editor.adapters.companions = setmetatable({
        bringNear = function(shell, player) shell.x, shell.y = player:getX() + 1, player:getY(); return true end,
    }, { __index = ProjectALife.Companions })
end

test("join my crew makes someone nearby an A-Life companion, and leave sends them off", function()
    local world = World.new()
    ProjectALife.Watchdog = { bindings = {} }
    stand(world.player, 10, 10)
    World.addNpc("p1", "ash", "g1", "Pia")
    body("p1", 12, 10)
    local state = Hooks.handle(world.player, "personJoinCrew", { uid = "p1" })
    ok(not state.failed, state.message)
    eq(state.message, "Pia Doe joined your crew.")
    local record = ProjectALife.ActorRegistry.read("p1")
    eq(record.memory.companion.owner, ProjectALife.Companions.playerKey(world.player))
    eq(person(state, "p1").crew, "yours", "listed in your crew without ever meeting")
    ok(state.crewOn); eq(state.crewSize, 1); eq(state.crewMax, 5)
    eq(Hooks.handle(world.player, "personJoinCrew", { uid = "p1" }).message, "Pia Doe is already in your crew.")
    state = Hooks.handle(world.player, "personLeaveCrew", { uid = "p1" })
    ok(not state.failed, state.message)
    eq(state.message, "Pia Doe left your crew.")
    record = ProjectALife.ActorRegistry.read("p1")
    eq(record.memory.companion, nil); ok(record.memory.companionKept ~= nil, "A-Life keeps their state for a rejoin")
    eq(state.crewSize, 0)
    ok(Hooks.handle(world.player, "personLeaveCrew", { uid = "p1" }).failed, "not in your crew any more")
    ProjectALife.Watchdog = nil
end)

test("someone far away walks over to join, and someone not loaded is refused", function()
    local world = World.new()
    ProjectALife.Watchdog = { bindings = {} }
    stand(world.player, 10, 10)
    World.addNpc("p1", "blk", "g1", "Sam")
    World.addNpc("p2", "ash", "g2", "Pia")
    local shell = body("p1", 60, 10)
    local state = Hooks.handle(world.player, "personJoinCrew", { uid = "p1" })
    ok(state.failed, "too far without a way to bring them")
    eq(state.message, "Sam Doe is too far away; get closer to them and try again.")
    walkOver()
    state = Hooks.handle(world.player, "personJoinCrew", { uid = "p1" })
    ok(not state.failed, state.message)
    eq(state.message, "Sam Doe came over and joined your crew.")
    eq(shell.x, 11, "standing beside you")
    eq(person(state, "p1").stance, "friendly", "even a hostile faction's member is friendly once in your crew")
    state = Hooks.handle(world.player, "personJoinCrew", { uid = "p2" })
    eq(state.message, "Pia Doe can't join right now; get closer to them and try again.")
    ProjectALife.Watchdog = nil
end)

test("a full crew, companions switched off and someone else's companion are refused", function()
    local world = World.new()
    ProjectALife.Watchdog = { bindings = {} }
    stand(world.player, 10, 10)
    for index = 1, 6 do
        World.addNpc("c" .. index, "ash", "g" .. index, "Cal" .. index)
        body("c" .. index, 11, 10)
    end
    for index = 1, 5 do ok(not Hooks.handle(world.player, "personJoinCrew", { uid = "c" .. index }).failed) end
    local state = Hooks.handle(world.player, "personJoinCrew", { uid = "c6" })
    ok(state.failed); eq(state.message, "Your crew is full at 5; dismiss someone first.")
    local record = ProjectALife.ActorRegistry.read("c6")
    ProjectALife.ActorRegistry.update("c6", record.revision, function(fresh)
        fresh.memory.companion = { owner = "someone-else" }
    end)
    state = Hooks.handle(world.player, "refresh", { focus = "c6" })
    eq(person(state, "c6").crew, "other")
    eq(Hooks.handle(world.player, "personJoinCrew", { uid = "c6" }).message, "Cal6 Doe is already in someone else's crew.")
    SandboxVars.ALife.Companions_Enabled = false
    state = Hooks.handle(world.player, "personLeaveCrew", { uid = "c1" })
    SandboxVars.ALife.Companions_Enabled = nil
    ok(state.failed); eq(state.message, "Companions are turned off in A-Life's sandbox options.")
    ok(not state.crewOn)
    ProjectALife.Watchdog = nil
end)
