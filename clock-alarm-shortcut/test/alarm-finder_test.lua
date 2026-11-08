local AlarmFinder = ClockAlarmShortcut_AlarmFinder
local S = PZ_Stubs

test("watches and alarm clocks are alarms, other items are not", function()
    eq(AlarmFinder.isAlarm(S.alarm("AlarmClockClothing", true)), true, "watch")
    eq(AlarmFinder.isAlarm(S.alarm("AlarmClock", true)), true, "alarm clock")
    eq(AlarmFinder.isAlarm(S.plainItem()), false, "plain item")
    eq(AlarmFinder.isAlarm(nil), false, "nil")
end)

test("only digital alarms can be set", function()
    eq(AlarmFinder.isSettable(S.alarm("AlarmClockClothing", true)), true, "digital")
    eq(AlarmFinder.isSettable(S.alarm("AlarmClockClothing", false)), false, "analog")
end)

test("a worn digital watch is found", function()
    local watch = S.alarm("AlarmClockClothing", true)
    local player = S.player(0, { S.plainItem(), watch }, {})
    eq(AlarmFinder.findForPlayer(player), watch)
end)

test("an analog watch is skipped in favor of a held digital alarm clock", function()
    local analog = S.alarm("AlarmClockClothing", false)
    local clock = S.alarm("AlarmClock", true, { equipped = true })
    local player = S.player(0, { analog }, { analog, clock })
    eq(AlarmFinder.findForPlayer(player), clock)
end)

test("a digital alarm clock in a pocket but not held is ignored", function()
    local clock = S.alarm("AlarmClock", true)
    local player = S.player(0, {}, { clock })
    eq(AlarmFinder.findForPlayer(player), nil)
end)

test("worn items win over held ones", function()
    local watch = S.alarm("AlarmClockClothing", true, { name = "watch" })
    local clock = S.alarm("AlarmClock", true, { equipped = true, name = "clock" })
    local player = S.player(0, { watch }, { clock, watch })
    eq(AlarmFinder.findForPlayer(player).name, "watch")
end)

test("dead or missing players have no alarm", function()
    eq(AlarmFinder.findForPlayer(nil), nil, "missing")
    local dead = S.player(0, { S.alarm("AlarmClockClothing", true) }, {}, true)
    eq(AlarmFinder.findForPlayer(dead), nil, "dead")
end)

test("find returns the first local player that has an alarm, with their number", function()
    local watch = S.alarm("AlarmClockClothing", true)
    S.players = { S.player(0, {}, {}), S.player(1, { watch }, {}) }
    local alarm, num = AlarmFinder.find()
    eq(alarm, watch, "alarm")
    eq(num, 1, "player number")
end)

test("find returns nothing when no one has an alarm", function()
    S.players = { S.player(0, {}, {}) }
    eq(AlarmFinder.find(), nil)
end)
