local B = CSG_Builds
local S = CSG_Selection

test("parseOutfitLines splits each build at the first colon only", function()
    local value = "gender=1;Jacket=Base.Jacket;alicesweaponsling:slingback=alice.Sling;tks:KnifeSheathBack=Base.Knife;"
    local builds = B.parseOutfitLines({ "VERSION=1", "Max Wolf:" .. value, "Other:gender=2;" })
    eq(builds["Max Wolf"], value, "modded body locations with colons survive")
    eq(builds["Other"], "gender=2;")
end)

test("parseOutfitLines ignores other versions, junk and missing headers", function()
    eq(B.parseOutfitLines({ "VERSION=2", "Old:gender=1;" })["Old"], nil, "other version")
    eq(B.parseOutfitLines({ "Old:gender=1;" })["Old"], nil, "no version header")
    local builds = B.parseOutfitLines({ "VERSION=1", "nocolon", "", ":empty name", "Ok:x" })
    eq(builds["nocolon"], nil)
    eq(builds[""], nil)
    eq(builds["Ok"], "x")
end)

test("gear per build round trips through one text file", function()
    local first = S.deserialize("attach\tBack\tBase.Crowbar\ncontainer\tBase.Bag_ALICEpack#1\tBase.Pop\t2\noption\tloaded\t0")
    local second = S.deserialize("hand\tprimary\tBase.Axe")
    local text = B.serializeGear({ ["Max Wolf"] = first, Other = second })
    local back = B.deserializeGear(text)
    eq(back["Max Wolf"].attachments.Back, "Base.Crowbar")
    eq(S.containerItems(back["Max Wolf"], "Base.Bag_ALICEpack#1")[1].count, 2)
    eq(back["Max Wolf"].options.loaded, false, "options travel with the build")
    eq(back.Other.hands.primary, "Base.Axe")
    eq(back.Other.options.loaded, true)
    eq(B.deserializeGear("").Other, nil)
    eq(B.deserializeGear(nil)["x"], nil)
end)

test("deserializeGear skips gear lines before any build header", function()
    local back = B.deserializeGear("hand\tprimary\tBase.Axe\nbuild\tA\nhand\tprimary\tBase.Crowbar")
    eq(back.A.hands.primary, "Base.Crowbar")
    local count = 0
    for _ in pairs(back) do count = count + 1 end
    eq(count, 1)
end)
