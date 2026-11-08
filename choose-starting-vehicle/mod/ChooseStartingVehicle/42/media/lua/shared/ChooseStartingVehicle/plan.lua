--- Turns a build and the sandbox settings into concrete spawn steps: the
--- part choices to install or remove, the condition, fuel and battery levels,
--- the tint, and which container gets the trunk and glove box items. Pure.
local Build = require("ChooseStartingVehicle/build")

local Plan = {}

-- Tint presets for vehicles whose paint comes from a hue/saturation/value
-- tint (most vanilla cars). Values are 0..1 like BaseVehicle:setColorHSV.
Plan.COLORS = {
    { key = "white", h = 0.0, s = 0.0, v = 0.95 },
    { key = "silver", h = 0.0, s = 0.0, v = 0.7 },
    { key = "gray", h = 0.0, s = 0.0, v = 0.45 },
    { key = "black", h = 0.0, s = 0.0, v = 0.12 },
    { key = "red", h = 0.0, s = 0.85, v = 0.7 },
    { key = "maroon", h = 0.98, s = 0.8, v = 0.35 },
    { key = "orange", h = 0.07, s = 0.9, v = 0.85 },
    { key = "yellow", h = 0.14, s = 0.85, v = 0.9 },
    { key = "green", h = 0.33, s = 0.7, v = 0.55 },
    { key = "darkgreen", h = 0.36, s = 0.7, v = 0.28 },
    { key = "blue", h = 0.6, s = 0.8, v = 0.7 },
    { key = "navy", h = 0.63, s = 0.8, v = 0.3 },
    { key = "brown", h = 0.07, s = 0.6, v = 0.35 },
    { key = "beige", h = 0.11, s = 0.3, v = 0.8 },
}

--- Returns the tint preset with this key, or nil.
function Plan.color(key)
    for _, color in ipairs(Plan.COLORS) do
        if color.key == key then
            return color
        end
    end
    return nil
end

--- Returns the install steps for a section's part choices, sorted by part id:
--- {id, itemType} to install, or {id, remove = true} for "none".
function Plan.partSteps(parts)
    local ids = {}
    for id in pairs(parts or {}) do
        ids[#ids + 1] = id
    end
    table.sort(ids)
    local steps = {}
    for _, id in ipairs(ids) do
        local choice = parts[id]
        if choice == Build.NONE then
            steps[#steps + 1] = { id = id, remove = true }
        elseif choice then
            steps[#steps + 1] = { id = id, itemType = choice }
        end
    end
    return steps
end

--- True when a container id names trunk storage ("TruckBed", "DEF89Trunk").
function Plan.isTrunkId(id)
    return string.find(id or "", "Trunk", 1, true) ~= nil or string.find(id or "", "TruckBed", 1, true) ~= nil
end

--- Picks the container that counts as the trunk: the biggest trunk-named
--- container, else the biggest container that is not a seat, a wheel, the gas
--- tank or a glove box. `containers` holds {id, category, capacity, wheel, gloveBox}.
function Plan.pickTrunk(containers)
    local best, bestTrunk = nil, nil
    for _, c in ipairs(containers or {}) do
        local skip = c.wheel or c.gloveBox or c.category == "seat" or c.category == "gastank" or c.id == "GasTank"
        if not skip then
            if not best or (c.capacity or 0) > (best.capacity or 0) then
                best = c
            end
            if Plan.isTrunkId(c.id) and (not bestTrunk or (c.capacity or 0) > (bestTrunk.capacity or 0)) then
                bestTrunk = c
            end
        end
    end
    local pick = bestTrunk or best
    return pick and pick.id or nil
end

--- Picks the glove box: the "GloveBox" part, else any container marked as one.
function Plan.pickGloveBox(containers)
    local fallback = nil
    for _, c in ipairs(containers or {}) do
        if c.id == "GloveBox" then
            return c.id
        end
        if c.gloveBox and not fallback then
            fallback = c.id
        end
    end
    return fallback
end

--- True when a part id names a glove-box-like container (glove box, console).
function Plan.isGloveBoxId(id)
    return string.find(id or "", "GloveBox", 1, true) ~= nil or string.find(id or "", "Console", 1, true) ~= nil
end

--- Describes catalog parts' containers the way CSV_Apply.containers does for
--- a spawned vehicle, so the window can tell which part gets the trunk items.
function Plan.containersOf(parts)
    local list = {}
    for _, part in ipairs(parts or {}) do
        if part.container then
            list[#list + 1] = {
                id = part.id,
                category = part.category,
                capacity = part.capacity or 0,
                wheel = part.wheel == true,
                gloveBox = Plan.isGloveBoxId(part.id),
            }
        end
    end
    return list
end

--- Returns which part ids hold the trunk and glove box cargo for catalog parts.
function Plan.cargoParts(parts)
    local containers = Plan.containersOf(parts)
    return { trunk = Plan.pickTrunk(containers), glovebox = Plan.pickGloveBox(containers) }
end

--- Builds a section plan (vehicle or trailer) from a build section.
local function sectionPlan(section, settings)
    return {
        vehicle = section.vehicle,
        skin = section.skin,
        color = section.color and Plan.color(section.color) or nil,
        steps = Plan.partSteps(section.parts),
    }
end

--- Builds the full spawn plan, honoring the sandbox switches for trailers and
--- cargo. Returns nil when there is nothing to spawn.
function Plan.fromBuild(build, settings)
    if Build.isEmpty(build) or not settings.enabled then
        return nil
    end
    local plan = sectionPlan(build, settings)
    plan.condition = settings.partCondition
    plan.fuel = settings.fuelPercent / 100
    plan.battery = settings.batteryPercent / 100
    plan.keyInPocket = settings.keyInPocket
    plan.trunk = settings.allowCargo and build.trunk or {}
    plan.glovebox = settings.allowCargo and build.glovebox or {}
    if settings.allowTrailer and build.trailer and build.trailer.vehicle then
        plan.trailer = sectionPlan(build.trailer, settings)
        plan.trailer.cargo = settings.allowCargo and build.trailer.cargo or {}
    end
    return plan
end

--- Turns a script name into the full type addVehicleDebug wants ("Base.X").
function Plan.fullType(name)
    if string.find(name or "", ".", 1, true) then
        return name
    end
    return "Base." .. tostring(name)
end

return Plan
