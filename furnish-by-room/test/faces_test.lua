--- Rotation order through an entry's facings.
local Faces = require("FurnishByRoom/faces")

test("faces: cycles N, W, S, E and wraps", function()
    local entry = { faces = { N = "n", W = "w", S = "s", E = "e" } }
    eq(table.concat(Faces.list(entry), ","), "n,w,s,e")
    eq(Faces.next(entry, "s"), "e")
    eq(Faces.next(entry, "e"), "n")
    eq(Faces.next(entry, "unknown"), "n")
end)

test("faces: skips missing facings and handles none", function()
    local two = { faces = { S = "s", E = "e" } }
    eq(Faces.next(two, "s"), "e")
    eq(Faces.next(two, "e"), "s")
    local plain = { faces = { _ = "only" } }
    eq(Faces.next(plain, "only"), "only")
    eq(Faces.next({ faces = {} }, "x"), "x")
end)
