local Catalog = require("ChooseStartingVehicle/catalog")
package.path = TEST_ROOT .. "/test/harness/?.lua;" .. package.path
local Resolver = require("script-resolver")

--- Builds a resolved-parts state from a list of part records.
local function resolved(parts)
    local state = { order = {}, byId = {} }
    for _, part in ipairs(parts) do
        part.specificItem = part.specificItem == true
        state.order[#state.order + 1] = part.id
        state.byId[part.id] = part
    end
    return state
end

local LABELS = {
    TireFrontLeft = "Front Left Tire", TireFrontRight = "Front Right Tire",
    TireRearLeft = "Rear Left Tire", TireRearRight = "Rear Right Tire",
    DAMNFrontLeftArmor = "Front Left Window Armor", DAMNFrontRightArmor = "Front Right Window Armor",
    DAMNBumperFront = "Front Bumper", Battery = "Battery",
}

local lookups = {
    itemLabel = function(t)
        if t == "Base.Missing" then return nil end
        return "L:" .. t
    end,
    partLabel = function(id) return LABELS[id] or id end,
}

test("idWords splits camel case, acronyms and digits", function()
    listEq(Catalog.idWords("DAMNFrontLeftArmor"), { "DAMN", "Front", "Left", "Armor" }, "acronym")
    listEq(Catalog.idWords("DEF89Roofrack"), { "DEF", "89", "Roofrack" }, "digits")
    listEq(Catalog.idWords("TireFrontLeft"), { "Tire", "Front", "Left" }, "plain")
end)

test("stem removes position words", function()
    eq(Catalog.stem("TireFrontLeft"), "Tire", "tire")
    eq(Catalog.stem("DAMNFrontLeftArmor"), "DAMNArmor", "armor")
    eq(Catalog.stem("DAMNBumperFront"), "DAMNBumper", "bumper")
    eq(Catalog.stem("Front"), "Front", "nothing left keeps the id")
end)

test("buildSlots merges same-option parts and keeps the common label", function()
    local tires = "Base.T1;Base.T2"
    local state = resolved({
        { id = "TireFrontLeft", itemTypes = { "Base.T1", "Base.T2" }, wheel = "FrontLeft" },
        { id = "TireFrontRight", itemTypes = { "Base.T1", "Base.T2" }, wheel = "FrontRight" },
        { id = "TireRearLeft", itemTypes = { "Base.T1", "Base.T2" }, wheel = "RearLeft" },
        { id = "TireRearRight", itemTypes = { "Base.T1", "Base.T2" }, wheel = "RearRight" },
    })
    local slots = Catalog.buildSlots(state, 2, lookups, Resolver.installableTypes)
    eq(#slots, 1, "one slot " .. tires)
    eq(slots[1].label, "Tire", "label")
    eq(#slots[1].partIds, 4, "four parts")
    eq(slots[1].allowNone, false, "tires are structural")
end)

test("buildSlots offers None for add-ons, even with a single item", function()
    local state = resolved({
        { id = "DAMNFrontLeftArmor", itemTypes = { "Base.Armor" }, category = "bodywork" },
        { id = "DAMNFrontRightArmor", itemTypes = { "Base.Armor" }, category = "bodywork" },
    })
    local slots = Catalog.buildSlots(state, 2, lookups, Resolver.installableTypes)
    eq(#slots, 1, "merged")
    eq(slots[1].label, "Front Window Armor", "common words")
    eq(slots[1].allowNone, true, "add-on")
end)

test("buildSlots hides single-option structural parts, nodisplay parts and missing items", function()
    local state = resolved({
        { id = "Battery", itemTypes = { "Base.CarBattery" }, specificItem = true },
        { id = "DEF89Vents", itemTypes = { "Base.Wrench" }, category = "nodisplay" },
        { id = "TruckBed", itemTypes = { "nil" }, specificItem = true },
        { id = "DAMNBumperFront", itemTypes = { "Base.Missing" } },
    })
    eq(#Catalog.buildSlots(state, 2, lookups, Resolver.installableTypes), 0, "nothing to choose")
end)

test("buildSlots keeps structural parts with real alternatives, without None", function()
    local state = resolved({ { id = "GasTank", itemTypes = { "Base.SmallGasTank", "Base.BigGasTank" }, specificItem = true } })
    local slots = Catalog.buildSlots(state, 3, lookups, Resolver.installableTypes)
    eq(#slots, 1, "slot")
    eq(slots[1].options[2].itemType, "Base.BigGasTank3", "mechanic suffix")
    eq(slots[1].allowNone, false, "no None")
end)

test("commonLabel falls back to the first label when nothing is shared", function()
    eq(Catalog.commonLabel({ "Alpha", "Beta" }), "Alpha", "fallback")
    eq(Catalog.commonLabel({}), "", "empty")
end)

test("skinLabel names KI5 shells and rejects useless names", function()
    eq(Catalog.skinLabel("Vehicles/Vehicles_84jeepXJ4_Shell_chestnutBrown"), "Chestnut Brown", "camel")
    eq(Catalog.skinLabel("Vehicles/Trailers_KI5cargo_Shell_ustoreit"), "Ustoreit", "lower")
    eq(Catalog.skinLabel("Vehicles/vehicle_pickupshell"), "Pickupshell", "vanilla last token")
    eq(Catalog.skinLabel("Vehicles/Vehicle_Car_01"), nil, "digits")
    eq(Catalog.skinLabel(nil), nil, "nil")
end)

test("skinLabels numbers repeats and falls back when counts differ", function()
    listEq(Catalog.skinLabels({ "V/A_Shell_gray", "V/A_Shell_gray" }, 2), { "Gray", "Gray 2" }, "repeat")
    listEq(Catalog.skinLabels({}, 2, "Paint"), { "Paint 1", "Paint 2" }, "fallback")
end)

test("source tells KI5, game and other mods apart", function()
    eq(Catalog.source("89defender", { "DEF89Tires", "DAMNglobal" }), Catalog.SOURCE_KI5, "ki5")
    eq(Catalog.source("pz-vanilla", {}), Catalog.SOURCE_GAME, "vanilla")
    eq(Catalog.source(nil, {}), Catalog.SOURCE_GAME, "no mod id")
    eq(Catalog.source("DashRoamerB42", {}), Catalog.SOURCE_MOD, "mod")
end)

test("trailer and wreck names", function()
    ok(Catalog.isTrailerName("TrailerKI5cargoSmall"), "trailer")
    ok(not Catalog.isTrailerName("89defender110"), "not trailer")
    ok(Catalog.isWreckName("CarNormalBurnt"), "burnt")
    ok(Catalog.isWreckName("SUVSmashedFront"), "smashed")
end)

test("sortEntries orders by source then name; filter splits trailers", function()
    local entries = Catalog.sortEntries({
        { name = "Base.B", displayName = "Bravo", source = Catalog.SOURCE_GAME, isTrailer = false },
        { name = "Base.T", displayName = "Trailer", source = Catalog.SOURCE_KI5, isTrailer = true },
        { name = "Base.A", displayName = "alpha", source = Catalog.SOURCE_KI5, isTrailer = false },
        { name = "Base.M", displayName = "Mod car", source = Catalog.SOURCE_MOD, isTrailer = false },
    })
    eq(entries[1].name, "Base.A", "ki5 first")
    eq(entries[4].name, "Base.M", "mods last")
    eq(#Catalog.filter(entries, "all", false), 3, "vehicles")
    eq(#Catalog.filter(entries, "all", true), 1, "trailers")
    eq(#Catalog.filter(entries, Catalog.SOURCE_GAME, false), 1, "game only")
end)

test("slotForPart finds the slot that controls a part", function()
    local entry = { slots = { { partIds = { "A", "B" } } } }
    eq(Catalog.slotForPart(entry, "B"), entry.slots[1], "found")
    eq(Catalog.slotForPart(entry, "C"), nil, "missing")
end)

test("trunk and console storage parts are structural, roof racks are add-ons", function()
    ok(Catalog.isStructural({ id = "DEF89Trunk", container = true }), "KI5 trunk")
    ok(Catalog.isStructural({ id = "KI5TRCSTrunk", container = true }), "trailer trunk")
    ok(Catalog.isStructural({ id = "DEF89CenterConsole", container = true }), "console")
    ok(not Catalog.isStructural({ id = "DEF89Roofrack", container = true }), "roof rack")
end)

test("displayParts keeps vehicle order, drops nodisplay parts and links slots", function()
    local state = resolved({
        { id = "Engine", category = "engine" },
        { id = "DAMNSnorkel", itemTypes = { "Base.Snorkel" }, category = "bodywork" },
        { id = "Vents", category = "nodisplay" },
    })
    local slots = Catalog.buildSlots(state, 2, lookups, Resolver.installableTypes)
    local parts = Catalog.displayParts(state, slots, lookups)
    eq(#parts, 2, "nodisplay dropped")
    eq(parts[1].id, "Engine", "order")
    eq(parts[1].slot, nil, "nothing to choose")
    eq(parts[2].slot.key, "DAMNSnorkel", "slot linked")
end)

test("mechanicsColumns puts doors, bodywork and lights on the right", function()
    local parts = {
        { id = "Engine", category = "engine" }, { id = "DoorFrontLeft", category = "door" },
        { id = "Battery", category = "engine" }, { id = "HeadlightLeft", category = "lights" },
        { id = "TireFrontLeft", category = "tire" },
    }
    local columns = Catalog.mechanicsColumns(parts)
    eq(#columns.left, 2, "engine and tire groups")
    eq(#columns.left[1].parts, 2, "engine parts grouped")
    eq(columns.right[1].category, "door", "doors first on the right")
    eq(columns.right[2].category, "lights", "lights")
end)
