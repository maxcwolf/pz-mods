--- Pure bookkeeping for pausing the game while the editor is open and putting
--- the old speed back on close, without unpausing a game the player paused.
ALifeRepEditor = ALifeRepEditor or {}

local Pause = {}
ALifeRepEditor.Pause = Pause

--- Decides whether opening should pause and returns the state to keep for closing.
function Pause.open(state, speed, multiplier, multiplayer)
    if type(state) == "table" and state.open == true then return state, false end
    local paused = multiplayer ~= true and (tonumber(speed) or 0) > 0
    return { open = true, paused = paused, speed = tonumber(speed) or 1, multiplier = tonumber(multiplier) or 1 }, paused
end

--- Returns the speed and multiplier to restore on close, or nil when nothing should change.
function Pause.close(state, currentSpeed)
    if type(state) ~= "table" or state.open ~= true then return nil end
    if state.paused ~= true or (tonumber(currentSpeed) or 0) ~= 0 then return nil end
    return { speed = state.speed, multiplier = state.multiplier }
end

return Pause
