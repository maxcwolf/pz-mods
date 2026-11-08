require "ALifeRepEditor/pause"
local Pause = ALifeRepEditor.Pause

test("opening a running single-player game pauses it", function()
    local state, pause = Pause.open(nil, 1, 1, false)
    ok(pause); ok(state.paused); eq(state.speed, 1)
end)

test("opening an already paused game leaves it alone and close does not unpause", function()
    local state, pause = Pause.open(nil, 0, 1, false)
    ok(not pause)
    eq(Pause.close(state, 0), nil)
end)

test("multiplayer never pauses", function()
    local state, pause = Pause.open(nil, 1, 1, true)
    ok(not pause); eq(Pause.close(state, 1), nil)
end)

test("close restores the old speed and multiplier", function()
    local state = Pause.open(nil, 3, 20, false)
    local restore = Pause.close(state, 0)
    eq(restore.speed, 3); eq(restore.multiplier, 20)
end)

test("close does nothing if the player already changed the speed", function()
    local state = Pause.open(nil, 1, 1, false)
    eq(Pause.close(state, 2), nil)
end)

test("opening twice keeps the first state", function()
    local state = Pause.open(nil, 2, 5, false)
    local again, pause = Pause.open(state, 0, 1, false)
    ok(again == state); ok(not pause)
end)
