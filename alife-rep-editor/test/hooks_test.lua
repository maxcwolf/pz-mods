--- Tests for the A-Life wrappers and the command handler.
local World = ARE_World
local Hooks = ALifeRepEditor.Hooks

test("all four A-Life hooks are installed and installing again changes nothing", function()
    eq(Hooks.installed, 4)
    local wrapped = ProjectALife.PersonalRep.onActorKilled
    Hooks.install()
    eq(Hooks.installed, 4)
    ok(ProjectALife.PersonalRep.onActorKilled == wrapped)
end)

test("wrappers pass A-Life's return values through", function()
    local world = World.new()
    local victim = World.addNpc("w1", "ash", "gw", "Wes")
    victim.lifecycle = "dead"
    ProjectALife.RepTrack.onActorKilled(world.player, victim, world.key)
    local done, class, applied = ProjectALife.PersonalRep.onActorKilled(victim, nil, world.key, world.player)
    ok(done); eq(class, "neutral"); eq(applied, -40)
end)

test("a broken editor step does not break A-Life's kill handling", function()
    local world = World.new()
    local victim = World.addNpc("b1", "ash", "gb", "Bea")
    local saved = ALifeRepEditor.Editor.beginKill
    ALifeRepEditor.Editor.beginKill = function() error("boom") end
    World.kill(world, victim)
    ALifeRepEditor.Editor.beginKill = saved
    eq(World.row(world).score, -40)
end)

test("handle runs a command and returns the fresh state with a message", function()
    local world = World.new()
    local state = Hooks.handle(world.player, "nudge", { delta = 5 })
    ok(state.ok); ok(not state.failed); eq(state.personal.score, 5)
    ok(string.find(state.message, "0 -> 5", 1, true) ~= nil, state.message)
end)

test("handle still answers when building the window state fails", function()
    local world = World.new()
    local snapshot = ALifeRepEditor.Editor.snapshot
    ALifeRepEditor.Editor.snapshot = function() error("boom") end
    local ran, state = pcall(Hooks.handle, world.player, "nudge", { delta = 5 })
    ALifeRepEditor.Editor.snapshot = snapshot
    ok(ran, "handle did not throw: " .. tostring(state))
    ok(state.failed, "marked failed")
    ok(string.find(state.message, "console.txt", 1, true) ~= nil, state.message)
    eq(World.row(world).score, 5, "the nudge itself still applied")
end)

test("handle reports unknown commands and failures", function()
    local world = World.new()
    ok(not Hooks.handle(world.player, "explode", {}).ok)
    local state = Hooks.handle(world.player, "undoKill", { id = "none" })
    ok(state.failed); eq(state.message, "That kill is no longer on the list.")
end)

test("multiplayer refuses non-staff unless the sandbox option allows everyone", function()
    local world = World.new()
    local savedServer = isServer
    isServer = function() return true end
    world.player.access = "None"
    ok(Hooks.handle(world.player, "refresh", {}).denied, "player refused")
    world.player.access = "admin"
    ok(not Hooks.handle(world.player, "refresh", {}).denied, "admin allowed")
    world.player.access = "None"
    SandboxVars.ALifeRepEditor = { AllowEveryone = true }
    ok(not Hooks.handle(world.player, "refresh", {}).denied, "everyone allowed")
    SandboxVars.ALifeRepEditor = nil
    isServer = savedServer
end)
