--- Game glue: reads every clothing script item, asks the pure rules which
--- ones are face coverings, and raises their corpse sickness defense when a
--- world loads. Runs on client and server so both agree on the values.
---
--- The game stores the defense on the item type, but whether a gas mask has a
--- filter is stored on each item. So the filter masks are re-checked every
--- game minute: a type being worn with no filter drops back to its own value.
require "FaceCoveringProtection/face-covering"

local FaceCovering = FCP_FaceCovering
local Patch = {}

--- Defense each item had before this mod touched it, keyed by full type.
Patch.originals = {}

--- Face coverings found when the world loaded, or nil before that.
Patch.tracked = nil

--- Reads the minimum defense from the sandbox settings of the loaded world.
function Patch.readMinimum()
    local vars = SandboxVars and SandboxVars.FaceCoveringProtection
    return FaceCovering.clampMinimum(vars and vars.MinimumDefense)
end

--- Tells whether a script item is a gas mask or respirator that takes filters.
function Patch.takesFilter(script)
    return script:hasTag(ItemTag.GAS_MASK) or script:hasTag(ItemTag.RESPIRATOR) or script:hasTag(ItemTag.IMPROVISED_GAS_MASK)
end

--- Collects the facts the rules need from one clothing script item.
function Patch.describe(script)
    local fullType = script:getFullName()
    local current = script:getCorpseSicknessDefense()
    if Patch.originals[fullType] == nil then
        Patch.originals[fullType] = current
    end
    local location = script:getBodyLocation()
    return {
        fullType = fullType,
        name = script:getName(),
        bodyLocation = location and location:toString() or "",
        fabric = script:getFabricType(),
        takesFilter = Patch.takesFilter(script),
        defense = Patch.originals[fullType],
        current = current,
        script = script,
    }
end

--- Describes every clothing item known to the game, vanilla and modded.
function Patch.collect()
    local infos = {}
    local scripts = getScriptManager():getAllItems()
    for i = 0, scripts:size() - 1 do
        local script = scripts:get(i)
        if script:isItemType(ItemType.CLOTHING) then
            table.insert(infos, Patch.describe(script))
        end
    end
    return infos
end

--- Lists the players whose worn items matter on this machine.
function Patch.players()
    local players = {}
    if isServer() then
        local online = getOnlinePlayers()
        for i = 0, online:size() - 1 do
            table.insert(players, online:get(i))
        end
    else
        for i = 0, getNumActivePlayers() - 1 do
            local player = getSpecificPlayer(i)
            if player then
                table.insert(players, player)
            end
        end
    end
    return players
end

--- Returns the set of item types some player is wearing with no filter in.
function Patch.wornWithoutFilter()
    local unfiltered = {}
    for _, player in ipairs(Patch.players()) do
        local worn = player:getWornItems()
        for i = 0, worn:size() - 1 do
            local item = worn:getItemByIndex(i)
            if item and instanceof(item, "Clothing") and not item:hasFilter() then
                unfiltered[item:getFullType()] = true
            end
        end
    end
    return unfiltered
end

--- Brings the tracked script items in line with the rules and returns how
--- many values were changed.
function Patch.sync()
    if not Patch.tracked then
        return 0
    end
    for _, info in ipairs(Patch.tracked) do
        info.current = info.script:getCorpseSicknessDefense()
    end
    local patches = FaceCovering.planPatches(Patch.tracked, Patch.readMinimum(), Patch.wornWithoutFilter())
    for _, patch in ipairs(patches) do
        local script = getScriptManager():getItem(patch.fullType)
        if script then
            script:DoParam("CorpseSicknessDefense = " .. tostring(patch.defense))
        end
    end
    return #patches
end

--- Finds the face coverings for the loaded world and applies the minimum.
function Patch.apply()
    Patch.tracked = FaceCovering.onlyCoverings(Patch.collect())
    local changed = Patch.sync()
    print("[FaceCoveringProtection] tracking " .. #Patch.tracked .. " face coverings, set " .. changed .. " to at least " .. Patch.readMinimum() .. "% corpse sickness defense")
    return changed
end

Events.OnInitGlobalModData.Add(Patch.apply)
Events.EveryOneMinute.Add(Patch.sync)
Events.OnClothingUpdated.Add(Patch.sync)

FCP_Patch = Patch
return Patch
