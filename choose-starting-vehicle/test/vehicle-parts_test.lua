local ScriptText = require("ChooseStartingVehicle/script-text")
local VehicleParts = require("ChooseStartingVehicle/vehicle-parts")

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

test("skinTextures lists skins with a texture in order", function()
    local vehicle = setup("vehicle Car { skin { texture = V/A_Shell_red, } skin { } skin { texture = V/A_Shell_blue, } }")
    listEq(VehicleParts.skinTextures({ vehicle }), { "V/A_Shell_red", "V/A_Shell_blue" }, "skins")
end)

test("templateNames lists direct template references without part suffixes", function()
    local vehicle = setup("vehicle Car { template = DAMNglobal, template! = X, template = Door/part/DoorFrontLeft, }")
    listEq(VehicleParts.templateNames({ vehicle }), { "DAMNglobal", "X", "Door" }, "names")
end)


--- A Java-style ArrayList over a Lua list.
local function arrayList(list)
    return { size = function() return #list end, get = function(_, i) return list[i + 1] end }
end

--- A fake engine VehiclePart.
local function enginePart(def)
    return {
        getId = function() return def.id end,
        getItemType = function() return def.itemTypes and arrayList(def.itemTypes) or nil end,
        getCategory = function() return def.category end,
        getWheelIndex = function() return def.wheel or -1 end,
        getDoor = function() return def.door and {} or nil end,
        getWindow = function() return nil end,
        isContainer = function() return def.container == true end,
        getContainerCapacity = function() return def.capacity or 0 end,
        isSpecificItem = function() return true end,
        getScriptPart = function()
            local models = def.models or {}
            return {
                getModelCount = function() return #models end,
                getModel = function(_, i)
                    return { getId = function() return models[i + 1][1] end, getFile = function() return models[i + 1][2] end }
                end,
            }
        end,
    }
end

test("toList copies a Java list and treats nil as empty", function()
    listEq(VehicleParts.toList(arrayList({ "a", "b" })), { "a", "b" }, "list")
    eq(#VehicleParts.toList(nil), 0, "nil")
end)

test("fromVehicle reads ids, items, flags and models in part order", function()
    local parts = {
        enginePart({ id = "TireFrontLeft", wheel = 0, itemTypes = { "Base.OldTire2" }, category = "tire" }),
        enginePart({ id = "DoorFrontLeft", door = true, category = "door" }),
        enginePart({ id = "DAMNBumperFront", itemTypes = { "Base.A", "Base.B" }, models = { { "Stock", "S0" }, { "Bull", "B1" } } }),
        enginePart({ id = "SeatFrontLeft", container = true, capacity = 20 }),
    }
    local vehicle = { getPartCount = function() return #parts end, getPartByIndex = function(_, i) return parts[i + 1] end }
    local state = VehicleParts.fromVehicle(vehicle)
    listEq(state.order, { "TireFrontLeft", "DoorFrontLeft", "DAMNBumperFront", "SeatFrontLeft" }, "order")
    eq(state.byId.TireFrontLeft.wheel, true, "wheel")
    eq(state.byId.DoorFrontLeft.wheel, false, "not a wheel")
    eq(state.byId.DoorFrontLeft.door, true, "door")
    eq(#state.byId.DoorFrontLeft.itemTypes, 0, "no item list")
    listEq(state.byId.DAMNBumperFront.itemTypes, { "Base.A", "Base.B" }, "items")
    eq(state.byId.DAMNBumperFront.models[2].file, "B1", "model file")
    eq(state.byId.SeatFrontLeft.container, true, "container")
    eq(state.byId.SeatFrontLeft.capacity, 20, "capacity")
    eq(state.byId.DoorFrontLeft.capacity, 0, "not a container")
end)

test("itemTypes passes the engine's list through unchanged", function()
    listEq(VehicleParts.itemTypes({ itemTypes = { "Base.NormalTire2" } }), { "Base.NormalTire2" }, "kept")
    eq(#VehicleParts.itemTypes({}), 0, "none")
end)
