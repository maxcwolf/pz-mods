local Signature = require("BaseBlueprints/signature")

test("signature: open and closed doors match, different doors do not", function()
    local closed = { cls = "IsoDoor", sprite = "fixtures_doors_01_0", north = true }
    local open = { cls = "IsoDoor", sprite = "fixtures_doors_01_2", north = true }
    local other = { cls = "IsoDoor", sprite = "fixtures_doors_02_0", north = true }
    local west = { cls = "IsoDoor", sprite = "fixtures_doors_01_0" }
    eq(Signature.of(closed), Signature.of(open))
    ok(Signature.of(closed) ~= Signature.of(other), "other sheet differs")
    ok(Signature.of(closed) ~= Signature.of(west), "facing differs")
end)

test("signature: furniture sprites, floors, overlays and attachments count", function()
    local a = { cls = "IsoObject", sprite = "furniture_seating_indoor_01_0" }
    local b = { cls = "IsoObject", sprite = "furniture_seating_indoor_01_1" }
    ok(Signature.of(a) ~= Signature.of(b), "rotated couch differs")
    local wall = { cls = "IsoObject", sprite = "walls_interior_house_01_0", attached = { "b", "a" } }
    local same = { cls = "IsoObject", sprite = "walls_interior_house_01_0", attached = { "a", "b" } }
    eq(Signature.of(wall), Signature.of(same), "attachment order ignored")
    local painted = { cls = "IsoObject", sprite = "walls_interior_house_01_0", overlay = "paint_blue" }
    ok(Signature.of(painted) ~= Signature.of({ cls = "IsoObject", sprite = "walls_interior_house_01_0" }), "paint differs")
    ok(Signature.of({ cls = "IsoObject", sprite = "x_1", floor = true }) ~= Signature.of({ cls = "IsoObject", sprite = "x_1" }))
end)

test("signature: square text ignores object order and empty is blank", function()
    local a = { cls = "IsoObject", sprite = "a_1" }
    local b = { cls = "IsoObject", sprite = "b_1" }
    eq(Signature.ofList({ a, b }), Signature.ofList({ b, a }))
    eq(Signature.ofList({}), "")
    eq(Signature.ofList(nil), "")
end)
