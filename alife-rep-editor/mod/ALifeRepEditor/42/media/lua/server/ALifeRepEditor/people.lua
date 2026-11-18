--- Server-side editing of one NPC's relationship with the player: the
--- opinion A-Life keeps on each NPC (-100..100, "Hates you" to "Would stand
--- by you") and the per-player hostile and wary flags. Writes go through
--- A-Life's own opinion module, so its drift and per-NPC limits still apply.
require "ALifeRepEditor/editor"
require "ALifeRepEditor/opinion-bands"
require "ALifeRepEditor/people-rows"

ALifeRepEditor = ALifeRepEditor or {}

local Editor = ALifeRepEditor.Editor
local Bands = ALifeRepEditor.OpinionBands
local Rows = ALifeRepEditor.PeopleRows

local People = {
    listCap = 200,
    WARMED = "They've warmed to you.",
    SOURED = "They've soured on you.",
    OFF = "NPC opinions are turned off in A-Life's sandbox options.",
}
ALifeRepEditor.People = People

--- Returns A-Life's opinion module, or nil.
function People.opinion()
    return Editor.alife().opinion
end

--- Returns true when A-Life is tracking NPC opinions in this world.
function People.enabled()
    local opinion = People.opinion()
    if opinion == nil or type(opinion.valueOf) ~= "function" then return false end
    return type(opinion.enabled) ~= "function" or opinion.enabled() == true
end

--- Returns the opinion bands built from A-Life's labels.
function People.bands()
    local opinion = People.opinion()
    return Bands.fromLabels(opinion ~= nil and opinion.labels or nil, opinion ~= nil and opinion.minimum or nil)
end

--- Returns the lowest and highest opinion A-Life allows.
function People.range()
    local opinion = People.opinion()
    return tonumber(opinion ~= nil and opinion.minimum or nil) or Bands.MIN,
        tonumber(opinion ~= nil and opinion.maximum or nil) or Bands.MAX
end

--- Returns a living NPC's record by uid, or nil.
function People.record(uid)
    local registry = Editor.alife().registry
    if registry == nil or type(registry.read) ~= "function" or uid == nil then return nil end
    local record = registry.read(tostring(uid))
    if type(record) ~= "table" or record.lifecycle == "dead" then return nil end
    return record
end

--- Returns an NPC's current opinion of the player, the stored row, and the baseline it drifts to.
function People.valueOf(record, player)
    local value, row, base = People.opinion().valueOf(record, player)
    return tonumber(value) or 0, row, tonumber(base) or 0
end

--- Returns how an NPC treats the player right now (hostile, careful, neutral, friendly, allied), or nil.
function People.stance(record, player)
    local relations = ProjectALife ~= nil and ProjectALife.Relations or nil
    if Editor.adapters.relations ~= nil then relations = Editor.adapters.relations end
    if relations == nil or type(relations.playerStance) ~= "function" then return nil end
    local ok, stance = pcall(relations.playerStance, record, player)
    return ok and stance ~= nil and tostring(stance) or nil
end

--- Returns true when a per-player flag on an NPC is set (hostileToPlayerKeys, carefulPlayerKeys).
function People.flag(record, field, key)
    local flags = type(record.memory) == "table" and record.memory[field] or nil
    return type(flags) == "table" and flags[key] ~= nil and flags[key] ~= false
end

--- Returns A-Life's companions module when companions are switched on, or nil.
function People.crew()
    local companions = ProjectALife ~= nil and ProjectALife.Companions or nil
    if Editor.adapters.companions ~= nil then companions = Editor.adapters.companions end
    if companions == nil or type(companions.recruit) ~= "function" or type(companions.dismiss) ~= "function" then return nil end
    if type(companions.enabled) == "function" and companions.enabled() ~= true then return nil end
    return companions
end

--- Returns the key A-Life's companions use for the player, or nil.
function People.crewKey(player)
    local companions = People.crew()
    if companions == nil or type(companions.playerKey) ~= "function" then return nil end
    return companions.playerKey(player)
end

--- Returns the most companions one player may have.
function People.crewMax()
    local companions = People.crew()
    local rules = companions ~= nil and type(companions.rules) == "function" and companions.rules() or nil
    return type(rules) == "table" and tonumber(rules.maxPerPlayer) or 5
end

--- Returns "yours" when an NPC is in the player's crew, "other" when in another player's, or nil.
function People.crewOf(record, crewKey)
    local memory = type(record) == "table" and record.memory or nil
    local entry = type(memory) == "table" and memory.companion or nil
    local owner = type(entry) == "table" and entry.owner or nil
    if type(owner) ~= "string" or owner == "" then return nil end
    return owner == crewKey and "yours" or "other"
end

--- Builds what the window shows about one NPC.
function People.describe(record, key, player, bands, withStance, crewKey)
    local value, row, base = People.valueOf(record, player)
    local factionId = record.factionId
    return {
        uid = tostring(record.uid), name = Editor.nameOf(record),
        factionId = factionId, factionName = factionId ~= nil and Editor.factionName(factionId) or "",
        value = value, base = base, label = Bands.labelAt(bands, value),
        met = row ~= nil, at = type(row) == "table" and tonumber(row.at) or nil,
        why = type(row) == "table" and type(row.why) == "string" and row.why or nil,
        hostile = People.flag(record, "hostileToPlayerKeys", key),
        wary = People.flag(record, "carefulPlayerKeys", key),
        stance = withStance and People.stance(record, player) or nil,
        crew = People.crewOf(record, crewKey),
    }
end

--- Lists the living NPCs who have an opinion of the player, plus the focused NPC even if they haven't met.
function People.list(player, focusUid)
    local registry = Editor.alife().registry
    local key = Editor.keyOf(player)
    local result = {}
    if not People.enabled() or key == nil or registry == nil or type(registry.each) ~= "function" then return result end
    local bands, found, crewKey = People.bands(), {}, People.crewKey(player)
    registry.each(function(record)
        if record.lifecycle ~= "dead" and type(record.memory) == "table" then
            local map = record.memory.opinion
            local met = type(map) == "table" and type(map[key]) == "table"
            if met or (crewKey ~= nil and People.crewOf(record, crewKey) == "yours") then found[#found + 1] = record end
        end
        return false
    end)
    local focus = focusUid ~= nil and tostring(focusUid) or nil
    local focusRecord = People.record(focus)
    local hasFocus = false
    for _, record in ipairs(found) do
        if tostring(record.uid) == focus then hasFocus = true end
    end
    if focusRecord ~= nil and not hasFocus then found[#found + 1] = focusRecord end
    for _, record in ipairs(found) do
        result[#result + 1] = People.describe(record, key, player, bands, true, crewKey)
    end
    Rows.sort(result, focus)
    while #result > People.listCap do result[#result] = nil end
    return result
end

--- Sets an NPC's opinion of the player to an exact value.
function People.setValue(player, uid, value)
    if not People.enabled() then return false, People.OFF end
    local opinion, key, record = People.opinion(), Editor.keyOf(player), People.record(uid)
    if key == nil or record == nil then return false, "That person isn't around any more." end
    local low, high = People.range()
    local bands = People.bands()
    local before, _, base = People.valueOf(record, player)
    local target = Bands.nudged(value, 0, low, high)
    local now = Editor.now()
    local why = target >= before and People.WARMED or People.SOURED
    local mutate = function(memory)
        local row
        if type(opinion.store) == "function" then
            row = opinion.store(memory, key, base, now)
        else
            memory.opinion = type(memory.opinion) == "table" and memory.opinion or {}
            memory.opinion[key] = type(memory.opinion[key]) == "table" and memory.opinion[key] or {}
            row = memory.opinion[key]
        end
        row.v, row.at = target, now
        if target ~= before then row.why, row.w = why, 0 end
    end
    local written
    if type(opinion.write) == "function" then
        written = opinion.write(record.uid, mutate)
    else
        local fresh = { memory = { opinion = { [key] = Editor.copy(type(record.memory) == "table"
            and type(record.memory.opinion) == "table" and record.memory.opinion[key] or nil) } } }
        mutate(fresh.memory)
        written = Editor.writeOpinion(record.uid, key, fresh.memory.opinion[key])
    end
    if not written then return false, "A-Life wouldn't save that change; try again." end
    return true, Editor.nameOf(record) .. ": " .. Bands.labelAt(bands, before) .. " (" .. Rows.signed(before) .. ") -> "
        .. Bands.labelAt(bands, target) .. " (" .. Rows.signed(target) .. ")."
end

--- Moves an NPC's opinion of the player up or down.
function People.nudge(player, uid, delta)
    local record = People.record(uid)
    if not People.enabled() then return false, People.OFF end
    if record == nil then return false, "That person isn't around any more." end
    local current = People.valueOf(record, player)
    return People.setValue(player, uid, current + (tonumber(delta) or 0))
end

--- Jumps an NPC's opinion of the player to the middle of a band.
function People.setBand(player, uid, index)
    local bands = People.bands()
    local position = tonumber(index)
    if position == nil or bands[position] == nil then return false, "Unknown relationship." end
    local _, high = People.range()
    return People.setValue(player, uid, Bands.target(bands, position, high))
end

--- Clears an NPC's memory of the player, so they judge them as a stranger again.
function People.forget(player, uid)
    if not People.enabled() then return false, People.OFF end
    local key, record = Editor.keyOf(player), People.record(uid)
    if key == nil or record == nil then return false, "That person isn't around any more." end
    local map = type(record.memory) == "table" and record.memory.opinion or nil
    if type(map) ~= "table" or map[key] == nil then return true, Editor.nameOf(record) .. " already sees you as a stranger." end
    if not Editor.writeOpinion(record.uid, key, nil) then return false, "A-Life wouldn't save that change; try again." end
    return true, Editor.nameOf(record) .. " has forgotten you and sees you as a stranger again."
end

--- Writes one per-player flag on an NPC; nil clears it.
function People.writeFlag(record, field, key, value)
    local registry = Editor.alife().registry
    local updated = registry.update(record.uid, record.revision, function(fresh)
        fresh.memory = type(fresh.memory) == "table" and fresh.memory or {}
        local flags = type(fresh.memory[field]) == "table" and fresh.memory[field] or {}
        flags[key] = value
        fresh.memory[field] = flags
    end)
    return updated ~= nil and updated ~= false
end

--- Ends an NPC's personal hostility and wariness toward the player.
function People.calm(player, uid)
    local key, record = Editor.keyOf(player), People.record(uid)
    if key == nil or record == nil then return false, "That person isn't around any more." end
    People.writeFlag(record, "hostileToPlayerKeys", key, nil)
    record = People.record(uid)
    People.writeFlag(record, "carefulPlayerKeys", key, nil)
    record = People.record(uid)
    local name = Editor.nameOf(record)
    if People.stance(record, player) == "hostile" then
        return true, name .. " calmed down, but their faction is still hostile; forgive it on the Reputation tab."
    end
    return true, name .. " no longer holds a personal grudge against you."
end

--- Makes an NPC personally hostile to the player.
function People.makeHostile(player, uid)
    local key, record = Editor.keyOf(player), People.record(uid)
    if key == nil or record == nil then return false, "That person isn't around any more." end
    if not People.writeFlag(record, "hostileToPlayerKeys", key, true) then
        return false, "A-Life wouldn't save that change; try again."
    end
    return true, Editor.nameOf(record) .. " is now hostile to you."
end

--- Finishes a join the way A-Life's own talk options do: a visiting guest
--- leaves their visit, and a captive is let go.
function People.settleJoin(record, player)
    local join = ProjectALife ~= nil and ProjectALife.VisitorJoin or nil
    if join ~= nil and type(join.pendingOf) == "function" and type(join.detach) == "function" and join.pendingOf(record.uid) ~= nil then
        pcall(join.detach, record.uid, player)
    end
    local captives = ProjectALife ~= nil and ProjectALife.Captives or nil
    local held = type(record.memory) == "table" and record.memory.captive or nil
    if type(held) == "table" and captives ~= nil and type(captives.release) == "function" then
        pcall(captives.release, record.uid, "joined")
    end
end

--- Makes an NPC join the player's crew as an A-Life companion, walking them over first if needed.
function People.joinCrew(player, uid)
    local companions = People.crew()
    if companions == nil then return false, Rows.crewRefusal("disabled") end
    local record = People.record(uid)
    if record == nil then return false, Rows.crewRefusal("gone") end
    local name, key, maximum = Editor.nameOf(record), People.crewKey(player), People.crewMax()
    local crew = People.crewOf(record, key)
    if crew == "yours" then return true, name .. " is already in your crew." end
    if crew == "other" then return false, Rows.crewRefusal("taken", name) end
    if key ~= nil and #companions.roster(key) >= maximum then return false, Rows.crewRefusal("roster_full", name, maximum) end
    local shell = companions.shellOf(record.uid)
    if shell == nil then return false, Rows.crewRefusal("unavailable", name) end
    local moved = false
    local reach = type(companions.settings) == "table" and tonumber(companions.settings.recruitReach) or 4
    if companions.flatDistance(shell, player) > reach and type(companions.bringNear) == "function" then
        local ran, done = pcall(companions.bringNear, shell, player)
        moved = ran and done == true
    end
    local joined, why = companions.recruit(player, record.uid, { open = true })
    if joined ~= true then return false, Rows.crewRefusal(why, name, maximum) end
    People.settleJoin(record, player)
    return true, name .. (moved and " came over and joined your crew." or " joined your crew.")
end

--- Sends an NPC in the player's crew on their way, as A-Life's own dismiss does.
function People.leaveCrew(player, uid)
    local companions = People.crew()
    if companions == nil then return false, Rows.crewRefusal("disabled") end
    local record = People.record(uid)
    if record == nil then return false, Rows.crewRefusal("gone") end
    local name = Editor.nameOf(record)
    if People.crewOf(record, People.crewKey(player)) ~= "yours" then return false, Rows.crewRefusal("not_yours", name) end
    local left, why = companions.dismiss(player, record.uid, "order")
    if left ~= true then return false, Rows.crewRefusal(why, name) end
    return true, name .. " left your crew."
end

--- Adds the People tab's data to a window state.
function People.addTo(state, player, focusUid)
    state.peopleOn = People.enabled()
    local bands = People.bands()
    state.opinionBands = bands
    state.opinionMin, state.opinionMax = People.range()
    local opinion = People.opinion()
    state.opinionDecay = opinion ~= nil and type(opinion.decay) == "function" and tonumber((opinion.decay())) or nil
    state.crewOn = People.crew() ~= nil
    state.crewMax = People.crewMax()
    local crewKey = People.crewKey(player)
    local companions = People.crew()
    state.crewSize = crewKey ~= nil and #companions.roster(crewKey) or 0
    state.people = People.list(player, focusUid)
    state.focus = focusUid ~= nil and tostring(focusUid) or nil
    return state
end

return People
