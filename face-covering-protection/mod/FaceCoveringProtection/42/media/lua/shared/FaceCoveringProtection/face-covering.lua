--- Pure rules for deciding which clothing items are face coverings and how
--- much corpse sickness defense they should have. No Project Zomboid globals
--- are used here so the module can be unit-tested outside the game.
local FaceCovering = {}

FaceCovering.DEFAULT_MINIMUM = 50

--- Kinds of face covering: cloth-like ones always get the minimum, filter
--- masks only while a filter (charged or spent) is fitted.
FaceCovering.CLOTH = "cloth"
FaceCovering.FILTER = "filter"

--- Body locations where an item sits over the mouth and nose.
FaceCovering.FACE_LOCATIONS = { mask = true, maskeyes = true, maskfull = true, fullhat = true }

--- Fabric types that mark an item as made of cloth.
FaceCovering.CLOTH_FABRICS = { cotton = true, denim = true }

--- Name fragments that mark an item in a face location as a cloth covering.
FaceCovering.CLOTH_KEYWORDS = { "balaclava", "bandana", "shemagh", "scarf", "gaiter", "headsack" }

--- Lowercases a body location id and drops the vanilla "base:" namespace.
function FaceCovering.normalizeLocation(location)
    local lowered = string.lower(location or "")
    return (string.gsub(lowered, "^base:", ""))
end

--- Tells whether an item name contains one of the cloth covering keywords.
function FaceCovering.hasClothKeyword(name)
    local lowered = string.lower(name or "")
    for _, keyword in ipairs(FaceCovering.CLOTH_KEYWORDS) do
        if string.find(lowered, keyword) then
            return true
        end
    end
    return false
end

--- Tells whether an item is made of cloth, by its fabric or by its name.
function FaceCovering.isCloth(info)
    local fabric = string.lower(info.fabric or "")
    return FaceCovering.CLOTH_FABRICS[fabric] == true or FaceCovering.hasClothKeyword(info.name)
end

--- Sorts an item into a kind of face covering, or nil when it is not one.
--- Gas masks and respirators are filter masks; anything that already protects
--- against corpse sickness, or is cloth worn over the face, is a cloth one.
function FaceCovering.classify(info)
    if info.takesFilter then
        return FaceCovering.FILTER
    end
    if (info.defense or 0) > 0 then
        return FaceCovering.CLOTH
    end
    local location = FaceCovering.normalizeLocation(info.bodyLocation)
    if FaceCovering.FACE_LOCATIONS[location] and FaceCovering.isCloth(info) then
        return FaceCovering.CLOTH
    end
    return nil
end

--- Turns a sandbox setting into a usable percentage between 0 and 100.
function FaceCovering.clampMinimum(value)
    if type(value) ~= "number" then
        return FaceCovering.DEFAULT_MINIMUM
    end
    return math.max(0, math.min(100, value))
end

--- Returns the defense an item should end up with: its own value, raised to
--- the minimum when it is a face covering. A filter mask that is being worn
--- with no filter in it keeps its own value.
function FaceCovering.targetDefense(info, minimum, wornWithoutFilter)
    local defense = info.defense or 0
    local kind = FaceCovering.classify(info)
    if kind == nil or (kind == FaceCovering.FILTER and wornWithoutFilter) then
        return defense
    end
    return math.max(defense, minimum)
end

--- Lists the items whose defense has to change, with the value to set.
--- `unfiltered` is the set of full types currently worn with no filter.
function FaceCovering.planPatches(infos, minimum, unfiltered)
    local patches = {}
    for _, info in ipairs(infos) do
        local target = FaceCovering.targetDefense(info, minimum, (unfiltered or {})[info.fullType] == true)
        if target ~= (info.current or info.defense or 0) then
            table.insert(patches, { fullType = info.fullType, defense = target })
        end
    end
    return patches
end

--- Keeps only the items that are face coverings of some kind.
function FaceCovering.onlyCoverings(infos)
    local coverings = {}
    for _, info in ipairs(infos) do
        if FaceCovering.classify(info) ~= nil then
            table.insert(coverings, info)
        end
    end
    return coverings
end

FCP_FaceCovering = FaceCovering
return FaceCovering
