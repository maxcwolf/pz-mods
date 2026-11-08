--- Editor tests against Project A-Life's real reputation code.
local World = ARE_World
local Editor = ALifeRepEditor.Editor

--- Sets up a neutral faction squad of three and returns the world and NPCs.
local function squad()
    local world = World.new()
    local victim = World.addNpc("u1", "ash", "g1", "Joe")
    local mate = World.addNpc("u2", "ash", "g1", "Ann")
    local other = World.addNpc("u3", "ash", "g2", "Bob")
    ProjectALife.Revenge.tallies.g1 = { count = 0 }
    return world, victim, mate, other
end

--- Plays out an accidental kill: two hits, then the death.
local function accident(world, victim)
    World.hit(world, victim)
    World.advance(0.01)
    World.hit(world, victim)
    ProjectALife.Revenge.tallies.g1.count = ProjectALife.Revenge.tallies.g1.count + 1
    World.kill(world, victim)
end

test("an accidental kill really hurts reputation in A-Life (sanity check)", function()
    local world, victim = squad()
    accident(world, victim)
    eq(World.row(world).score, -40, "score")
    eq(ProjectALife.Reputation.statusFor(world.player, "ash"), "hostile", "faction")
    ok((World.opinion(world, "u2").v or 0) < 0, "mate's opinion dropped")
    eq(ProjectALife.RepTrack.humans(world.player), 1, "humans killed")
end)

test("the kill is recorded for undo with its details", function()
    local world, victim = squad()
    accident(world, victim)
    local state = Editor.snapshot(world.player)
    eq(#state.kills, 1)
    eq(state.kills[1].id, "u1:0")
    eq(state.kills[1].text, "Joe Doe (Ashguard) meant you no harm. Reputation -40, just now")
end)

test("undo puts back score, faction, opinions, kill count and revenge", function()
    local world, victim, mate, other = squad()
    local before = World.opinion(world, "u3")
    accident(world, victim)
    local done = Editor.undoKill(world.player, "u1:0")
    ok(done, "undo ok")
    eq(World.row(world).score, 0, "score")
    eq(World.row(world).level, "rep_0", "level")
    eq(ProjectALife.Reputation.recordedStatus(world.player, "ash"), nil, "no recorded hostility")
    eq(ProjectALife.Reputation.statusFor(world.player, "ash"), "neutral", "faction back to neutral")
    eq(World.opinion(world, "u2"), nil, "mate's opinion back to never-met")
    eq(World.opinion(world, "u3"), before, "other squad's opinion back")
    eq(ProjectALife.RepTrack.humans(world.player), 0, "humans killed")
    eq(ProjectALife.Revenge.tallies.g1, nil, "revenge tally gone")
    eq(World.row(world).deed, nil, "the story about you is gone")
end)

test("undo keeps reputation earned after the kill", function()
    local world, victim = squad()
    accident(world, victim)
    Editor.nudge(world.player, 25)
    Editor.undoKill(world.player, "u1:0")
    eq(World.row(world).score, 25)
end)

test("undo twice is refused and a missing kill is reported", function()
    local world, victim = squad()
    accident(world, victim)
    ok(Editor.undoKill(world.player, "u1:0"))
    local again, message = Editor.undoKill(world.player, "u1:0")
    ok(not again); eq(message, "That kill was already undone.")
    local missing = Editor.undoKill(world.player, "nope")
    ok(not missing)
    ok(Editor.snapshot(world.player).kills[1].undone, "listed as undone")
end)

test("undo keeps a faction hostile when it was already hostile before the fight", function()
    local world, victim = squad()
    Editor.makeHostile(world.player, "ash")
    World.advance(30)
    accident(world, victim)
    Editor.undoKill(world.player, "u1:0")
    eq(ProjectALife.Reputation.recordedStatus(world.player, "ash"), "hostile")
end)

test("killing a hostile raider is recorded with its reputation gain", function()
    local world = World.new()
    local raider = World.addNpc("r1", "blk", "g9", "Rex")
    World.kill(world, raider)
    local state = Editor.snapshot(world.player)
    eq(World.row(world).score, 10)
    ok(string.find(state.kills[1].text, "was hostile to you. Reputation +10", 1, true) ~= nil, state.kills[1].text)
end)

test("a kill A-Life already counted is not recorded twice", function()
    local world, victim = squad()
    accident(world, victim)
    World.kill(world, victim)
    eq(#Editor.snapshot(world.player).kills, 1)
end)

test("nudge and setLevel change score and level", function()
    local world = World.new()
    ok(Editor.nudge(world.player, 100))
    eq(World.row(world).score, 100); eq(World.row(world).level, "rep_p1")
    ok(Editor.setLevel(world.player, "rep_n5"))
    eq(World.row(world).score, -900); eq(World.row(world).level, "rep_n5")
    ok(Editor.setLevel(world.player, "rep_0"))
    eq(World.row(world).score, 0)
    ok(Editor.nudge(world.player, 5000))
    eq(World.row(world).score, 1000); eq(World.row(world).level, "rep_p5")
    ok(not Editor.setLevel(world.player, "rep_bogus"))
end)

test("setScore ignores hysteresis so the level always matches the score", function()
    local world = World.new()
    Editor.setScore(world.player, 65)
    eq(World.row(world).level, "rep_p1")
    Editor.setScore(world.player, 50)
    eq(World.row(world).level, "rep_0")
end)

test("personal reputation turned off is reported, not crashed", function()
    local world = World.new()
    ProjectALife.PersonalRep.enabled = false
    local done, message = Editor.nudge(world.player, 5)
    ProjectALife.PersonalRep.enabled = true
    ok(not done); ok(string.find(message, "turned off", 1, true) ~= nil)
end)

test("forgive clears a faction's hostility and grudges", function()
    local world, victim, mate = squad()
    World.hit(world, victim)
    ok(Editor.snapshot(world.player).factions[1].id == "ash", "angry faction listed first")
    local done = Editor.forgive(world.player, "ash")
    ok(done)
    eq(ProjectALife.Reputation.statusFor(world.player, "ash"), "neutral")
    eq(World.opinion(world, "u1"), nil, "victim's grudge gone")
    local row = Editor.snapshot(world.player).factions
    for _, faction in ipairs(row) do
        if faction.id == "ash" then eq(faction.grudges, 0) end
    end
end)

test("forgive keeps good opinions", function()
    local world, victim = squad()
    ProjectALife.NpcOpinion.note("saved", victim, world.player)
    local good = World.opinion(world, "u1").v
    Editor.forgive(world.player, "ash")
    eq(World.opinion(world, "u1").v, good)
end)

test("makeHostile and forgiveAll", function()
    local world = World.new()
    Editor.makeHostile(world.player, "civ")
    eq(ProjectALife.Reputation.statusFor(world.player, "civ"), "hostile")
    local done, message = Editor.forgiveAll(world.player)
    ok(done); ok(string.find(message, "1 changed", 1, true) ~= nil, message)
    eq(ProjectALife.Reputation.statusFor(world.player, "civ"), "friendly")
    ok(not Editor.makeHostile(world.player, "nope"))
end)

test("snapshot lists live factions with attitudes and skips deleted ones", function()
    local world = World.new()
    local state = Editor.snapshot(world.player)
    eq(#state.factions, 3)
    eq(state.personal.score, 0); eq(state.personal.level, "rep_0")
    eq(#state.levels, 11); eq(state.scoreMin, -1000)
    local byId = {}
    for _, faction in ipairs(state.factions) do byId[faction.id] = faction end
    eq(byId.civ.status, "friendly"); eq(byId.blk.status, "hostile"); eq(byId.old, nil)
end)

test("the kill list keeps the newest six", function()
    local world = World.new()
    for i = 1, 8 do
        World.kill(world, World.addNpc("n" .. i, "ash", "s" .. i, "N" .. i))
        World.advance(1)
    end
    local kills = Editor.snapshot(world.player).kills
    eq(#kills, 6); eq(kills[1].id, "n8:0")
end)

test("saved kills hold no live game objects", function()
    local world, victim = squad()
    accident(world, victim)
    local saved = world.modData[Editor.TAG].players[world.key].kills[1]
    eq(saved.killer, nil)
end)

test("undo leaves a grudge from an older, separate fight alone", function()
    local world, victim, mate = squad()
    ProjectALife.NpcOpinion.note("robbery", mate, world.player)
    local grudge = World.opinion(world, "u2").v
    World.advance(48)
    accident(world, victim)
    Editor.undoKill(world.player, "u1:0")
    local row = World.opinion(world, "u2")
    ok(row ~= nil, "older grudge kept")
    ok(row.v <= grudge, "kept at least as bad as before")
end)

test("undo and forgive end the hostile-to-you flag on the NPCs involved", function()
    local world, victim, mate = squad()
    mate.memory.hostileToPlayerKeys = { [world.key] = true }
    accident(world, victim)
    Editor.undoKill(world.player, "u1:0")
    eq(ProjectALife.ActorRegistry.records.u2.memory.hostileToPlayerKeys[world.key], nil, "undo calmed the mate")
    ProjectALife.ActorRegistry.records.u3.memory.hostileToPlayerKeys = { [world.key] = true }
    Editor.forgive(world.player, "ash")
    eq(ProjectALife.ActorRegistry.records.u3.memory.hostileToPlayerKeys[world.key], nil, "forgive calmed the faction")
end)

test("a one-shot kill with no hits first is still undone fully", function()
    local world, victim = squad()
    World.kill(world, victim)
    Editor.undoKill(world.player, "u1:0")
    eq(World.row(world).score, 0)
    eq(ProjectALife.Reputation.statusFor(world.player, "ash"), "neutral")
    eq(World.opinion(world, "u2"), nil)
end)
