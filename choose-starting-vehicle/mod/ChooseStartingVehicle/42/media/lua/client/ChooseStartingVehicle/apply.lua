--- Spawns the planned vehicle (and trailer) next to the player and makes it
--- match the build: parts, paint, condition, fuel, battery, keys and cargo.
--- Also marks every part as already decided for KI5's damnlib so it never
--- re-rolls the add-ons on a later load.
local Placement = require("ChooseStartingVehicle/placement")
local Plan = require("ChooseStartingVehicle/plan")

CSV_Apply = CSV_Apply or {}

local LOG = "[ChooseStartingVehicle] "

--- Calls a part's install or uninstall "complete" Lua hook, if it has one.
local function callComplete(tableName, vehicle, part, item)
    local t = part:getTable(tableName)
    if t and t.complete then
        local ok, err = pcall(VehicleUtils.callLua, t.complete, vehicle, part, item)
        if not ok then
            print(LOG .. tableName .. " hook failed for " .. part:getId() .. ": " .. tostring(err))
        end
    end
end

--- Installs an item type into a part, replacing whatever is there.
function CSV_Apply.install(vehicle, part, itemType)
    local old = part:getInventoryItem()
    if old and old:getFullType() == itemType then
        return true
    end
    local item = instanceItem(itemType)
    if not item then
        print(LOG .. "no item " .. tostring(itemType) .. " for " .. part:getId())
        return false
    end
    if old then
        part:setInventoryItem(nil)
        callComplete("uninstall", vehicle, part, old)
    end
    part:setInventoryItem(item, 10)
    callComplete("install", vehicle, part, nil)
    vehicle:transmitPartItem(part)
    return true
end

--- Empties a part slot.
function CSV_Apply.remove(vehicle, part)
    local old = part:getInventoryItem()
    if not old then
        return
    end
    part:setInventoryItem(nil)
    callComplete("uninstall", vehicle, part, old)
    vehicle:transmitPartItem(part)
end

--- Tells damnlib every slot has had its default chosen already.
function CSV_Apply.markDamnDefaults(vehicle)
    local modData = vehicle:getModData()
    for i = 0, vehicle:getPartCount() - 1 do
        modData["defaultPartSet_" .. vehicle:getPartByIndex(i):getId()] = "true"
    end
    modData.ChooseStartingVehicle = true
end

--- Applies the part steps of a section plan; returns how many failed.
function CSV_Apply.parts(vehicle, steps)
    local failed = 0
    for _, step in ipairs(steps or {}) do
        local part = vehicle:getPartById(step.id)
        if not part then
            failed = failed + 1
            print(LOG .. vehicle:getScriptName() .. " has no part " .. step.id)
        elseif step.remove then
            CSV_Apply.remove(vehicle, part)
        elseif not CSV_Apply.install(vehicle, part, step.itemType) then
            failed = failed + 1
        end
    end
    CSV_Apply.markDamnDefaults(vehicle)
    return failed
end

--- Sets every installed part's condition, fills tires with air, unlocks doors.
function CSV_Apply.condition(vehicle, condition)
    for i = 0, vehicle:getPartCount() - 1 do
        local part = vehicle:getPartByIndex(i)
        if part:getInventoryItem() then
            part:setCondition(condition)
            vehicle:transmitPartCondition(part)
            if part:getWheelIndex() >= 0 and part:getContainerCapacity() > 0 then
                part:setContainerContentAmount(part:getContainerCapacity())
            end
        end
        local door = part:getDoor()
        if door then
            door:setLocked(false)
            vehicle:transmitPartDoor(part)
        end
    end
    if condition >= 100 then
        vehicle:setRust(0)
        vehicle:transmitRust()
    end
    vehicle:setTrunkLocked(false)
    vehicle:setAlarmed(false)
end

--- Sets the fuel and battery levels (fractions 0..1).
function CSV_Apply.levels(vehicle, fuel, battery)
    local tank = vehicle:getPartById("GasTank")
    if tank and tank:getInventoryItem() then
        tank:setContainerContentAmount(tank:getContainerCapacity() * fuel)
        vehicle:transmitPartModData(tank)
    end
    local cell = vehicle:getPartById("Battery")
    local item = cell and cell:getInventoryItem()
    if item and instanceof(item, "DrainableComboItem") then
        item:setUsedDelta(battery)
        vehicle:transmitPartUsedDelta(cell)
    end
end

--- Applies the paint (skin index) and tint of a section plan.
function CSV_Apply.paint(vehicle, section)
    if section.skin and section.skin >= 0 and section.skin < vehicle:getSkinCount() then
        vehicle:setSkinIndex(section.skin)
        vehicle:updateSkin()
    end
    if section.color then
        vehicle:setColorHSV(section.color.h, section.color.s, section.color.v)
        vehicle:transmitColorHSV()
    end
end

--- Describes a vehicle's item containers for Plan.pickTrunk / pickGloveBox.
function CSV_Apply.containers(vehicle)
    local list = {}
    for i = 0, vehicle:getPartCount() - 1 do
        local part = vehicle:getPartByIndex(i)
        local types = part:getItemType()
        local installed = part:getInventoryItem() ~= nil or not types or types:isEmpty()
        if part:getItemContainer() and installed then
            local id = part:getId()
            list[#list + 1] = {
                id = id,
                category = part:getCategory(),
                capacity = part:getContainerCapacity(),
                wheel = part:getWheelIndex() >= 0,
                gloveBox = Plan.isGloveBoxId(id),
            }
        end
    end
    return list
end

--- Puts stacks of items into a vehicle part's container.
function CSV_Apply.fill(vehicle, partId, stacks)
    if not partId or not stacks or #stacks == 0 then
        return
    end
    local part = vehicle:getPartById(partId)
    local container = part and part:getItemContainer()
    if not container then
        print(LOG .. "no container " .. tostring(partId) .. " on " .. vehicle:getScriptName())
        return
    end
    for _, stack in ipairs(stacks) do
        for _ = 1, stack.count do
            if not container:AddItem(stack.type) then
                print(LOG .. "could not add " .. stack.type)
                break
            end
        end
    end
end

--- Gives the player the key, in their pocket or the glove box; returns the
--- key and true when it went in the pocket.
function CSV_Apply.key(vehicle, player, inPocket, gloveBoxId)
    local key = vehicle:createVehicleKey()
    if not key then
        return nil, false
    end
    local gloveBox = gloveBoxId and vehicle:getPartById(gloveBoxId)
    local container = gloveBox and gloveBox:getItemContainer()
    if not inPocket and container then
        container:AddItem(key)
        return key, false
    end
    player:getInventory():AddItem(key)
    return key, true
end

--- Takes a key back from wherever it sits in the player's inventory, bags
--- included; a key the player dropped or stowed elsewhere is left alone.
function CSV_Apply.takeKey(player, key)
    if not key or not player:getInventory():containsRecursive(key) then
        return false
    end
    local container = key:getContainer()
    if not container then
        return false
    end
    container:Remove(key)
    return true
end

--- Permanently removes a spawn (trailer, car, and the pocket key) so it can
--- be spawned again somewhere else; marks the result so reapply skips it.
function CSV_Apply.removeSpawn(result, player)
    if result.trailer then
        result.trailer:permanentlyRemove()
    end
    if result.vehicle then
        result.vehicle:permanentlyRemove()
    end
    CSV_Apply.takeKey(player, result.key)
    result.removed = true
end

--- Returns the forward (z) position of an attachment in a vehicle script's
--- local space, the same way BaseVehicle:getAttachmentLocalPos computes it.
function CSV_Apply.attachmentZ(script, id)
    local attachment = script:getAttachmentById(id)
    if not attachment then
        return nil
    end
    local z = attachment:getOffset():z()
    local model = script:getModel()
    if model then
        z = z + model:getOffset():z()
    end
    return z
end

--- Returns the attachment a trailer is towed by. Trailers name their tongue
--- "trailer" (at the front), a few also have "trailerfront"; vanilla's tow menu
--- tries "trailer" first, so this does too.
function CSV_Apply.trailerHitchId(trailerScript)
    if trailerScript:getAttachmentById("trailer") then
        return "trailer"
    end
    if trailerScript:getAttachmentById("trailerfront") then
        return "trailerfront"
    end
    return nil
end

--- Returns the tile for the trailer: `offset` tiles straight behind the car's
--- actual position and heading (addVehicleDebug adds a little random yaw),
--- falling back to the planned tile.
function CSV_Apply.trailerTile(vehicle, offset, planned)
    local pos = vehicle:getWorldPos(0, 0, offset, Vector3f.new())
    if pos then
        return math.floor(pos:x()), math.floor(pos:y())
    end
    return planned.x, planned.y
end

--- Returns the placement body for a vehicle script.
local function bodyFor(script, offset)
    local extents = script:getExtents()
    return { offset = offset or 0, width = Placement.tilesFor(extents:x(), 1.0), length = Placement.tilesFor(extents:z(), 1.0) }
end

--- True when a square can hold part of a parked vehicle.
function CSV_Apply.isClear(x, y)
    local sq = getCell():getGridSquare(x, y, 0)
    if not sq or not sq:getFloor() then
        return false
    end
    if sq:getRoom() or sq:getBuilding() or sq:isSolid() or sq:isSolidTrans() or sq:HasTree() then
        return false
    end
    if sq:isWaterSquare() or sq:hasWater() or sq:getVehicleContainer() then
        return false
    end
    if sq:has(IsoFlagType.collideN) or sq:has(IsoFlagType.collideW) then
        return false
    end
    return sq:isFree(false)
end

--- True when a square is road or parking lot, where a car looks parked.
function CSV_Apply.isRoad(x, y)
    local sq = getCell():getGridSquare(x, y, 0)
    local floor = sq and sq:getFloor()
    local sprite = floor and floor:getSprite()
    local name = sprite and sprite:getName()
    return name ~= nil and string.find(name, "street", 1, true) ~= nil
end

--- Finds a spot and spawns one vehicle; returns it or nil.
local function spawnAt(fullType, dir, x, y)
    local sq = getCell():getGridSquare(x, y, 0)
    if not sq then
        return nil
    end
    return addVehicleDebug(fullType, IsoDirections[dir], nil, sq)
end

--- Makes a spawned vehicle match a section plan, plus the shared levels.
local function dress(vehicle, section, plan)
    CSV_Apply.paint(vehicle, section)
    local failed = CSV_Apply.parts(vehicle, section.steps)
    CSV_Apply.condition(vehicle, plan.condition)
    CSV_Apply.levels(vehicle, plan.fuel, plan.battery)
    vehicle:updatePartStats()
    vehicle:doDamageOverlay()
    return failed
end

--- Spawns the whole plan near the player. Returns {vehicle, trailer} or nil.
function CSV_Apply.spawn(player, plan, settings)
    local fullType = Plan.fullType(plan.vehicle)
    local script = getScriptManager():getVehicle(fullType)
    if not script then
        print(LOG .. "vehicle script " .. fullType .. " is not loaded")
        return nil
    end
    local bodies = { bodyFor(script, 0) }
    local trailerScript = nil
    local trailerHitchId = nil
    if plan.trailer then
        trailerScript = getScriptManager():getVehicle(Plan.fullType(plan.trailer.vehicle))
        if trailerScript then
            trailerHitchId = CSV_Apply.trailerHitchId(trailerScript)
            local carHitch = CSV_Apply.attachmentZ(script, "trailer")
            local trailerHitch = trailerHitchId and CSV_Apply.attachmentZ(trailerScript, trailerHitchId)
            local offset
            if carHitch and trailerHitch then
                offset = Placement.trailerOffset(carHitch, trailerHitch)
            else
                offset = -(script:getExtents():z() + trailerScript:getExtents():z()) / 2 - 1
            end
            bodies[2] = bodyFor(trailerScript, offset)
        end
    end
    local spot = Placement.findSpot({
        originX = math.floor(player:getX()),
        originY = math.floor(player:getY()),
        bodies = bodies,
        minRadius = 3,
        maxRadius = settings.searchRadius,
        isClear = CSV_Apply.isClear,
        isPreferred = CSV_Apply.isRoad,
    })
    if not spot then
        print(LOG .. "no free spot within " .. tostring(settings.searchRadius) .. " tiles for " .. fullType)
        return nil
    end
    local vehicle = spawnAt(fullType, spot.dir, spot.centers[1].x, spot.centers[1].y)
    if not vehicle then
        print(LOG .. "addVehicleDebug refused " .. fullType .. " at " .. spot.centers[1].x .. "," .. spot.centers[1].y)
        return nil
    end
    local failed = dress(vehicle, plan, plan)
    local containers = CSV_Apply.containers(vehicle)
    local gloveBoxId = Plan.pickGloveBox(containers)
    CSV_Apply.fill(vehicle, Plan.pickTrunk(containers), plan.trunk)
    CSV_Apply.fill(vehicle, gloveBoxId, plan.glovebox)
    local key, inPocket = CSV_Apply.key(vehicle, player, plan.keyInPocket, gloveBoxId)
    local result = { vehicle = vehicle, key = inPocket and key or nil, x = vehicle:getX(), y = vehicle:getY() }
    if trailerScript and spot.centers[2] then
        local tx, ty = CSV_Apply.trailerTile(vehicle, bodies[2].offset, spot.centers[2])
        local trailer = spawnAt(trailerScript:getFullName(), spot.dir, tx, ty)
        if trailer then
            trailer:setAngles(vehicle:getAngleX(), vehicle:getAngleY(), vehicle:getAngleZ())
            failed = failed + dress(trailer, plan.trailer, plan)
            CSV_Apply.fill(trailer, Plan.pickTrunk(CSV_Apply.containers(trailer)), plan.trailer.cargo)
            if not trailerHitchId or not vehicle:attachmentExist("trailer") or not trailer:attachmentExist(trailerHitchId) then
                print(LOG .. "left the trailer unhitched: no matching tow attachments")
            elseif not vehicle:canAttachTrailer(trailer, "trailer", trailerHitchId) then
                print(LOG .. "left the trailer unhitched: the hitches did not line up; use the tow menu")
            else
                vehicle:addPointConstraint(player, trailer, "trailer", trailerHitchId)
            end
            result.trailer = trailer
        else
            print(LOG .. "could not spawn trailer " .. trailerScript:getFullName())
        end
    end
    print(LOG .. "spawned " .. fullType .. " at " .. spot.centers[1].x .. "," .. spot.centers[1].y .. " facing " .. spot.dir
        .. (result.trailer and " with a trailer" or "") .. "; " .. tostring(failed) .. " part choices failed")
    return result
end

--- True when a vehicle's parts no longer match the steps.
function CSV_Apply.drifted(vehicle, steps)
    for _, step in ipairs(steps or {}) do
        local part = vehicle:getPartById(step.id)
        local item = part and part:getInventoryItem()
        if part and step.remove and item then
            return true
        end
        if part and step.itemType and (not item or item:getFullType() ~= step.itemType) then
            return true
        end
    end
    return false
end

--- Re-applies the part choices if anything changed them after spawning, then
--- the condition and levels so a swapped tire or tank is not left flat or empty.
--- Does nothing for a spawn that was removed to follow the player.
function CSV_Apply.reapply(result, plan)
    if result.removed then
        return
    end
    local sections = { { result.vehicle, plan.steps }, { result.trailer, plan.trailer and plan.trailer.steps } }
    for _, pair in ipairs(sections) do
        local vehicle, steps = pair[1], pair[2]
        if vehicle and steps and CSV_Apply.drifted(vehicle, steps) then
            print(LOG .. "parts changed after spawning; applying the build again")
            CSV_Apply.parts(vehicle, steps)
            CSV_Apply.condition(vehicle, plan.condition)
            CSV_Apply.levels(vehicle, plan.fuel, plan.battery)
            vehicle:doDamageOverlay()
        end
    end
end
