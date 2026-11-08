local Capacity = require("VehicleStorageCapacity/capacity")

test("capacity: scale rounds, floors at 1 and caps at 1000", function()
    eq(Capacity.scale(50, 200), 100)
    eq(Capacity.scale(35, 150), 53, "52.5 rounds up")
    eq(Capacity.scale(5, 10), 1, "0.5 rounds to 1")
    eq(Capacity.scale(1, 10), 1, "never 0")
    eq(Capacity.scale(600, 300), 1000, "engine cap")
end)

test("capacity: first sight scales the game's value and remembers it", function()
    local d = Capacity.decide({ raw = 50, percent = 200, itemId = 7, needsItem = true })
    eq(d.capacity, 100); eq(d.record.base, 50); eq(d.record.applied, 100); eq(d.record.item, 7)
end)

test("capacity: an already scaled part is left alone", function()
    local d = Capacity.decide({ raw = 100, percent = 200, itemId = 7, needsItem = true,
        record = { base = 50, applied = 100, item = 7 } })
    eq(d.capacity, nil); eq(d.record.base, 50)
end)

test("capacity: a new percent rescales from the remembered base, not the current value", function()
    local d = Capacity.decide({ raw = 100, percent = 300, itemId = 7, record = { base = 50, applied = 100, item = 7 } })
    eq(d.capacity, 150)
end)

test("capacity: back to 100 restores the base and forgets", function()
    local d = Capacity.decide({ raw = 100, percent = 100, itemId = 7, record = { base = 50, applied = 100, item = 7 } })
    eq(d.capacity, 50); eq(d.record, nil); ok(not d.keep, "clears the record")
end)

test("capacity: 100 on an untouched part does nothing", function()
    local d = Capacity.decide({ raw = 50, percent = 100, itemId = 7 })
    eq(d.capacity, nil); eq(d.record, nil)
end)

test("capacity: a game recompute (new value) becomes the new base", function()
    local d = Capacity.decide({ raw = 40, percent = 200, itemId = 7, record = { base = 50, applied = 100, item = 7 } })
    eq(d.capacity, 80); eq(d.record.base, 40)
end)

test("capacity: a different item with the same value is a recompute", function()
    local d = Capacity.decide({ raw = 100, percent = 200, itemId = 8, record = { base = 50, applied = 100, item = 7 } })
    eq(d.capacity, 200); eq(d.record.base, 100); eq(d.record.item, 8)
end)

test("capacity: occupied seats keep everything", function()
    local d = Capacity.decide({ raw = 5, percent = 200, occupiedSeat = true, record = { base = 20, applied = 40, item = -1 } })
    ok(d.keep, "keep"); eq(d.capacity, nil)
end)

test("capacity: a part missing its item keeps the game's value and forgets", function()
    local d = Capacity.decide({ raw = 120, percent = 200, needsItem = true, itemId = nil })
    eq(d.capacity, nil); eq(d.record, nil); ok(not d.keep, "clears")
end)

test("capacity: zero-capacity parts are skipped", function()
    local d = Capacity.decide({ raw = 0, percent = 200, itemId = 3, needsItem = true })
    eq(d.capacity, nil); eq(d.record, nil)
end)

test("capacity: itemless built-in storage uses the no-item id", function()
    local d = Capacity.decide({ raw = 130, percent = 200, needsItem = false })
    eq(d.capacity, 260); eq(d.record.item, Capacity.NO_ITEM)
end)
