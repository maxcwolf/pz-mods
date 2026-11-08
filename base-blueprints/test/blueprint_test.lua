local Blueprint = require("BaseBlueprints/blueprint")

local AREA = { x1 = 0, y1 = 0, x2 = 3, y2 = 3, z1 = 0, z2 = 1 }

test("blueprint: names and ids are cleaned", function()
    eq(Blueprint.cleanName("  My   Base\n "), "My   Base")
    eq(Blueprint.cleanName(""), "Base")
    eq(#Blueprint.cleanName(string.rep("x", 100)), Blueprint.MAX_NAME)
    eq(Blueprint.makeId("Riverside / Farm!", 1730000000), "riverside-farm-1730000000")
    eq(Blueprint.makeId("!!!", 5), "base-5")
end)

test("blueprint: lines round-trip with counts", function()
    local squares = {
        ["1,1,0"] = { { cls = "IsoObject", sprite = "floor_1", floor = true },
            { cls = "IsoObject", sprite = "crate_1", containers = { { type = "crate", items = { { t = "Base.Axe", n = 1 } } } } } },
        ["2,1,0"] = {},
    }
    local bp = Blueprint.new({ id = "b-1", name = "Home", area = AREA, changedOnly = true }, squares)
    eq(bp.meta.squares, 2)
    eq(bp.meta.objects, 2)
    eq(bp.meta.contents, true)
    local lines = Blueprint.toLines(bp)
    eq(lines[1], Blueprint.HEADER)
    eq(#lines, 4)
    local back = assert(Blueprint.fromLines(lines))
    eq(back.meta.name, "Home")
    eq(#back.squares["2,1,0"], 0, "empty square kept")
    eq(back.squares["1,1,0"][2].containers[1].items[1].t, "Base.Axe")
end)

test("blueprint: contents are stripped unless asked for", function()
    local squares = { ["1,1,0"] = { { cls = "IsoObject", sprite = "crate_1", containers = { { type = "crate", items = {} } } } } }
    local bp = Blueprint.new({ id = "b", name = "x", area = AREA }, squares)
    eq(Blueprint.squaresToApply(bp, false)["1,1,0"][1].containers, nil)
    ok(Blueprint.squaresToApply(bp, true)["1,1,0"][1].containers)
    ok(squares["1,1,0"][1].containers, "original untouched")
end)

test("blueprint: bad files are refused", function()
    eq((Blueprint.fromLines({ "something else" })), nil)
    eq((Blueprint.fromLines({ Blueprint.HEADER, "{area={}}" })), nil)
    eq((Blueprint.fromLines({ Blueprint.HEADER, "{area={x1=0,y1=0,x2=1,y2=1,z1=0,z2=0}}", "junk" })), nil)
end)
