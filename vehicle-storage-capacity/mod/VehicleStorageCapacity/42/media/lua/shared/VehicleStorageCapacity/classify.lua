--- Sorts vehicle storage into the sandbox categories. Pure: callers pass plain
--- values read from the game, so the rules work for vanilla, KI5 and any other
--- vehicle mod without a per-mod list.
local Classify = {}

--- Returns true when the vehicle is a trailer or camper: its script name says
--- so, or it has no engine (KI5 trailers and campers, vanilla trailers).
function Classify.isTrailer(scriptName, hasEngine)
    local name = string.lower(scriptName or "")
    if string.find(name, "trailer", 1, true) then
        return true
    end
    return not hasEngine
end

--- Returns true when any of the part's item types is a glove box item.
local function hasGloveBoxItem(itemTypes)
    for _, itemType in ipairs(itemTypes or {}) do
        if string.find(string.lower(itemType), "glovebox", 1, true) then
            return true
        end
    end
    return false
end

--- Returns "seat", "glovebox", "trailer" or "trunk" for one storage part.
--- `part` holds id, seatNumber (-1 when not a seat) and itemTypes (a list).
function Classify.category(part, isTrailer)
    local id = string.lower(part.id or "")
    if (part.seatNumber or -1) >= 0 or string.sub(id, 1, 4) == "seat" then
        return "seat"
    end
    if string.find(id, "glovebox", 1, true) or string.find(id, "console", 1, true)
        or hasGloveBoxItem(part.itemTypes) then
        return "glovebox"
    end
    if isTrailer then
        return "trailer"
    end
    return "trunk"
end

return Classify
