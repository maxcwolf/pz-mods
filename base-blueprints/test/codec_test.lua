local Codec = require("BaseBlueprints/codec")

test("codec: round-trips nested values", function()
    local value = {
        "a", 2, true, false, -3.5,
        name = "Fridge \"big\"\nline\ttab\\",
        list = { { t = "Base.Axe", n = 2 }, {} },
        ["odd key"] = 1,
        [10] = "sparse",
        ["true"] = "keyword key",
    }
    local text = Codec.encode(value)
    local back = assert(Codec.decode(text))
    eq(back[1], "a")
    eq(back[2], 2)
    eq(back[3], true)
    eq(back[4], false)
    eq(back[5], -3.5)
    eq(back.name, value.name)
    eq(back.list[1].t, "Base.Axe")
    eq(back.list[1].n, 2)
    eq(#back.list[2], 0)
    eq(back["odd key"], 1)
    eq(back[10], "sparse")
    eq(back["true"], "keyword key")
    eq(Codec.encode(back), text, "stable re-encode")
end)

test("codec: output is one line and key order is stable", function()
    local a = Codec.encode({ b = 1, a = 2, c = "x\ny" })
    eq(a, "{a=2,b=1,c=\"x\\ny\"}")
    ok(not string.find(a, "\n"), "no raw newline")
end)

test("codec: rejects broken text without throwing", function()
    local v, err = Codec.decode("{a=1,")
    eq(v, nil)
    ok(err, "has an error")
    eq((Codec.decode("")), nil)
    eq((Codec.decode("{a=1}junk")), nil)
end)

test("codec: plain drops functions and non-finite numbers", function()
    local copy = Codec.plain({ a = 1, f = print, n = 0 / 0, inner = { b = "x" } })
    eq(copy.a, 1)
    eq(copy.f, nil)
    eq(copy.n, nil)
    eq(copy.inner.b, "x")
end)
