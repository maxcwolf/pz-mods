--- Connects the editor to Project A-Life: wraps the four A-Life functions a
--- player's NPC kill passes through (so the kill can be undone later) and
--- answers the window's commands, checking who is allowed in multiplayer.
require "ProjectALife/Decisions/ALifeReputation"
require "ProjectALife/Decisions/ALifeReputationPersonal"
require "ProjectALife/Decisions/ALifeRepTrack"
require "ProjectALife/Decisions/ALifeNpcOpinion"
require "ALifeRepEditor/editor"
require "ALifeRepEditor/permissions"

ALifeRepEditor = ALifeRepEditor or {}

local Editor = ALifeRepEditor.Editor
local Permissions = ALifeRepEditor.Permissions

local Hooks = { MODULE = "ALifeRepEditor", originals = {}, installed = 0 }
ALifeRepEditor.Hooks = Hooks

--- Prints a tagged line to the console.
local function log(text)
    print("[ALifeRepEditor] " .. tostring(text))
end

--- Runs an editor step without letting a bug in it break A-Life's own kill handling.
local function safely(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then log("error: " .. tostring(err)) end
end

--- Replaces target[name] with a wrapper once, keeping the original for the wrapper to call.
function Hooks.wrap(target, name, makeWrapper)
    if type(target) ~= "table" or type(target[name]) ~= "function" then
        log("cannot find A-Life function " .. tostring(name) .. "; undo for kills will be partial.")
        return false
    end
    Hooks.originals[target] = Hooks.originals[target] or {}
    if Hooks.originals[target][name] ~= nil then return false end
    local original = target[name]
    Hooks.originals[target][name] = original
    target[name] = makeWrapper(original)
    Hooks.installed = Hooks.installed + 1
    return true
end

--- Installs every wrapper; safe to call more than once.
function Hooks.install()
    local P = ProjectALife or {}
    Hooks.wrap(P.RepTrack, "onActorKilled", function(original)
        return function(killer, actor, key)
            safely(Editor.beginKill, killer, actor, key)
            return original(killer, actor, key)
        end
    end)
    Hooks.wrap(P.PersonalRep, "onActorKilled", function(original)
        return function(actor, shell, killerKey, killer)
            local ok, class, applied = original(actor, shell, killerKey, killer)
            safely(function()
                Editor.noteKillResult(killerKey or Editor.keyOf(killer), actor, ok, class, applied)
            end)
            return ok, class, applied
        end
    end)
    Hooks.wrap(P.NpcOpinion, "noteKill", function(original)
        return function(victim, killerKey, killer)
            local result = original(victim, killerKey, killer)
            safely(function() Editor.finishKill(killerKey or Editor.keyOf(killer), victim) end)
            return result
        end
    end)
    Hooks.wrap(P.Reputation, "escalate", function(original)
        return function(player, actorOrFaction, deed)
            local peek
            safely(function() peek = Editor.peekEscalation(player, actorOrFaction) end)
            local changed, reason = original(player, actorOrFaction, deed)
            if changed == true then safely(Editor.noteEscalation, peek) end
            return changed, reason
        end
    end)
    return Hooks.installed
end

--- Returns the context the permission check needs for this player.
function Hooks.permissionContext(player)
    local multiplayer = type(isServer) == "function" and isServer() == true
    local accessLevel
    if multiplayer and player ~= nil and player.getAccessLevel ~= nil then accessLevel = player:getAccessLevel() end
    local options = SandboxVars ~= nil and SandboxVars.ALifeRepEditor or nil
    return { multiplayer = multiplayer, accessLevel = accessLevel,
        allowEveryone = type(options) == "table" and options.AllowEveryone == true }
end

Hooks.COMMANDS = {
    refresh = function() return true, nil end,
    nudge = function(player, args) return Editor.nudge(player, args.delta) end,
    setScore = function(player, args) return Editor.setScore(player, args.score) end,
    setLevel = function(player, args) return Editor.setLevel(player, args.level) end,
    undoKill = function(player, args) return Editor.undoKill(player, args.id) end,
    forgive = function(player, args) return Editor.forgive(player, args.faction) end,
    forgiveAll = function(player) return Editor.forgiveAll(player) end,
    makeHostile = function(player, args) return Editor.makeHostile(player, args.faction) end,
}

--- Runs one window command and returns the fresh state for the window, with a message.
function Hooks.handle(player, command, args)
    if not Permissions.allowed(Hooks.permissionContext(player)) then
        return { ok = false, denied = true, message = "Only server staff can edit reputation here." }
    end
    local run = Hooks.COMMANDS[command]
    if run == nil then return { ok = false, message = "Unknown command " .. tostring(command) .. "." } end
    local ok, done, message = pcall(run, player, type(args) == "table" and args or {})
    if not ok then
        log("command " .. tostring(command) .. " failed: " .. tostring(done))
        done, message = false, "Something went wrong; see console.txt."
    end
    local state = Editor.snapshot(player)
    state.message = message
    state.failed = done ~= true
    return state
end

--- Answers commands sent from a multiplayer client.
function Hooks.onClientCommand(module, command, player, args)
    if module ~= Hooks.MODULE then return end
    local state = Hooks.handle(player, command, args)
    if type(sendServerCommand) == "function" then sendServerCommand(player, Hooks.MODULE, "state", state) end
end

Hooks.install()
log("loaded; " .. tostring(Hooks.installed) .. " of 4 A-Life hooks installed.")

if type(Events) == "table" then
    if Events.OnClientCommand ~= nil then Events.OnClientCommand.Add(Hooks.onClientCommand) end
    if Events.OnGameStart ~= nil then Events.OnGameStart.Add(Hooks.install) end
    if Events.OnServerStarted ~= nil then Events.OnServerStarted.Add(Hooks.install) end
end

return Hooks
