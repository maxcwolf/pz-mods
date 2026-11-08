--- The undo list.
local History = require("FurnishByRoom/history")

test("history: push, pop newest first, ignore empty", function()
    local h = History.new()
    ok(History.push(h, { kind = "place", parts = { 1 } }))
    ok(History.push(h, { kind = "floor", tiles = { 1, 2 } }))
    ok(not History.push(h, { kind = "remove", parts = {} }), "empty")
    eq(History.size(h), 2)
    eq(History.pop(h).kind, "floor")
    eq(History.pop(h).kind, "place")
    eq(History.pop(h), nil)
end)

test("history: drops the oldest past the limit", function()
    local h = History.new(3)
    for i = 1, 5 do
        History.push(h, { kind = "place", parts = { i } })
    end
    eq(History.size(h), 3)
    eq(h.actions[1].parts[1], 3)
end)
