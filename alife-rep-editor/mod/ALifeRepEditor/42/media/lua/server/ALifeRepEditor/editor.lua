--- Server-side reputation editing on top of Project A-Life: reads and changes
--- the personal score, faction attitudes and NPC opinions A-Life keeps, and
--- records each NPC kill so it can be undone later. Every A-Life module is
--- looked up at call time through Editor.alife(), so tests can swap in fakes.
require "ALifeRepEditor/score"
require "ALifeRepEditor/kill-ledger"
require "ALifeRepEditor/faction-restore"
require "ALifeRepEditor/faction-rows"

ALifeRepEditor = ALifeRepEditor or {}

local Score = ALifeRepEditor.Score
local Ledger = ALifeRepEditor.KillLedger
local Restore = ALifeRepEditor.FactionRestore
local Rows = ALifeRepEditor.FactionRows

local Editor = {
    TAG = "ALifeRepEditor.v1",
    SCHEMA = 1,
    opinionCap = 80,
    pending = {},
    adapters = {},
    storage = nil,
}
ALifeRepEditor.Editor = Editor

--- Returns the Project A-Life modules the editor works with.
function Editor.alife()
    local P = Editor.adapters.alife or ProjectALife or {}
    return {
        rep = P.Reputation, personal = P.PersonalRep, levels = P.RepLevels, track = P.RepTrack,
        registry = P.ActorRegistry, opinion = P.NpcOpinion, revenge = P.Revenge, catalog = P.Catalog,
    }
end

--- Returns the current game time in world hours.
function Editor.now()
    if type(Editor.adapters.nowHours) == "function" then return Editor.adapters.nowHours() end
    local personal = Editor.alife().personal
    if personal ~= nil and type(personal.nowHours) == "function" then return tonumber((personal.nowHours())) or 0 end
    return 0
end

--- Returns a copy of a table nested up to a few levels, or the value itself.
function Editor.copy(value, depth)
    if type(value) ~= "table" then return value end
    local level = depth or 3
    local result = {}
    for field, item in pairs(value) do
        if type(item) == "table" and level > 1 then
            result[field] = Editor.copy(item, level - 1)
        elseif type(item) ~= "table" then
            result[field] = item
        end
    end
    return result
end

--- Returns true when two flat tables hold the same values.
function Editor.same(left, right)
    if type(left) ~= "table" or type(right) ~= "table" then return left == right end
    for field, value in pairs(left) do
        if type(value) ~= "table" and right[field] ~= value then return false end
    end
    for field, value in pairs(right) do
        if type(value) ~= "table" and left[field] ~= value then return false end
    end
    return true
end

--- Returns the editor's saved world data, creating it on first use.
function Editor.store()
    if Editor.storage ~= nil then return Editor.storage end
    local data
    if type(Editor.adapters.getOrCreate) == "function" then
        data = Editor.adapters.getOrCreate(Editor.TAG)
    elseif ModData ~= nil and type(ModData.getOrCreate) == "function" then
        data = ModData.getOrCreate(Editor.TAG)
    end
    if type(data) ~= "table" then return nil end
    if type(data.players) ~= "table" then data.players = {} end
    data.schema = Editor.SCHEMA
    Editor.storage = data
    return data
end

--- Returns one player's kills and escalation origins, creating them on first use.
function Editor.playerData(key)
    local store = Editor.store()
    if store == nil or type(key) ~= "string" then return nil end
    local data = store.players[key]
    if type(data) ~= "table" then
        data = {}
        store.players[key] = data
    end
    if type(data.kills) ~= "table" then data.kills = {} end
    if type(data.origins) ~= "table" then data.origins = {} end
    return data
end

--- Returns A-Life's reputation key for a player object or key string.
function Editor.keyOf(player)
    local rep = Editor.alife().rep
    if player == nil or rep == nil or type(rep.playerKey) ~= "function" then return nil end
    return rep.playerKey(player)
end

--- Returns A-Life's table of faction attitudes per player, loading it if needed.
function Editor.repPlayers()
    local rep = Editor.alife().rep
    if rep == nil then return nil end
    if rep.storage == nil and type(rep.recordedStatus) == "function" then
        rep.recordedStatus("__ALifeRepEditor", "__probe")
    end
    local state = rep.storage
    if type(state) ~= "table" or type(state.players) ~= "table" then return nil end
    return state.players
end

--- Returns a player's recorded attitude entry for a faction, or nil for its usual attitude.
function Editor.factionEntry(key, factionId)
    local players = Editor.repPlayers()
    local playerState = players ~= nil and players[key] or nil
    local entry = type(playerState) == "table" and playerState[factionId] or nil
    return type(entry) == "table" and entry or nil
end

--- Replaces a player's recorded attitude for a faction; nil puts back its usual attitude.
function Editor.setFactionEntry(key, factionId, entry)
    local rep = Editor.alife().rep
    local players = Editor.repPlayers()
    if players == nil or type(key) ~= "string" or type(factionId) ~= "string" then return false end
    local playerState = players[key]
    if type(playerState) ~= "table" then
        if entry == nil then return true end
        playerState = {}
        players[key] = playerState
    end
    playerState[factionId] = Restore.copy(entry)
    local populated = false
    for _ in pairs(playerState) do populated = true break end
    if not populated then players[key] = nil end
    rep.dirty = true
    return true
end

--- Returns the faction id of an A-Life actor record, NPC shell or faction id.
function Editor.factionIdOf(ref)
    if type(ref) == "string" then return ref end
    if type(ref) == "table" and type(ref.factionId) == "string" then return ref.factionId end
    if ref == nil or ref.getModData == nil then return nil end
    local data = ref:getModData()
    if type(data) ~= "table" then return nil end
    if type(data.ProjectALifeFactionId) == "string" then return data.ProjectALifeFactionId end
    local registry = Editor.alife().registry
    local actor = type(data.ProjectALifeUID) == "string" and registry ~= nil and registry.read(data.ProjectALifeUID) or nil
    return actor ~= nil and actor.factionId or nil
end

--- Returns every faction in A-Life's catalog that has not been deleted, by id.
function Editor.factionMap()
    local catalog = Editor.alife().catalog
    local result = {}
    if catalog == nil then return result end
    local sources = { catalog.current and catalog.current.factions, catalog.network and catalog.network.factions }
    for index = 1, 2 do
        local source = sources[index]
        if type(source) == "table" then
            for id, faction in pairs(source) do
                local general = type(faction) == "table" and faction.general or nil
                if type(general) ~= "table" or general.deleted ~= true then result[id] = faction end
            end
        end
    end
    return result
end

--- Returns a faction's display name.
function Editor.factionName(factionId)
    local faction = Editor.factionMap()[factionId]
    local general = type(faction) == "table" and faction.general or nil
    if type(general) == "table" and type(general.name) == "string" and general.name ~= "" then return general.name end
    return tostring(factionId or "")
end

--- Returns an NPC's display name from its A-Life record.
function Editor.nameOf(actor)
    local memory = type(actor.memory) == "table" and actor.memory or {}
    if type(memory.personFirst) == "string" and memory.personFirst ~= "" then
        local last = type(memory.personLast) == "string" and memory.personLast or ""
        return last ~= "" and (memory.personFirst .. " " .. last) or memory.personFirst
    end
    if type(memory.name) == "string" and memory.name ~= "" then return memory.name end
    return "An NPC"
end

--- Copies the opinion rows a kill can change: the victim's group mates and faction.
function Editor.opinionSnapshot(key, victim)
    local registry = Editor.alife().registry
    local result, count = {}, 0
    if registry == nil or type(registry.each) ~= "function" then return result end
    local memory = type(victim.memory) == "table" and victim.memory or {}
    registry.each(function(record)
        if record.uid ~= victim.uid and record.lifecycle ~= "dead" and type(record.memory) == "table" then
            local sameGroup = memory.groupId ~= nil and record.memory.groupId == memory.groupId
            local sameFaction = victim.factionId ~= nil and record.factionId == victim.factionId
            if sameGroup or sameFaction then
                local map = record.memory.opinion
                local row = type(map) == "table" and map[key] or nil
                result[tostring(record.uid)] = type(row) == "table" and Editor.copy(row) or false
                count = count + 1
            end
        end
        return count >= Editor.opinionCap
    end)
    return result
end

--- Writes one NPC's opinion of a player through A-Life's registry; nil clears it.
function Editor.writeOpinion(uid, key, row)
    local registry = Editor.alife().registry
    if registry == nil or type(registry.read) ~= "function" or type(registry.update) ~= "function" then return false end
    local current = registry.read(uid)
    if current == nil then return false end
    local updated = registry.update(current.uid, current.revision, function(record)
        record.memory = type(record.memory) == "table" and record.memory or {}
        local map = type(record.memory.opinion) == "table" and record.memory.opinion or {}
        map[key] = type(row) == "table" and Editor.copy(row) or nil
        record.memory.opinion = map
    end)
    return updated ~= nil and updated ~= false
end

--- Combines two opinion snapshots; rows from the earlier one win.
function Editor.mergeSnapshots(later, earlier)
    local result = {}
    for uid, row in pairs(type(later) == "table" and later or {}) do result[uid] = row end
    for uid, row in pairs(type(earlier) == "table" and earlier or {}) do result[uid] = row end
    return result
end

--- Returns the uids of a faction's living NPCs (every faction when nil) as a set.
function Editor.members(factionId)
    local registry = Editor.alife().registry
    local result = {}
    if registry == nil or type(registry.each) ~= "function" then return result end
    registry.each(function(record)
        if record.lifecycle ~= "dead" and (factionId == nil or record.factionId == factionId) then
            result[tostring(record.uid)] = true
        end
        return false
    end)
    return result
end

--- Ends the "hostile to this player" flag A-Life sets on NPCs, for the NPCs in a snapshot.
function Editor.calmDown(key, snapshot)
    local registry = Editor.alife().registry
    if registry == nil or type(snapshot) ~= "table" then return 0 end
    local calmed = 0
    for uid in pairs(snapshot) do
        local record = registry.read(uid)
        local flags = record ~= nil and type(record.memory) == "table" and record.memory.hostileToPlayerKeys or nil
        if type(flags) == "table" and flags[key] ~= nil then
            local updated = registry.update(record.uid, record.revision, function(fresh)
                if type(fresh.memory) == "table" and type(fresh.memory.hostileToPlayerKeys) == "table" then
                    fresh.memory.hostileToPlayerKeys[key] = nil
                end
            end)
            if updated ~= nil then calmed = calmed + 1 end
        end
    end
    return calmed
end

--- Puts NPC opinions back to a snapshot, skipping ones that already match.
function Editor.restoreOpinions(key, snapshot)
    local registry = Editor.alife().registry
    if registry == nil or type(snapshot) ~= "table" then return 0 end
    local restored = 0
    for uid, before in pairs(snapshot) do
        local current = registry.read(uid)
        local map = current ~= nil and type(current.memory) == "table" and current.memory.opinion or nil
        local now = type(map) == "table" and map[key] or nil
        local wanted = type(before) == "table" and before or nil
        if current ~= nil and not (now == nil and wanted == nil) and not Editor.same(now, wanted) then
            if Editor.writeOpinion(uid, key, wanted) then restored = restored + 1 end
        end
    end
    return restored
end

--- Returns the opinion an NPC would have of the player with no memories at all.
function Editor.opinionBaseline(record, player)
    local opinion = Editor.alife().opinion
    if opinion ~= nil and type(opinion.baseline) == "function" and player ~= nil then
        return tonumber((opinion.baseline(record, player))) or 0
    end
    return 0
end

--- Counts NPCs per faction whose opinion of the player is below their baseline.
function Editor.grudgeCounts(key, player)
    local registry = Editor.alife().registry
    local counts = {}
    if registry == nil or type(registry.each) ~= "function" then return counts end
    registry.each(function(record)
        local map = type(record.memory) == "table" and record.memory.opinion or nil
        local row = type(map) == "table" and map[key] or nil
        if type(row) == "table" and record.lifecycle ~= "dead" and record.factionId ~= nil
                and (tonumber(row.v) or 0) < Editor.opinionBaseline(record, player) then
            counts[record.factionId] = (counts[record.factionId] or 0) + 1
        end
        return false
    end)
    return counts
end

--- Clears the bad memories a faction's NPCs hold about the player and returns how many.
function Editor.clearGrudges(key, player, factionId)
    local registry = Editor.alife().registry
    if registry == nil or type(registry.each) ~= "function" then return 0 end
    local uids = {}
    registry.each(function(record)
        local map = type(record.memory) == "table" and record.memory.opinion or nil
        local row = type(map) == "table" and map[key] or nil
        if type(row) == "table" and (factionId == nil or record.factionId == factionId)
                and (tonumber(row.v) or 0) < Editor.opinionBaseline(record, player) then
            uids[#uids + 1] = record.uid
        end
        return false
    end)
    local cleared = 0
    for _, uid in ipairs(uids) do
        if Editor.writeOpinion(uid, key, nil) then cleared = cleared + 1 end
    end
    return cleared
end

--- Pushes the new reputation to the player's screen through A-Life.
function Editor.sync(player)
    local m = Editor.alife()
    if m.personal ~= nil then m.personal.dirty = true end
    if m.rep ~= nil and type(m.rep.sync) == "function" and player ~= nil and type(player) ~= "string" then
        pcall(m.rep.sync, player)
    end
end

--- Remembers the state just before A-Life applies a player's kill of an NPC.
function Editor.beginKill(killer, actor, key)
    if type(actor) ~= "table" or actor.uid == nil then return false end
    key = key or Editor.keyOf(killer)
    if type(key) ~= "string" then return false end
    local m = Editor.alife()
    local row = m.personal ~= nil and m.personal.enabled ~= false and type(m.personal.rowFor) == "function"
        and m.personal.rowFor(key, killer, true) or nil
    local memory = type(actor.memory) == "table" and actor.memory or {}
    local factionId = actor.factionId
    Editor.pending[key] = {
        id = tostring(actor.uid) .. ":" .. tostring(actor.generation),
        uid = actor.uid,
        name = Editor.nameOf(actor),
        factionId = factionId,
        factionName = factionId ~= nil and Editor.factionName(factionId) or nil,
        squadId = memory.squadId,
        atHours = Editor.now(),
        scoreBefore = row ~= nil and row.score or nil,
        deedBefore = row ~= nil and Editor.copy(row.deed) or nil,
        humansBefore = m.track ~= nil and type(m.track.humans) == "function" and killer ~= nil and m.track.humans(killer) or nil,
        factionBefore = factionId ~= nil and Restore.copy(Editor.factionEntry(key, factionId)) or nil,
        opinions = Editor.opinionSnapshot(key, actor),
        killer = killer,
    }
    return true
end

--- Stores what A-Life's personal reputation did with the kill.
function Editor.noteKillResult(key, actor, ok, class, applied)
    local pending = type(key) == "string" and Editor.pending[key] or nil
    if pending == nil or type(actor) ~= "table" or pending.uid ~= actor.uid then return false end
    if ok == true then
        pending.class = class
        pending.applied = tonumber(applied) or 0
    end
    return true
end

--- Finishes a kill once A-Life is done with it and adds it to the undo list when it changed anything.
function Editor.finishKill(key, actor)
    local pending = type(key) == "string" and Editor.pending[key] or nil
    if pending == nil then return false end
    if type(actor) == "table" and actor.uid ~= nil and pending.uid ~= actor.uid then return false end
    Editor.pending[key] = nil
    local m = Editor.alife()
    local killer = pending.killer
    pending.killer = nil
    local row = m.personal ~= nil and m.personal.enabled ~= false and type(m.personal.rowFor) == "function"
        and m.personal.rowFor(key, killer, false) or nil
    pending.deedAfter = row ~= nil and Editor.copy(row.deed) or nil
    pending.killDay = row ~= nil and type(row.kills) == "table" and row.kills.day or nil
    if pending.factionId ~= nil then
        pending.factionAfter = Restore.copy(Editor.factionEntry(key, pending.factionId))
    end
    local humansAfter = m.track ~= nil and type(m.track.humans) == "function" and killer ~= nil and m.track.humans(killer) or nil
    pending.humanCounted = humansAfter ~= nil and pending.humansBefore ~= nil and humansAfter > pending.humansBefore
    local factionChanged = not Editor.same(pending.factionBefore, pending.factionAfter)
    if pending.class == nil and not factionChanged and not pending.humanCounted then return false end
    pending.applied = tonumber(pending.applied) or 0
    local data = Editor.playerData(key)
    if data == nil then return false end
    Ledger.push(data.kills, pending, Ledger.max)
    return true
end

--- Finishes any kill A-Life never finished (for example with NPC opinions turned off).
function Editor.flushPending()
    local keys = {}
    for key in pairs(Editor.pending) do keys[#keys + 1] = key end
    for _, key in ipairs(keys) do Editor.finishKill(key, nil) end
end

--- Returns the A-Life actor record behind a record, NPC shell or uid, or nil.
function Editor.recordOf(ref)
    local registry = Editor.alife().registry
    if registry == nil or type(registry.read) ~= "function" or ref == nil then return nil end
    if type(ref) == "string" then return registry.read(ref) end
    if type(ref) == "table" and ref.uid ~= nil then return registry.read(ref.uid) or ref end
    if ref.getModData == nil then return nil end
    local data = ref:getModData()
    if type(data) ~= "table" or type(data.ProjectALifeUID) ~= "string" then return nil end
    return registry.read(data.ProjectALifeUID)
end

--- Reads a faction attitude and the NPC being hit just before A-Life may make the faction hostile.
function Editor.peekEscalation(player, actorOrFaction)
    local key, factionId = Editor.keyOf(player), Editor.factionIdOf(actorOrFaction)
    if type(key) ~= "string" or type(factionId) ~= "string" then return nil end
    return { key = key, factionId = factionId, before = Restore.copy(Editor.factionEntry(key, factionId)),
        record = Editor.recordOf(actorOrFaction) }
end

--- Records where a fight began (attitude and nearby opinions) so undoing the kill can go back past the first hit.
function Editor.noteEscalation(peek)
    if type(peek) ~= "table" then return false end
    local data = Editor.playerData(peek.key)
    if data == nil then return false end
    local origin = Restore.noteOrigin(data.origins, peek.factionId, peek.before, Editor.now(), Restore.windowHours)
    if origin.opinions == nil and type(peek.record) == "table" then
        origin.opinions = Editor.opinionSnapshot(peek.key, peek.record)
    end
    return true
end

--- Returns the player's personal reputation row, or nil when A-Life's personal reputation is off.
function Editor.personalRow(key, player)
    local personal = Editor.alife().personal
    if personal == nil or personal.enabled == false or type(personal.rowFor) ~= "function" then return nil end
    return personal.rowFor(key, player, true)
end

--- Sets the personal score to an exact value and the level that matches it.
function Editor.setScore(player, score)
    local m = Editor.alife()
    local key = Editor.keyOf(player)
    local row = key ~= nil and Editor.personalRow(key, player) or nil
    if row == nil or m.levels == nil then return false, "Personal reputation is turned off in this world." end
    local before = row.score
    row.score = Score.clamp(score, m.levels.scoreMin or -1000, m.levels.scoreMax or 1000)
    row.level = m.levels.at(row.score, nil, 0).id
    row.driftAt = Editor.now()
    Editor.sync(player)
    return true, "Reputation " .. tostring(before) .. " -> " .. tostring(row.score) .. "."
end

--- Moves the personal score up or down by a delta.
function Editor.nudge(player, delta)
    local key = Editor.keyOf(player)
    local row = key ~= nil and Editor.personalRow(key, player) or nil
    if row == nil then return false, "Personal reputation is turned off in this world." end
    return Editor.setScore(player, (tonumber(row.score) or 0) + (tonumber(delta) or 0))
end

--- Jumps the personal score to the middle of a named level.
function Editor.setLevel(player, levelId)
    local levels = Editor.alife().levels
    local index = levels ~= nil and levels.indexOf(levelId) or nil
    if index == nil then return false, "Unknown level." end
    return Editor.setScore(player, Score.levelTarget(levels.rows, index, levels.scoreMax or 1000))
end

--- Takes back everything a recorded kill did to the player's reputation.
function Editor.undoKill(player, id)
    local m = Editor.alife()
    local key = Editor.keyOf(player)
    local data = key ~= nil and Editor.playerData(key) or nil
    local entry = data ~= nil and Ledger.find(data.kills, id) or nil
    if entry == nil then return false, "That kill is no longer on the list." end
    if entry.undone == true then return false, "That kill was already undone." end
    local row = Editor.personalRow(key, player)
    if row ~= nil and m.levels ~= nil then
        if (tonumber(entry.applied) or 0) ~= 0 then
            row.score = Score.clamp((tonumber(row.score) or 0) - entry.applied, m.levels.scoreMin or -1000, m.levels.scoreMax or 1000)
            row.level = m.levels.at(row.score, nil, 0).id
            row.driftAt = Editor.now()
        end
        if entry.deedAfter ~= nil and Editor.same(row.deed, entry.deedAfter) then row.deed = Editor.copy(entry.deedBefore) end
        if type(row.kills) == "table" and entry.killDay ~= nil and row.kills.day == entry.killDay then
            row.kills.n = math.max(0, (tonumber(row.kills.n) or 0) - 1)
            if (entry.class == "hostile" or entry.class == "crime") and row.kills.hostile ~= nil then
                row.kills.hostile = math.max(0, (tonumber(row.kills.hostile) or 0) - 1)
            end
        end
    end
    if entry.humanCounted == true and m.track ~= nil and type(m.track.data) == "function" then
        local modData = m.track.data(player, false)
        if type(modData) == "table" then
            modData.palHumansKilled = math.max(0, (tonumber(modData.palHumansKilled) or 0) - 1)
            local ring = type(modData.palHumanRing) == "table" and modData.palHumanRing or {}
            for index = #ring, 1, -1 do
                if ring[index] == entry.id then table.remove(ring, index) end
            end
        end
    end
    local opinions = entry.opinions
    if entry.factionId ~= nil then
        local origin = data.origins[entry.factionId]
        local target = Restore.pick(origin, entry.factionBefore, entry.atHours, Restore.windowHours)
        if Restore.isRecent(origin, entry.atHours, Restore.windowHours) then
            opinions = Editor.mergeSnapshots(entry.opinions, origin.opinions)
        end
        Editor.setFactionEntry(key, entry.factionId, target)
        data.origins[entry.factionId] = nil
    end
    Editor.restoreOpinions(key, opinions)
    Editor.calmDown(key, opinions)
    local tallies = m.revenge ~= nil and m.revenge.tallies or nil
    local tally = type(tallies) == "table" and entry.squadId ~= nil and tallies[entry.squadId] or nil
    if type(tally) == "table" then
        tally.count = (tonumber(tally.count) or 1) - 1
        if tally.count <= 0 then tallies[entry.squadId] = nil end
    end
    entry.undone = true
    entry.opinions = nil
    Editor.sync(player)
    return true, "Undid the kill of " .. tostring(entry.name) .. "."
end

--- Puts a faction back to its usual attitude and clears its NPCs' grudges.
function Editor.forgive(player, factionId)
    local key = Editor.keyOf(player)
    if key == nil or Editor.factionMap()[factionId] == nil then return false, "Unknown faction." end
    Editor.setFactionEntry(key, factionId, nil)
    local data = Editor.playerData(key)
    if data ~= nil then data.origins[factionId] = nil end
    local cleared = Editor.clearGrudges(key, player, factionId)
    Editor.calmDown(key, Editor.members(factionId))
    Editor.sync(player)
    local note = cleared > 0 and (" " .. tostring(cleared) .. " grudges cleared.") or ""
    return true, Editor.factionName(factionId) .. " forgive you." .. note
end

--- Forgives every faction at once.
function Editor.forgiveAll(player)
    local key = Editor.keyOf(player)
    if key == nil then return false, "No player." end
    local count = 0
    for factionId in pairs(Editor.factionMap()) do
        if Editor.factionEntry(key, factionId) ~= nil then count = count + 1 end
        Editor.setFactionEntry(key, factionId, nil)
    end
    local data = Editor.playerData(key)
    if data ~= nil then data.origins = {} end
    local cleared = Editor.clearGrudges(key, player, nil)
    Editor.calmDown(key, Editor.members(nil))
    Editor.sync(player)
    return true, "Every faction is back to its usual attitude (" .. tostring(count) .. " changed, "
        .. tostring(cleared) .. " grudges cleared)."
end

--- Makes a faction hostile to the player.
function Editor.makeHostile(player, factionId)
    local key = Editor.keyOf(player)
    if key == nil or Editor.factionMap()[factionId] == nil then return false, "Unknown faction." end
    Editor.setFactionEntry(key, factionId, { status = "hostile", cause = "admin", atHours = Editor.now() })
    Editor.sync(player)
    return true, Editor.factionName(factionId) .. " are now hostile to you."
end

--- Builds everything the window shows for one player.
function Editor.snapshot(player)
    Editor.flushPending()
    local m = Editor.alife()
    local key = Editor.keyOf(player)
    if key == nil then return { ok = false, message = "No player." } end
    local now = Editor.now()
    local result = { ok = true, now = now, levels = {}, kills = {}, factions = {},
        scoreMin = -1000, scoreMax = 1000 }
    if m.levels ~= nil and type(m.levels.rows) == "table" then
        for index, row in ipairs(m.levels.rows) do
            result.levels[index] = { id = row.id, name = row.en or row.id, min = row.min }
        end
        result.scoreMin, result.scoreMax = m.levels.scoreMin or -1000, m.levels.scoreMax or 1000
    end
    local row = Editor.personalRow(key, player)
    if row ~= nil then result.personal = { score = row.score, level = row.level } end
    local data = Editor.playerData(key)
    for _, entry in ipairs(data ~= nil and data.kills or {}) do
        result.kills[#result.kills + 1] = { id = entry.id, text = Ledger.describe(entry, now),
            undone = entry.undone == true }
    end
    local grudges = Editor.grudgeCounts(key, player)
    if m.rep ~= nil then
        for factionId in pairs(Editor.factionMap()) do
            local entry = Editor.factionEntry(key, factionId)
            result.factions[#result.factions + 1] = {
                id = factionId, name = Editor.factionName(factionId),
                status = m.rep.statusFor(player, factionId),
                baseline = m.rep.defaultStatus(factionId, player),
                recorded = m.rep.recordedStatus(player, factionId),
                cause = entry ~= nil and entry.cause or nil,
                grudges = grudges[factionId] or 0,
            }
        end
    end
    Rows.sort(result.factions)
    return result
end

return Editor
