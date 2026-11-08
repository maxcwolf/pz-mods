--- The list of saved blueprints. The game cannot list files from Lua, so an
--- index file names every blueprint file. Both live in ~/Zomboid/Lua so they
--- work in every save.
local Codec = require("BaseBlueprints/codec")

local Library = {}

Library.INDEX = "BaseBlueprints_index.txt"
Library.HEADER = "BaseBlueprints index 1"

--- Returns the file name for a blueprint id.
function Library.fileFor(id)
    return "BaseBlueprints_" .. id .. ".txt"
end

--- Makes an index entry from a blueprint.
function Library.entryFor(bp, auto)
    local m = bp.meta
    local area = m.area
    return {
        id = m.id,
        name = m.name,
        x = math.floor((area.x1 + area.x2) / 2),
        y = math.floor((area.y1 + area.y2) / 2),
        squares = m.squares or 0,
        objects = m.objects or 0,
        contents = m.contents == true,
        changedOnly = m.changedOnly == true,
        created = m.created or "",
        auto = auto == true,
    }
end

--- Reads index lines into entries; unreadable lines are skipped.
function Library.parseIndex(lines)
    local entries = {}
    if not lines or lines[1] ~= Library.HEADER then
        return entries
    end
    for i = 2, #lines do
        local entry = Codec.decode(lines[i])
        if type(entry) == "table" and type(entry.id) == "string" and type(entry.name) == "string" then
            entries[#entries + 1] = entry
        end
    end
    return entries
end

--- Returns index lines for entries.
function Library.indexLines(entries)
    local lines = { Library.HEADER }
    for _, entry in ipairs(entries) do
        lines[#lines + 1] = Codec.encode(entry)
    end
    return lines
end

--- Returns the position of an id in entries, or nil.
function Library.find(entries, id)
    for i, entry in ipairs(entries) do
        if entry.id == id then
            return i
        end
    end
    return nil
end

--- Adds an entry, replacing one with the same id; newest first.
function Library.upsert(entries, entry)
    local i = Library.find(entries, entry.id)
    if i then
        table.remove(entries, i)
    end
    table.insert(entries, 1, entry)
    return entries
end

--- Removes an entry by id.
function Library.remove(entries, id)
    local i = Library.find(entries, id)
    if i then
        table.remove(entries, i)
    end
    return entries
end

--- Returns the id of an entry whose name matches (case-insensitive), or nil.
function Library.idForName(entries, name)
    local wanted = string.lower(name or "")
    for _, entry in ipairs(entries) do
        if string.lower(entry.name) == wanted then
            return entry.id
        end
    end
    return nil
end

return Library
