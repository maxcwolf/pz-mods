--- Spawns the build armed at Play when a brand-new single-player game starts:
--- waits for the area around the player to finish loading, spawns, then
--- re-applies the part choices once more in case damnlib's own defaults landed
--- after ours. Afterwards it watches for a spawn-location mod (Spawn Selector
--- and the like) moving the character, and moves the car along; follow.lua
--- makes the decisions.
require "ChooseStartingVehicle/state"
require "ChooseStartingVehicle/apply"
local Plan = require("ChooseStartingVehicle/plan")
local Settings = require("ChooseStartingVehicle/settings")
local Follow = require("ChooseStartingVehicle/follow")

CSV_Spawn = CSV_Spawn or {}

CSV_Spawn.DELAY_TICKS = 30
CSV_Spawn.REAPPLY_TICKS = 180
CSV_Spawn.FIRST_LOAD_TIMEOUT_MS = 30000

local LOG = "[ChooseStartingVehicle] "

--- Runs `fn` once after `ticks` game ticks.
local function after(ticks, fn)
    local count = 0
    local function onTick()
        count = count + 1
        if count >= ticks then
            Events.OnTick.Remove(onTick)
            fn()
        end
    end
    Events.OnTick.Add(onTick)
end

--- Runs `fn` every tick until it returns true or raises an error (logged).
local function everyTick(label, fn)
    local function onTick()
        local ok, finished = pcall(fn)
        if not ok then
            print(LOG .. label .. " failed: " .. tostring(finished))
        end
        if not ok or finished then
            Events.OnTick.Remove(onTick)
        end
    end
    Events.OnTick.Add(onTick)
end

--- True when the ground-floor square at (x, y) is in the loaded cell.
local function isLoaded(x, y)
    return getCell():getGridSquare(x, y, 0) ~= nil
end

--- True when the squares under the player and a ring around them are loaded.
function CSV_Spawn.areaLoaded(player, settings)
    if not getCell() then
        return false
    end
    local points = Follow.probePoints(math.floor(player:getX()), math.floor(player:getY()), settings.searchRadius, Follow.DEFAULTS.probeCap)
    return Follow.allLoaded(points, isLoaded)
end

--- Schedules the re-apply pass for a spawn.
local function scheduleReapply(result, plan)
    after(CSV_Spawn.REAPPLY_TICKS, function()
        local reOk, err = pcall(CSV_Apply.reapply, result, plan)
        if not reOk then
            print(LOG .. "re-apply failed: " .. tostring(err))
        end
    end)
end

--- Spawns the plan near the player now; returns the result or nil (logged).
local function spawnNow(player, plan, settings)
    local ok, result = pcall(CSV_Apply.spawn, player, plan, settings)
    if not ok then
        print(LOG .. "spawn failed: " .. tostring(result))
        return nil
    end
    if result then
        scheduleReapply(result, plan)
    end
    return result
end

--- Spawns a fresh copy near the player's new spot, then removes the old one;
--- if the new spawn fails the old car stays where it was. Returns the new result or nil.
function CSV_Spawn.follow(player, plan, settings, old)
    local fresh = spawnNow(player, plan, settings)
    if not fresh then
        print(LOG .. "could not respawn near the player's new spot; the car stays at "
            .. math.floor(old.x) .. "," .. math.floor(old.y))
        return nil
    end
    local ok, err = pcall(CSV_Apply.removeSpawn, old, player)
    if not ok then
        print(LOG .. "could not remove the old car: " .. tostring(err))
    end
    print(LOG .. "the player was moved; moved the starting vehicle from "
        .. math.floor(old.x) .. "," .. math.floor(old.y) .. " to " .. math.floor(fresh.x) .. "," .. math.floor(fresh.y))
    return fresh
end

--- Builds one Follow sample from the player and the current spawn.
local function sample(player, settings, state, current)
    local inside = player:getVehicle()
    local s = {
        x = player:getX(),
        y = player:getY(),
        z = player:getZ(),
        t = getTimestampMs(),
        inVehicle = inside ~= nil,
        inOurVehicle = inside ~= nil and (inside == current.vehicle or inside == current.trailer),
        dead = player:isDead(),
        carX = current.vehicle:getX(),
        carY = current.vehicle:getY(),
    }
    if Follow.isLoading(state) then
        s.loaded = CSV_Spawn.areaLoaded(player, settings)
    end
    return s
end

--- Messages for the reasons a watch can end; quiet reasons are left out.
local STOP_MESSAGES = {
    ["load-timeout"] = "the player was moved but the area there did not load in time; the car stays where it was",
    ["spawn-failed"] = "stopped following the player after a failed respawn",
    ["max-follows"] = "followed the player as often as allowed; no more moves",
}

--- Watches the player after a spawn and moves the car along when a
--- spawn-location mod teleports them far away.
function CSV_Spawn.watch(player, plan, settings, result)
    local state = Follow.new(nil, result.x, result.y)
    local current = result
    everyTick("following the player", function()
        local action = Follow.step(state, sample(player, settings, state, current))
        if action == "respawn" then
            local fresh = CSV_Spawn.follow(player, plan, settings, current)
            Follow.done(state, fresh ~= nil, fresh and fresh.x, fresh and fresh.y)
            current = fresh or current
        end
        if state.phase == "stopped" then
            local message = STOP_MESSAGES[state.reason]
            if message then
                print(LOG .. message)
            end
            return true
        end
        return false
    end)
end

--- Spawns the plan for a player once the area around them has loaded (or a
--- timeout passed), then starts watching for a teleport.
function CSV_Spawn.run(player, plan, settings)
    local since = getTimestampMs()
    everyTick("waiting for the spawn area", function()
        local loaded = CSV_Spawn.areaLoaded(player, settings)
        if not loaded and not Follow.timedOut(since, getTimestampMs(), CSV_Spawn.FIRST_LOAD_TIMEOUT_MS) then
            return false
        end
        if not loaded then
            print(LOG .. "the area around the player is still not loaded; trying to spawn anyway")
        end
        local result = spawnNow(player, plan, settings)
        if result then
            CSV_Spawn.watch(player, plan, settings, result)
        end
        return true
    end)
end

--- Single player: a brand-new game fires OnNewGame with the player.
local function onNewGame(player, square)
    if isClient() or isServer() then
        return
    end
    local build = CSV_State.takePending()
    if not build then
        return
    end
    local settings = Settings.current()
    local plan = Plan.fromBuild(build, settings)
    if not plan then
        return
    end
    after(CSV_Spawn.DELAY_TICKS, function()
        CSV_Spawn.run(player, plan, settings)
    end)
end

--- Returning to the main menu drops a spawn that never happened, in memory
--- and in the last build file, keeping the build itself.
local function onMainMenuEnter()
    CSV_State.pending = false
    local _, pending = CSV_State.readLast()
    if pending then
        CSV_State.load()
        CSV_State.saveLast(false)
    end
end

Events.OnNewGame.Add(onNewGame)
Events.OnMainMenuEnter.Add(onMainMenuEnter)
