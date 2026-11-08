--- Fidelity tests against the KI5 and game scripts installed on this machine.
--- Skipped where the game and mods are not installed.
package.path = TEST_ROOT .. "/test/harness/?.lua;" .. package.path
local RealScripts = require("real-scripts")
local Resolver = require("script-resolver")
local ScriptText = require("ChooseStartingVehicle/script-text")
local VehicleParts = require("ChooseStartingVehicle/vehicle-parts")
local Catalog = require("ChooseStartingVehicle/catalog")

local real = RealScripts.load()
if not real or not real.vehicles["89defender110"] then
    skip("KI5 script fidelity", "KI5 '89 Defender is not installed here")
    return
end

local lookups = {
    itemLabel = function(t) return t end,
    partLabel = function(id) return id end,
}

--- Builds a catalog entry the way runtime.lua does, from real blocks.
local function entryFor(name)
    local blocks = real.vehicles[name]
    local resolved = Resolver.resolve(blocks, function(n) return real.templates[n] end)
    local mechanicType = tonumber(ScriptText.property(blocks[1], "mechanicType") or "")
    return {
        resolved = resolved,
        skins = Catalog.skinLabels(VehicleParts.skinTextures(blocks), #VehicleParts.skinTextures(blocks)),
        slots = Catalog.buildSlots(resolved, mechanicType, lookups, Resolver.installableTypes),
        source = Catalog.source(real.modOf[name], VehicleParts.templateNames(blocks)),
    }
end

--- Returns the slot that controls a part id.
local function slot(entry, partId)
    return Catalog.slotForPart(entry, partId)
end

test("Defender 110: bumpers, snorkel and armor are add-on slots with None", function()
    local e = entryFor("89defender110")
    local bumper = slot(e, "DAMNBumperFront")
    ok(bumper, "front bumper slot")
    eq(bumper.allowNone, true, "None allowed")
    eq(bumper.options[1].itemType, "Base.89defenderBumperFront0", "bumper")
    eq(bumper.options[2].itemType, "Base.89defenderBullbarFrontA", "bullbar")
    ok(slot(e, "DAMNSnorkel"), "snorkel")
    local armor = slot(e, "DAMNFrontLeftArmor")
    ok(armor, "armor")
    listEq(armor.partIds, { "DAMNFrontLeftArmor", "DAMNFrontRightArmor" }, "left and right armor merged")
end)

test("Defender 110: four tires merge into one slot without None", function()
    local tires = slot(entryFor("89defender110"), "TireFrontLeft")
    eq(#tires.partIds, 4, "four wheels")
    eq(#tires.options, 4, "four tire types")
    eq(tires.allowNone, false, "structural")
end)

test("Defender 110: brakes get the mechanic suffix; vents, trunk and console stay hidden", function()
    local e = entryFor("89defender110")
    eq(slot(e, "DEF89Trunk"), nil, "trunk storage")
    eq(slot(e, "DEF89CenterConsole"), nil, "console")
    ok(slot(e, "DEF89Roofrack").allowNone, "roof rack is an add-on")
    eq(slot(e, "BrakeFrontLeft").options[1].itemType, "Base.OldBrake2", "suffix")
    eq(slot(e, "DEF89Vents"), nil, "nodisplay")
    eq(slot(e, "Battery"), nil, "single structural item")
end)

test("Defender 110: eleven factory paints with readable names", function()
    local skins = entryFor("89defender110").skins
    eq(#skins, 11, "count")
    eq(skins[1], "Arizona Tan", "first")
end)

-- Templates some installed KI5 vehicles reference that no file the game loads
-- defines (the game skips them too). See known-issues.md.
local KNOWN_UNDEFINED = { BR89SpareTiresPD = true, F1502SpareTires = true, F1502Roofrack = true, F3502Roofrack = true,
    SUB87Gunrack = true, KI5CRStabilizerB16 = true, DAMN79camaroGhost = true }

test("every KI5 vehicle resolves all of its templates and is tagged KI5", function()
    local missing, ki5 = {}, 0
    for _, name in ipairs(real.order) do
        local blocks = real.vehicles[name]
        local names = VehicleParts.templateNames(blocks)
        if Catalog.source(real.modOf[name], names) == Catalog.SOURCE_KI5 then
            ki5 = ki5 + 1
            local resolved = Resolver.resolve(blocks, function(n) return real.templates[n] end)
            for _, t in ipairs(resolved.missingTemplates) do
                if not KNOWN_UNDEFINED[t] then
                    missing[#missing + 1] = name .. ":" .. t
                end
            end
        end
    end
    ok(ki5 >= 50, "found " .. ki5 .. " KI5 vehicles")
    eq(#missing, 0, "missing templates " .. table.concat(missing, ", "))
end)

test("every KI5 vehicle offers at least one add-on slot", function()
    local bare = {}
    for _, name in ipairs(real.order) do
        local e = entryFor(name)
        if e.source == Catalog.SOURCE_KI5 and not Catalog.isTrailerName(name) then
            local addOns = 0
            for _, s in ipairs(e.slots) do
                if s.allowNone then
                    addOns = addOns + 1
                end
            end
            if addOns == 0 then
                bare[#bare + 1] = name
            end
        end
    end
    eq(#bare, 0, "no add-ons on " .. table.concat(bare, ", "))
end)

test("KI5 trailers have a tongue hitch and KI5 vehicles a rear one", function()
    local function hasAttachment(name, id)
        for _, block in ipairs(real.vehicles[name]) do
            for _, a in ipairs(ScriptText.childBlocks(block, "attachment")) do
                if a.name == id then
                    return true
                end
            end
        end
        return false
    end
    eq(hasAttachment("TrailerKI5cargoSmall", "trailer"), true, "trailer tongue")
    eq(hasAttachment("89defender110", "trailer"), true, "vehicle rear hitch")
end)

test("vanilla cars come out as game vehicles with tire and brake choices", function()
    if not real.vehicles.CarNormal then
        skip("vanilla CarNormal", "game scripts not found")
        return
    end
    local e = entryFor("CarNormal")
    eq(e.source, Catalog.SOURCE_GAME, "source")
    ok(slot(e, "TireFrontLeft"), "tires")
    ok(slot(e, "BrakeFrontLeft"), "brakes")
end)

test("KI5 part models line up with their items for the preview (95% or better)", function()
    local PartModels = require("ChooseStartingVehicle/part-models")
    local maps = {}
    local pipe = io.popen("grep -rl 'itemToModel' '" .. RealScripts.WORKSHOP .. "' --include=*.lua 2>/dev/null")
    for file in pipe:lines() do
        local handle = io.open(file)
        local text = handle and handle:read("*a") or ""
        if handle then handle:close() end
        for partId, body in string.gmatch(text, 'partId%s*=%s*"([^"]+)"%s*,%s*itemToModel%s*=%s*(%b{})') do
            local map = {}
            for item, model in string.gmatch(body, '%["([^"]+)"%]%s*=%s*"([^"]+)"') do
                map[item] = model
            end
            maps[partId] = maps[partId] or {}
            table.insert(maps[partId], map)
        end
    end
    pipe:close()
    local checked, right = 0, 0
    for _, name in ipairs(real.order) do
        local r = Resolver.resolve(real.vehicles[name], function(n) return real.templates[n] end)
        for _, id in ipairs(r.order) do
            local part = r.byId[id]
            if maps[id] and part.models and #part.itemTypes > 0 then
                local own = {}
                for _, m in ipairs(part.models) do own[m.id] = true end
                for _, map in ipairs(maps[id]) do
                    local all = true
                    for _, t in ipairs(part.itemTypes) do
                        if not (map[t] and own[map[t]]) then all = false end
                    end
                    if all then
                        for _, t in ipairs(part.itemTypes) do
                            checked = checked + 1
                            local shown = PartModels.forItem(part, t)
                            if #shown == 1 and shown[1].id == map[t] then
                                right = right + 1
                            end
                        end
                        break
                    end
                end
            end
        end
    end
    ok(checked > 500, "checked " .. checked .. " items")
    ok(right / checked >= 0.95, right .. " of " .. checked .. " items show the right model")
end)
