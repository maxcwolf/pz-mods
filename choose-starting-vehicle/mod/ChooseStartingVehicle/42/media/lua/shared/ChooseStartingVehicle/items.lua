--- The searchable item list the cargo editor offers: drops hidden, obsolete and
--- furniture items, sorts by name and filters by category and search words.
--- Pure; raw item facts are read in the client.
local Items = {}

--- Returns the module of a full item type ("Base.Axe" -> "Base").
function Items.moduleOf(fullType)
    return string.match(fullType or "", "^([^%.]+)%.") or ""
end

--- True for items that never belong in cargo: hidden, obsolete or moveables.
function Items.isExcluded(raw)
    if not raw.fullType or raw.hidden or raw.obsolete then
        return true
    end
    return Items.moduleOf(raw.fullType) == "Moveables" or string.find(raw.fullType, ".Mov_", 1, true) ~= nil
end

--- Builds sorted entries from raw facts ({fullType, displayName, category, weight, icon}).
function Items.buildEntries(raws)
    local entries = {}
    for _, raw in ipairs(raws) do
        if not Items.isExcluded(raw) then
            entries[#entries + 1] = {
                fullType = raw.fullType,
                label = raw.displayName or raw.fullType,
                category = raw.category or "Unknown",
                weight = raw.weight or 0,
                icon = raw.icon,
            }
        end
    end
    table.sort(entries, function(a, b)
        local an, bn = string.lower(a.label), string.lower(b.label)
        if an == bn then
            return a.fullType < b.fullType
        end
        return an < bn
    end)
    return entries
end

--- Returns the sorted distinct categories of the entries.
function Items.categories(entries)
    local seen, list = {}, {}
    for _, entry in ipairs(entries) do
        if not seen[entry.category] then
            seen[entry.category] = true
            list[#list + 1] = entry.category
        end
    end
    table.sort(list)
    return list
end

--- Returns the entries in `category` (nil for all) whose name or type holds
--- every word of `query`, case-insensitively, up to `limit` results.
function Items.filter(entries, query, category, limit)
    local words = {}
    for word in string.gmatch(string.lower(query or ""), "%S+") do
        words[#words + 1] = word
    end
    local matches = {}
    for _, entry in ipairs(entries) do
        local ok = category == nil or entry.category == category
        if ok and #words > 0 then
            local haystack = string.lower(entry.label .. " " .. entry.fullType)
            for _, word in ipairs(words) do
                if not string.find(haystack, word, 1, true) then
                    ok = false
                    break
                end
            end
        end
        if ok then
            matches[#matches + 1] = entry
            if limit and #matches >= limit then
                break
            end
        end
    end
    return matches
end

--- Returns the total weight of stacks, using `weightOf(fullType)`.
function Items.stackWeight(stacks, weightOf)
    local total = 0
    for _, stack in ipairs(stacks or {}) do
        total = total + (weightOf(stack.type) or 0) * stack.count
    end
    return total
end

return Items
