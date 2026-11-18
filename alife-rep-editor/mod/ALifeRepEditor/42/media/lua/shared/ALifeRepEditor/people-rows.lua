--- Pure view model for the People tab: searching and ordering the NPCs
--- you've met, and the short lines shown about each one.
ALifeRepEditor = ALifeRepEditor or {}

local People = {}
ALifeRepEditor.PeopleRows = People

People.STANCE_TEXT = {
    allied = "Allied", friendly = "Friendly", neutral = "Neutral", careful = "Wary", hostile = "Hostile",
}

--- Returns true when a person's name or faction contains the search text (any case).
function People.matches(person, query)
    local needle = string.lower(tostring(query or ""))
    needle = string.gsub(needle, "^%s+", "")
    needle = string.gsub(needle, "%s+$", "")
    if needle == "" then return true end
    local haystack = string.lower(tostring(person.name or "") .. " " .. tostring(person.factionName or ""))
    return string.find(haystack, needle, 1, true) ~= nil
end

--- Returns the people matching a search, keeping their order.
function People.filter(people, query)
    local result = {}
    for _, person in ipairs(type(people) == "table" and people or {}) do
        if People.matches(person, query) then result[#result + 1] = person end
    end
    return result
end

--- Sorts people: the focused one first, then the most recently changed, then by name.
function People.sort(people, focusUid)
    table.sort(people, function(left, right)
        local leftFocus, rightFocus = left.uid == focusUid, right.uid == focusUid
        if leftFocus ~= rightFocus then return leftFocus end
        local leftAt, rightAt = tonumber(left.at) or -math.huge, tonumber(right.at) or -math.huge
        if leftAt ~= rightAt then return leftAt > rightAt end
        return string.lower(tostring(left.name)) < string.lower(tostring(right.name))
    end)
    return people
end

--- Returns the index of the person with a uid in a list, or nil.
function People.indexOf(people, uid)
    for index, person in ipairs(type(people) == "table" and people or {}) do
        if person.uid == uid then return index end
    end
    return nil
end

--- Returns the display word for an NPC's stance toward you.
function People.stanceText(stance)
    return People.STANCE_TEXT[tostring(stance or "")] or "Unknown"
end

--- Returns the faction, crew and stance line under a person's name.
function People.subtitle(person)
    local parts = {}
    local faction = tostring(person.factionName or "")
    if faction ~= "" then parts[#parts + 1] = faction end
    if person.crew == "yours" then parts[#parts + 1] = "in your crew" end
    if person.crew == "other" then parts[#parts + 1] = "in someone else's crew" end
    if person.stance ~= nil then parts[#parts + 1] = "treats you as " .. string.lower(People.stanceText(person.stance)) end
    return table.concat(parts, ", ")
end

People.CREW_REFUSALS = {
    disabled = "Companions are turned off in A-Life's sandbox options.",
    roster_full = "Your crew is full at %2; dismiss someone first.",
    taken = "%1 is already in someone else's crew.",
    unavailable = "%1 can't join right now; get closer to them and try again.",
    too_far = "%1 is too far away; get closer to them and try again.",
    not_yours = "%1 isn't in your crew.",
    gone = "That person isn't around any more.",
}

--- Returns the message for a failed crew change, from A-Life's reason code.
function People.crewRefusal(why, name, maximum)
    local text = People.CREW_REFUSALS[tostring(why or "")]
        or ("%1 couldn't join your crew (" .. tostring(why or "unknown") .. ").")
    text = string.gsub(text, "%%1", (string.gsub(tostring(name or "They"), "%%", "%%%%")))
    text = string.gsub(text, "%%2", tostring(tonumber(maximum) or 5))
    return text
end

--- Returns the value with an explicit sign, as in "+28" or "-5".
function People.signed(value)
    local number = math.floor((tonumber(value) or 0) + 0.5)
    return number > 0 and ("+" .. tostring(number)) or tostring(number)
end

return People
