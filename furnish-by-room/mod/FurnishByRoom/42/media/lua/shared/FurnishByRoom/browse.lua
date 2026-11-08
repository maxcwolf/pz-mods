--- What the player is looking at in either layout: a room, a category
--- ("all" or one of the room's) and a search, and the items that leaves.
local Catalog = require("FurnishByRoom/catalog")

local Browse = {}

Browse.ALL = "all"

--- Returns a fresh view of a room.
function Browse.new(room)
    return { room = room, cat = Browse.ALL, query = "" }
end

--- Returns the search words, lowercased, without empty ones.
function Browse.words(query)
    local words = {}
    for word in string.gmatch(string.lower(query or ""), "%S+") do
        words[#words + 1] = word
    end
    return words
end

--- Returns true when the label contains every word.
function Browse.matchesWords(label, words)
    local text = string.lower(label or "")
    for _, word in ipairs(words) do
        if not string.find(text, word, 1, true) then
            return false
        end
    end
    return true
end

--- Returns the entries the view shows: a search looks through the whole
--- room; otherwise the category filters.
function Browse.items(catalog, view)
    local words = Browse.words(view.query)
    local out = {}
    for _, entry in ipairs(Catalog.entries(catalog, view.room)) do
        if #words > 0 then
            if Browse.matchesWords(entry.label, words) then
                out[#out + 1] = entry
            end
        elseif view.cat == Browse.ALL or entry.cat == view.cat then
            out[#out + 1] = entry
        end
    end
    return out
end

--- Returns the category filters for the view's room, "all" first.
function Browse.filters(catalog, view)
    local out = { Browse.ALL }
    for _, cat in ipairs(Catalog.categories(catalog, view.room)) do
        out[#out + 1] = cat
    end
    return out
end

--- Switches room, resetting the category and search.
function Browse.setRoom(view, room)
    view.room = room
    view.cat = Browse.ALL
    view.query = ""
end

--- Sets the category, falling back to "all" when the room lacks it.
function Browse.setCategory(catalog, view, cat)
    for _, c in ipairs(Browse.filters(catalog, view)) do
        if c == cat then
            view.cat = cat
            return
        end
    end
    view.cat = Browse.ALL
end

--- Returns the category after the view's, wrapping, for the strip's cycle.
function Browse.nextCategory(catalog, view)
    local filters = Browse.filters(catalog, view)
    for i, c in ipairs(filters) do
        if c == view.cat then
            return filters[i % #filters + 1]
        end
    end
    return Browse.ALL
end

--- Returns the entry with the key in the view's room, or nil.
function Browse.find(catalog, room, key)
    for _, entry in ipairs(Catalog.entries(catalog, room)) do
        if entry.key == key then
            return entry
        end
    end
    return nil
end

--- Returns the entry after (or before, with step -1) the one with key in
--- list, wrapping; the first entry when key is not in the list.
function Browse.neighbor(list, key, step)
    if #list == 0 then
        return nil
    end
    for i, entry in ipairs(list) do
        if entry.key == key then
            return list[(i - 1 + (step or 1)) % #list + 1]
        end
    end
    return list[1]
end

return Browse
