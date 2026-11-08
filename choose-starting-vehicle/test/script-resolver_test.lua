local ScriptText = require("ChooseStartingVehicle/script-text")
package.path = TEST_ROOT .. "/test/harness/?.lua;" .. package.path
local Resolver = require("script-resolver")

--- Parses text holding templates and one vehicle; returns the vehicle block and a finder.
local function setup(text)
    local root = ScriptText.parse(text)
    local templates, vehicle = {}, nil
    local function walk(block)
        for _, item in ipairs(block.items) do
            if item.block then
                if item.block.kind == "template" then
                    templates[item.block.name] = item.block
                elseif item.block.kind == "vehicle" then
                    vehicle = item.block
                else
                    walk(item.block)
                end
            end
        end
    end
    walk(root)
    return vehicle, function(name) return templates[name] end
end

test("splitItemTypes trims and drops empties", function()
    listEq(Resolver.splitItemTypes(" Base.A ; Base.B;;"), { "Base.A", "Base.B" }, "types")
end)

test("templates apply in source order and later part blocks override", function()
    local vehicle, find = setup([[
template vehicle Tires { part TireFrontLeft { itemType = Base.OldTire, wheel = FrontLeft, } part TireFrontRight { itemType = Base.OldTire, } }
vehicle Car {
    template = Tires,
    part Tire* { itemType = Base.NormalTire;Base.ModernTire, }
}]])
    local state = Resolver.resolve({ vehicle }, find)
    listEq(state.order, { "TireFrontLeft", "TireFrontRight" }, "order")
    listEq(state.byId.TireFrontRight.itemTypes, { "Base.NormalTire", "Base.ModernTire" }, "wildcard override")
    eq(state.byId.TireFrontLeft.wheel, "FrontLeft", "wheel kept")
end)

test("a wildcard part block only changes parts defined before it", function()
    local vehicle, find = setup([[
vehicle Car {
    part Seat* { itemType = Base.Fancy, }
    part SeatFront { itemType = Base.Plain, }
}]])
    local state = Resolver.resolve({ vehicle }, find)
    listEq(state.byId.SeatFront.itemTypes, { "Base.Plain" }, "unaffected")
end)

test("template Name/part/Id copies only that part", function()
    local vehicle, find = setup([[
template vehicle Door { part DoorFrontLeft { itemType = Base.FrontDoor, door { } } part DoorRearLeft { itemType = Base.RearDoor, } }
vehicle Car { template = Door/part/DoorFrontLeft, }]])
    local state = Resolver.resolve({ vehicle }, find)
    listEq(state.order, { "DoorFrontLeft" }, "only one part")
    ok(state.byId.DoorFrontLeft.door, "door flag")
end)

test("nested templates resolve and missing ones are reported", function()
    local vehicle, find = setup([[
template vehicle Inner { part Snorkel { itemType = Base.Snorkel, specificItem = false, category = Other, } }
template vehicle Outer { template = Inner, }
vehicle Car { template = Outer, template = Ghost, }]])
    local state = Resolver.resolve({ vehicle }, find)
    eq(state.byId.Snorkel.category, "Other", "category")
    eq(state.byId.Snorkel.specificItem, false, "specificItem")
    listEq(state.missingTemplates, { "Ghost" }, "missing")
end)

test("installableTypes appends the mechanic type only to specific items", function()
    listEq(Resolver.installableTypes({ itemTypes = { "Base.NormalTire" }, specificItem = true }, 2), { "Base.NormalTire2" }, "specific")
    listEq(Resolver.installableTypes({ itemTypes = { "Base.Bullbar" }, specificItem = false }, 2), { "Base.Bullbar" }, "not specific")
end)

test("a later vehicle block (a mod override) is applied after the original", function()
    local original = setup("vehicle Car { part Muffler { itemType = Base.OldMuffler, } }")
    local override = setup("vehicle Car { part Muffler { itemType = Base.ModernMuffler, } }")
    local state = Resolver.resolve({ original, override }, function() return nil end)
    listEq(state.byId.Muffler.itemTypes, { "Base.ModernMuffler" }, "override wins")
end)

test("templateRef splits part, passenger and plain references", function()
    local name, kind, id = Resolver.templateRef("Door/part/DoorFrontLeft")
    eq(name .. "|" .. kind .. "|" .. id, "Door|part|DoorFrontLeft", "part")
    name, kind, id = Resolver.templateRef("PassengerSeat4/passenger/FrontLeft")
    eq(kind, "passenger", "passenger")
    name, kind = Resolver.templateRef(" Tires ")
    eq(name, "Tires", "plain")
    eq(kind, nil, "no kind")
end)

test("non-part template references are skipped, not reported missing", function()
    local vehicle = setup("vehicle Car { template = PassengerSeat4/passenger/FrontLeft, }")
    local state = Resolver.resolve({ vehicle }, function() return nil end)
    eq(#state.missingTemplates, 0, "not missing")
end)

test("resolver keeps part models in order and replaces a model with the same id", function()
    local vehicle, find = setup([[
template vehicle Bumpers { part DAMNBumperFront { itemType = Base.A;Base.B, model Stock { file = S0, } model Bull { file = B1, } } }
vehicle Car { template = Bumpers, part DAMNBumperFront { model Bull { file = B2, } } }]])
    local models = Resolver.resolve({ vehicle }, find).byId.DAMNBumperFront.models
    eq(#models, 2, "two models")
    eq(models[1].id, "Stock", "order")
    eq(models[2].file, "B2", "replaced")
end)
