--- Pure rules for the Crew tab: which skills and fighting stats can be set,
--- keeping levels in range, which weapon slot an item goes in, merging a
--- piece of clothing into an outfit, searching the item list, and the
--- overrides laid over A-Life's plan when a crew member's body loads.
ALifeRepEditor = ALifeRepEditor or {}

local Crew = {}
ALifeRepEditor.CrewRows = Crew

Crew.SKILLS = { "melee", "aiming", "firstAid", "cooking", "carpentry", "mechanics", "music", "stealth", "foraging" }
Crew.RATINGS = { "strength", "aiming" }
Crew.SKILL_LABELS = { melee = "Melee", aiming = "Aiming", firstAid = "First aid", cooking = "Cooking",
    carpentry = "Carpentry", mechanics = "Mechanics", music = "Music", stealth = "Stealth", foraging = "Foraging" }
Crew.RATING_LABELS = { strength = "Strength", aiming = "Accuracy" }
Crew.SKILL_MAX = 10
Crew.RATING_MAX = 10
Crew.GUN_ROUNDS = 60
Crew.SEARCH_MIN = 2
Crew.SEARCH_LIMIT = 40

Crew.REFUSALS = {
    disabled = "Companions are turned off in A-Life's sandbox options.",
    gone = "That person isn't around any more.",
    not_yours = "%1 isn't in your crew.",
    unloaded = "%1 is too far away to hand things to; get closer and try again.",
    unknown_skill = "Unknown skill.",
    unknown_item = "There's no item called %2 in this game.",
    no_item = "%1 isn't carrying that any more.",
    no_gun = "%1 isn't holding a gun.",
    not_clothing = "%2 isn't something they can wear.",
    last_piece = "%1 needs to keep at least one piece of clothing on.",
    not_saved = "A-Life wouldn't save that change; try again.",
}

--- Returns true when an id is one of the given names.
local function known(list, id)
    for _, name in ipairs(list) do
        if name == id then return true end
    end
    return false
end

--- Returns true when an id is one of A-Life's nine companion skills.
function Crew.isSkill(id)
    return known(Crew.SKILLS, id)
end

--- Returns true when an id is a fighting stat the editor can set.
function Crew.isRating(id)
    return known(Crew.RATINGS, id)
end

--- Returns a level as a whole number kept between 0 and maximum.
function Crew.clamp(value, maximum)
    local number = math.floor((tonumber(value) or 0) + 0.5)
    local top = tonumber(maximum) or Crew.SKILL_MAX
    if number < 0 then return 0 end
    if number > top then return top end
    return number
end

--- Fills a refusal message with a person's name and an item name, escaping % in both.
function Crew.refusal(why, name, item)
    local text = Crew.REFUSALS[why] or ("Couldn't do that (" .. tostring(why) .. ").")
    local safeName = string.gsub(tostring(name or "They"), "%%", "%%%%")
    local safeItem = string.gsub(tostring(item or "that"), "%%", "%%%%")
    text = string.gsub(text, "%%1", safeName)
    text = string.gsub(text, "%%2", safeItem)
    return text
end

--- Returns A-Life's weapon slot for an item: melee, primary (two-handed gun) or secondary (one-handed gun).
function Crew.slotFor(info)
    if type(info) ~= "table" or info.firearm ~= true then return "melee" end
    return info.twoHanded == true and "primary" or "secondary"
end

--- Returns what a Give button does with an item kind: equip a weapon, wear clothing, or carry it.
function Crew.giveAction(kind)
    if kind == "weapon" then return "equip" end
    if kind == "clothing" then return "wear" end
    return "carry"
end

--- Returns a copy of an outfit with an item put on, replacing anything worn on the same body location.
function Crew.wearInto(outfit, itemType, location, locationOf)
    local result = {}
    for _, entry in ipairs(type(outfit) == "table" and outfit or {}) do
        local entryType = type(entry) == "table" and entry.itemType or entry
        local entryLocation = locationOf ~= nil and locationOf(entryType) or nil
        local same = entryType == itemType or (location ~= nil and entryLocation == location)
        if not same and type(entryType) == "string" then
            result[#result + 1] = { itemType = entryType, tint = type(entry) == "table" and entry.tint or "" }
        end
    end
    result[#result + 1] = { itemType = itemType, tint = "" }
    return result
end

--- Returns a copy of an outfit without one item type, and whether it was there.
function Crew.takeOff(outfit, itemType)
    local result, found = {}, false
    for _, entry in ipairs(type(outfit) == "table" and outfit or {}) do
        local entryType = type(entry) == "table" and entry.itemType or entry
        if entryType == itemType and not found then
            found = true
        elseif type(entryType) == "string" then
            result[#result + 1] = { itemType = entryType, tint = type(entry) == "table" and entry.tint or "" }
        end
    end
    return result, found
end

--- Returns up to limit catalog items whose name or type contains the search text, sorted by name.
function Crew.search(catalog, query, limit)
    local needle = string.lower(tostring(query or ""))
    needle = string.gsub(needle, "^%s+", "")
    needle = string.gsub(needle, "%s+$", "")
    local result = {}
    if #needle < Crew.SEARCH_MIN then return result end
    for _, item in ipairs(type(catalog) == "table" and catalog or {}) do
        local haystack = string.lower(tostring(item.name or "") .. " " .. tostring(item.type or ""))
        if string.find(haystack, needle, 1, true) ~= nil then result[#result + 1] = item end
    end
    table.sort(result, function(left, right)
        local leftName, rightName = string.lower(tostring(left.name)), string.lower(tostring(right.name))
        local leftStarts = string.sub(leftName, 1, #needle) == needle
        local rightStarts = string.sub(rightName, 1, #needle) == needle
        if leftStarts ~= rightStarts then return leftStarts end
        if leftName ~= rightName then return leftName < rightName end
        return tostring(left.type) < tostring(right.type)
    end)
    local cap = tonumber(limit) or Crew.SEARCH_LIMIT
    while #result > cap do result[#result] = nil end
    return result
end

--- Lays a crew member's saved fighting stats, firearm permission and outfit over A-Life's plan for their body.
function Crew.applyOverrides(plan, saved)
    if type(plan) ~= "table" or type(saved) ~= "table" then return plan end
    if tonumber(saved.strength) ~= nil then plan.strength = Crew.clamp(saved.strength, Crew.RATING_MAX) end
    if tonumber(saved.aiming) ~= nil then plan.aiming = Crew.clamp(saved.aiming, Crew.RATING_MAX) end
    if saved.firearms == true then plan.firearmsAuthored = true end
    if type(saved.outfit) == "table" and #saved.outfit > 0 then
        local clothing = {}
        for _, entry in ipairs(saved.outfit) do
            if type(entry) == "table" and type(entry.itemType) == "string" then
                clothing[#clothing + 1] = { itemType = entry.itemType, tint = entry.tint or "" }
            end
        end
        if #clothing > 0 then plan.clothing = clothing end
    end
    return plan
end

--- Groups carried items for the list: weapons and worn clothing one per row, other items stacked by type.
function Crew.carryRows(items)
    local rows, stacks = {}, {}
    for _, item in ipairs(type(items) == "table" and items or {}) do
        if item.weapon or item.worn then
            rows[#rows + 1] = { id = item.id, type = item.type, name = item.name, count = 1,
                weapon = item.weapon == true, worn = item.worn == true, equipped = item.equipped == true }
        else
            local stack = stacks[item.type]
            if stack == nil then
                stack = { id = item.id, type = item.type, name = item.name, count = 0 }
                stacks[item.type] = stack
                rows[#rows + 1] = stack
            end
            stack.count = stack.count + 1
        end
    end
    table.sort(rows, function(left, right)
        local leftRank = left.equipped and 0 or left.weapon and 1 or left.worn and 3 or 2
        local rightRank = right.equipped and 0 or right.weapon and 1 or right.worn and 3 or 2
        if leftRank ~= rightRank then return leftRank < rightRank end
        return string.lower(tostring(left.name)) < string.lower(tostring(right.name))
    end)
    return rows
end

return Crew
