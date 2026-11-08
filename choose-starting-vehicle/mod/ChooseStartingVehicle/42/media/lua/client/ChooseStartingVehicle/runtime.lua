--- Reads the game's vehicle scripts into catalog entries. The vehicle list is
--- cheap (names, labels, source). The first time a vehicle is selected, its
--- parts are read from a scratch vehicle object the engine builds from the
--- script (templates keep no text at runtime, ADR 0006) and cached.
local ScriptText = require("ChooseStartingVehicle/script-text")
local VehicleParts = require("ChooseStartingVehicle/vehicle-parts")
local Catalog = require("ChooseStartingVehicle/catalog")
local PreviewSlot = require("ChooseStartingVehicle/preview-slot")

CSV_Runtime = CSV_Runtime or {}

local entryCache = {}
local listCache = nil

--- Returns the [modId, body] pairs the game kept for a script object.
function CSV_Runtime.scriptBodies(script)
    local pairsList = {}
    local bodies = script and script:getLoadedScriptBodies()
    if not bodies then
        return pairsList
    end
    for i = 0, bodies:size() - 2, 2 do
        pairsList[#pairsList + 1] = { modId = bodies:get(i), body = bodies:get(i + 1) }
    end
    return pairsList
end

--- Returns a translated string or nil when the key has no translation.
local function textOrNil(key)
    local text = getTextOrNull(key)
    if text == nil or text == key then
        return nil
    end
    return text
end

--- Returns a vehicle's display name.
function CSV_Runtime.vehicleLabel(script)
    return textOrNil("IGUI_VehicleName" .. script:getName()) or script:getName()
end

--- Returns a part's display name, falling back to its id split into words.
function CSV_Runtime.partLabel(id)
    return textOrNil("IGUI_VehiclePart" .. id) or table.concat(Catalog.idWords(id), " ")
end

--- Returns a part category's heading, as the mechanics window names it.
function CSV_Runtime.categoryLabel(category)
    return textOrNil("IGUI_VehiclePartCat" .. tostring(category)) or Catalog.titleCase(tostring(category))
end

--- Returns an item's display name, or nil when the item does not exist.
function CSV_Runtime.itemLabel(fullType)
    local item = getScriptManager():FindItem(fullType)
    if not item then
        return nil
    end
    return item:getDisplayName()
end

--- True when an item type exists.
function CSV_Runtime.itemExists(fullType)
    return getScriptManager():FindItem(fullType) ~= nil
end

--- Returns the source (KI5, game, other mod) of a vehicle from its stored text.
local function sourceOf(bodies)
    local modId = bodies[1] and bodies[1].modId or nil
    for _, pair in ipairs(bodies) do
        if string.find(pair.body, "DAMN", 1, true) then
            return Catalog.SOURCE_KI5
        end
    end
    return Catalog.source(modId, {})
end

--- Returns the cheap list of every offerable vehicle and trailer, sorted.
function CSV_Runtime.list()
    if listCache then
        return listCache
    end
    local entries = {}
    local scripts = getScriptManager():getAllVehicleScripts()
    for i = 0, scripts:size() - 1 do
        local script = scripts:get(i)
        local name = script:getName()
        if not script:isDebugOnly() and not Catalog.isWreckName(name) and script:getPartCount() > 0
            and script:getFullName() ~= PreviewSlot.FULL_NAME then
            local bodies = CSV_Runtime.scriptBodies(script)
            entries[#entries + 1] = {
                name = script:getFullName(),
                shortName = name,
                displayName = CSV_Runtime.vehicleLabel(script),
                source = sourceOf(bodies),
                isTrailer = Catalog.isTrailerName(name),
                skinCount = script:getSkinCount(),
            }
        end
    end
    listCache = Catalog.sortEntries(entries)
    return listCache
end

--- Builds a scratch vehicle from a script (never added to the world) and
--- reads its parts, or returns nil and the error when the engine refuses.
function CSV_Runtime.probe(fullName)
    local ok, result = pcall(function()
        local vehicle = BaseVehicle.new(nil)
        vehicle:setScriptName(fullName)
        vehicle:setScript()
        return VehicleParts.fromVehicle(vehicle)
    end)
    if not ok then
        return nil, result
    end
    return result
end

--- Returns the parsed vehicle blocks of a script's stored text.
local function vehicleBlocks(script)
    local blocks = {}
    for _, pair in ipairs(CSV_Runtime.scriptBodies(script)) do
        local block = ScriptText.findBlock(ScriptText.parse(pair.body), "vehicle")
        if block then
            blocks[#blocks + 1] = block
        end
    end
    return blocks
end

--- Returns the full entry (paints, parts in mechanics order and part slots) for a vehicle, or nil.
function CSV_Runtime.entry(fullName)
    if not fullName then
        return nil
    end
    local cached = entryCache[fullName]
    if cached then
        return cached
    end
    local base = Catalog.find(CSV_Runtime.list(), fullName)
    local script = getScriptManager():getVehicle(fullName)
    if not base or not script then
        return nil
    end
    local resolved, err = CSV_Runtime.probe(fullName)
    if not resolved then
        print("[ChooseStartingVehicle] could not read the parts of " .. fullName .. ": " .. tostring(err))
        resolved = { order = {}, byId = {} }
    end
    local blocks = vehicleBlocks(script)
    local lookups = { itemLabel = CSV_Runtime.itemLabel, partLabel = CSV_Runtime.partLabel }
    local entry = {}
    for key, value in pairs(base) do
        entry[key] = value
    end
    entry.skinTextures = VehicleParts.skinTextures(blocks)
    entry.skins = Catalog.skinLabels(entry.skinTextures, base.skinCount, getText("UI_CSV_Paint"))
    entry.slots = Catalog.buildSlots(resolved, script:getMechanicType(), lookups, VehicleParts.itemTypes)
    entry.parts = Catalog.displayParts(resolved, entry.slots, lookups)
    entry.overlay = script:getCarMechanicsOverlay() or fullName
    entry.mechanicType = script:getMechanicType()
    entryCache[fullName] = entry
    return entry
end

--- Looks up an entry for Build.sanitize: the full entry when it exists.
function CSV_Runtime.findEntry(fullName)
    return CSV_Runtime.entry(fullName)
end

--- Drops every cache (used after mods reload scripts).
function CSV_Runtime.reset()
    entryCache = {}
    listCache = nil
end
