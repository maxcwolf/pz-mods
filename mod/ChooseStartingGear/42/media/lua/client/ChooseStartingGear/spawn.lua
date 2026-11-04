--- Applies the pending selection when a brand-new character enters the world.
require "ChooseStartingGear/apply"

CSG_Spawn = CSG_Spawn or {}
local MAX_TICKS = 600
local RETRY_TICKS = 120

--- Runs the plan once and schedules one retry for anything whose slot or bag
--- was not on the player yet.
local function applyOnce(player, selection, allowRetry)
    local desc = MainScreen.instance and MainScreen.instance.desc
    local ok, plan = pcall(CSG_Apply.toPlayer, player, selection, desc)
    if not ok then
        print("[ChooseStartingGear] failed to apply starting gear: " .. tostring(plan))
        return
    end
    local retry = CSG_Plan.retrySelection(plan)
    if allowRetry and not CSG_Selection.isEmpty(retry) then
        local ticks = 0
        local function onTick()
            ticks = ticks + 1
            if ticks >= RETRY_TICKS then
                Events.OnTick.Remove(onTick)
                print("[ChooseStartingGear] retrying skipped gear")
                applyOnce(player, retry, false)
            end
        end
        Events.OnTick.Add(onTick)
    end
end

--- Applies the pending selection once the player's hotbar exists.
local function applyWhenReady(player)
    if not CSG_State.pending then
        return
    end
    CSG_State.pending = false
    local selection = CSG_State.selection
    if CSG_Selection.isEmpty(selection) then
        return
    end
    local ticks = 0
    local function onTick()
        ticks = ticks + 1
        if getPlayerHotbar(player:getPlayerNum()) or ticks >= MAX_TICKS then
            Events.OnTick.Remove(onTick)
            applyOnce(player, selection, true)
        end
    end
    Events.OnTick.Add(onTick)
end

--- Single player: a brand-new game fires OnNewGame with the player.
local function onNewGame(player, square)
    applyWhenReady(player)
end

--- Multiplayer: OnCreatePlayer also fires for returning characters, so only a
--- character with no survival time counts as new.
local function onCreatePlayer(index, player)
    if isClient() and player and player:getHoursSurvived() == 0 then
        applyWhenReady(player)
    end
end

--- Returning to the main menu drops any selection that was never consumed.
local function onMainMenuEnter()
    CSG_State.pending = false
end

Events.OnNewGame.Add(onNewGame)
Events.OnCreatePlayer.Add(onCreatePlayer)
Events.OnMainMenuEnter.Add(onMainMenuEnter)
