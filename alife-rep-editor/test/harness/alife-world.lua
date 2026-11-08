--- Builds a small fake game world around Project A-Life's real reputation,
--- personal reputation, kill tracking, NPC opinion and actor registry code,
--- so the editor is tested against the mod it edits rather than a mock of it.
local World = {}

SandboxVars = SandboxVars or {}
SandboxVars.ALife = SandboxVars.ALife or {}

local clock = { hours = 100 }

--- Fake GameTime so A-Life's clocks follow the test clock.
function getGameTime()
    return { getWorldAgeHours = function() return clock.hours end }
end

--- Fake millisecond clock derived from the test clock.
function getTimestampMs()
    return math.floor(clock.hours * 3600000)
end

--- Returns a fake IsoPlayer with mod data and an access level.
function World.player(username, access)
    local player = { modData = {}, username = username or "max", num = 0, hours = 10, dead = false, access = access }
    function player:getUsername() return self.username end
    function player:getPlayerNum() return self.num end
    function player:getModData() return self.modData end
    function player:hasModData() return true end
    function player:getHoursSurvived() return self.hours end
    function player:isDead() return self.dead end
    function player:getAccessLevel() return self.access end
    return player
end

--- Adds an NPC record straight into A-Life's registry.
function World.addNpc(uid, factionId, groupId, first)
    local Registry = ProjectALife.ActorRegistry
    local record = {
        uid = uid, revision = 1, generation = 0, lifecycle = "active", profileId = "p_" .. factionId,
        factionId = factionId, worldPosition = { x = 10, y = 10, z = 0 },
        memory = { groupId = groupId, squadId = groupId, personFirst = first, personLast = "Doe" },
    }
    Registry.records[uid] = record
    Registry.order[#Registry.order + 1] = uid
    return record
end

--- Resets every A-Life module and the editor, and returns a fresh world.
function World.new()
    clock.hours = 100
    local modData = {}
    local getOrCreate = function(tag)
        modData[tag] = modData[tag] or {}
        return modData[tag]
    end
    local player = World.player("max")
    local players = { player }
    ProjectALife.Catalog.current = {
        factions = {
            ash = { id = "ash", general = { name = "Ashguard" }, relations = { player = "neutral" } },
            civ = { id = "civ", general = { name = "Townsfolk" }, relations = { player = "friendly" } },
            blk = { id = "blk", general = { name = "Blacktop" }, relations = { player = "hostile" } },
            old = { id = "old", general = { name = "Gone", deleted = true }, relations = { player = "neutral" } },
        },
        npcs = {},
    }
    ProjectALife.Catalog.network = nil
    ProjectALife.Reputation.configure({
        getOrCreate = getOrCreate, authoritative = true, multiplayer = false,
        nowHours = function() return clock.hours end, players = function() return players end,
        send = function() return true end,
    })
    ProjectALife.PersonalRep.configure({ enabled = true, adapters = {
        getOrCreate = getOrCreate, authoritative = true,
        nowHours = function() return clock.hours end, nowMs = function() return clock.hours * 3600000 end,
    } })
    ProjectALife.PersonalRep.dirty = false
    ProjectALife.ActorRegistry.reset()
    ProjectALife.ActorRegistry.configure({})
    ProjectALife.Revenge = { tallies = {} }
    ProjectALife.NpcOpinion.reset()
    local Editor = ALifeRepEditor.Editor
    Editor.storage = nil
    Editor.pending = {}
    Editor.adapters = { getOrCreate = getOrCreate, nowHours = function() return clock.hours end }
    return { player = player, key = ProjectALife.Reputation.playerKey(player), modData = modData, clock = clock }
end

--- Moves the test clock forward.
function World.advance(hours)
    clock.hours = clock.hours + hours
end

--- Plays out a player hitting an NPC the way A-Life's combat code reports it.
function World.hit(world, victim)
    ProjectALife.Reputation.onPlayerDamagedActor(world.player, victim)
    ProjectALife.NpcOpinion.note("hit", victim, world.player)
end

--- Plays out a player killing an NPC in the same order as A-Life's Lifecycle fan-out.
function World.kill(world, victim)
    victim.lifecycle = "dead"
    local key = world.key
    ProjectALife.RepTrack.onActorKilled(world.player, victim, key)
    ProjectALife.Reputation.onPlayerKilledActor(world.player, victim)
    ProjectALife.PersonalRep.onActorKilled(victim, nil, key, world.player)
    ProjectALife.NpcOpinion.noteKill(victim, key, world.player)
end

--- Returns the player's personal reputation row.
function World.row(world)
    return ProjectALife.PersonalRep.rowFor(world.key, world.player, true)
end

--- Returns an NPC's opinion row about the player, or nil.
function World.opinion(world, uid)
    local record = ProjectALife.ActorRegistry.records[uid]
    local map = record and record.memory and record.memory.opinion or nil
    return map and map[world.key] or nil
end

return World
