--- Pure helpers for turning raw item facts into a sorted, searchable catalog.
local Catalog = {}

--- Returns the module part of a full item type such as "Base.Axe".
function Catalog.moduleOf(fullType)
    return string.match(fullType or "", "^([^%.]+)%.") or ""
end

--- Sorts entries by display name, then by full type for a stable order.
function Catalog.sortByName(entries)
    table.sort(entries, function(a, b)
        local an = string.lower(a.displayName or "")
        local bn = string.lower(b.displayName or "")
        if an == bn then
            return (a.fullType or "") < (b.fullType or "")
        end
        return an < bn
    end)
    return entries
end

--- Returns true for item types that never belong in starting gear: hidden or
--- obsolete items and the furniture "moveables" that are items only on paper.
function Catalog.isExcluded(raw)
    if not raw.fullType or raw.hidden or raw.obsolete then
        return true
    end
    if Catalog.moduleOf(raw.fullType) == "Moveables" then
        return true
    end
    if string.find(raw.fullType, ".Mov_", 1, true) then
        return true
    end
    return false
end

--- Builds catalog entries from raw item facts, dropping excluded items and
--- tagging duplicate display names with their module.
function Catalog.buildEntries(rawItems)
    local entries = {}
    local nameCount = {}
    for _, raw in ipairs(rawItems) do
        if not Catalog.isExcluded(raw) then
            local name = raw.displayName or raw.fullType
            nameCount[name] = (nameCount[name] or 0) + 1
            table.insert(entries, {
                fullType = raw.fullType,
                displayName = name,
                attachmentType = raw.attachmentType,
                weight = raw.weight or 0,
                isContainer = raw.isContainer == true,
                capacity = raw.capacity or 0,
                twoHanded = raw.twoHanded == true,
                isWeapon = raw.isWeapon == true,
                category = raw.category or "Unknown",
                equipLocation = raw.equipLocation,
                icon = raw.icon,
                maxAmmo = raw.maxAmmo or 0,
                isFirearm = raw.isFirearm == true,
                partType = raw.partType,
                mountOn = raw.mountOn,
                partStats = raw.partStats,
            })
        end
    end
    for _, entry in ipairs(entries) do
        if nameCount[entry.displayName] > 1 then
            entry.label = entry.displayName .. " [" .. Catalog.moduleOf(entry.fullType) .. "]"
        else
            entry.label = entry.displayName
        end
    end
    return Catalog.sortByName(entries)
end

--- Returns true when the item is a firearm or a magazine that holds rounds.
function Catalog.holdsAmmo(entry)
    return (entry.maxAmmo or 0) > 0
end

--- Returns true when a weapon part fits a firearm type: its MountOn list
--- names the firearm, or the list is empty, which vanilla treats as "any".
function Catalog.partFits(entry, firearmType)
    local mountOn = entry.mountOn or {}
    if #mountOn == 0 then
        return true
    end
    for _, fullType in ipairs(mountOn) do
        if fullType == firearmType then
            return true
        end
    end
    return false
end

--- Returns the weapon parts that fit a firearm type, grouped as
--- { partType, entries } and sorted by part type.
function Catalog.partsFor(entries, firearmType)
    local byType = {}
    local order = {}
    for _, entry in ipairs(entries) do
        if entry.partType and entry.partType ~= "" and Catalog.partFits(entry, firearmType) then
            if not byType[entry.partType] then
                byType[entry.partType] = { partType = entry.partType, entries = {} }
                table.insert(order, entry.partType)
            end
            table.insert(byType[entry.partType].entries, entry)
        end
    end
    table.sort(order)
    local groups = {}
    for _, partType in ipairs(order) do
        table.insert(groups, byType[partType])
    end
    return groups
end

--- Returns the entries whose label or full type contains every word of the
--- query and, when a category is given, whose category matches it.
function Catalog.filter(entries, query, category)
    local words = {}
    for word in string.gmatch(string.lower(query or ""), "%S+") do
        table.insert(words, word)
    end
    if #words == 0 and not category then
        return entries
    end
    local matches = {}
    for _, entry in ipairs(entries) do
        local ok = category == nil or entry.category == category
        if ok and #words > 0 then
            local haystack = string.lower((entry.label or "") .. " " .. (entry.fullType or ""))
            for _, word in ipairs(words) do
                if not string.find(haystack, word, 1, true) then
                    ok = false
                    break
                end
            end
        end
        if ok then
            table.insert(matches, entry)
        end
    end
    return matches
end

--- Returns the sorted list of distinct categories in the entries.
function Catalog.categories(entries)
    local seen = {}
    local list = {}
    for _, entry in ipairs(entries) do
        local category = entry.category or "Unknown"
        if not seen[category] then
            seen[category] = true
            table.insert(list, category)
        end
    end
    table.sort(list)
    return list
end

--- Groups wearable containers by the body location they are worn on; returns
--- a list of { location, entries } sorted by location.
function Catalog.bagLocations(entries)
    local byLocation = {}
    local locations = {}
    for _, entry in ipairs(entries) do
        if entry.isContainer and entry.equipLocation then
            if not byLocation[entry.equipLocation] then
                byLocation[entry.equipLocation] = {}
                table.insert(locations, entry.equipLocation)
            end
            table.insert(byLocation[entry.equipLocation], entry)
        end
    end
    table.sort(locations)
    local groups = {}
    for _, location in ipairs(locations) do
        table.insert(groups, { location = location, entries = byLocation[location] })
    end
    return groups
end

--- Indexes entries by full type for constant-time lookup.
function Catalog.byFullType(entries)
    local map = {}
    for _, entry in ipairs(entries) do
        map[entry.fullType] = entry
    end
    return map
end

CSG_Catalog = Catalog
return Catalog
