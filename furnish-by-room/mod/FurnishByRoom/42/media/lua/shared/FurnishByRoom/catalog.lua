--- Turns scanned tile records into the per-room catalog: one entry per piece
--- of furniture (its four facings and its other grid tiles folded into one
--- card), one entry per floor, sorted by category then name.
local Classify = require("FurnishByRoom/classify")

local Catalog = {}

Catalog.FACES = { "N", "W", "S", "E" }
local DEFAULT_FACE_ORDER = { "S", "E", "W", "N", "_" }

--- Returns the entry key for a record: its sheet plus its name, or plus its
--- tile number for unnamed tiles. Same-named floors share one entry.
function Catalog.key(record, label)
    if label == "" then
        return record.sheet .. "|" .. tostring(record.index)
    end
    return record.sheet .. "|" .. label
end

--- Returns true when a record is the tile that stands for its object: a
--- single tile, or the anchor of a multi-tile grid.
function Catalog.isAnchor(record)
    return record.anchor ~= false
end

--- Picks the facing a new entry shows first.
function Catalog.defaultSprite(faces)
    for _, face in ipairs(DEFAULT_FACE_ORDER) do
        if faces[face] then
            return faces[face]
        end
    end
    return nil
end

--- Records a facing on an entry, keeping the lowest tile number per facing.
local function addFace(entry, record)
    local face = record.facing or "_"
    local current = entry.faceIndex[face]
    if current == nil or record.index < current then
        entry.faceIndex[face] = record.index
        entry.faces[face] = record.sprite
    end
end

--- Sorts entries by category order, then name, then key.
function Catalog.sortEntries(entries)
    table.sort(entries, function(a, b)
        local ra, rb = Classify.categoryRank(a.cat), Classify.categoryRank(b.cat)
        if ra ~= rb then
            return ra < rb
        end
        if a.label ~= b.label then
            return a.label < b.label
        end
        return a.key < b.key
    end)
end

--- Builds the catalog from tile records ({ sprite, sheet, index, group,
--- custom, container, floor, moveable, facing, anchor }).
function Catalog.build(records, rules)
    local rooms = {}
    for _, record in ipairs(records) do
        if Catalog.isAnchor(record) then
            local places, fallback = Classify.places(record, rules)
            local label = Classify.label(record.group, record.custom)
            if label == "" and fallback == nil then
                places = {}
            elseif label == "" then
                label = fallback .. " " .. tostring(record.index)
            end
            if #places > 0 then
                local key = Catalog.key(record, Classify.label(record.group, record.custom))
                for _, place in ipairs(places) do
                    local room = rooms[place.room]
                    if not room then
                        room = { entries = {}, byKey = {} }
                        rooms[place.room] = room
                    end
                    local entry = room.byKey[key]
                    if not entry then
                        entry = { key = key, label = label, room = place.room, cat = place.cat,
                            sheet = record.sheet, floor = record.floor == true, faces = {}, faceIndex = {} }
                        room.byKey[key] = entry
                        room.entries[#room.entries + 1] = entry
                    end
                    addFace(entry, record)
                end
            end
        end
    end
    for _, room in pairs(rooms) do
        for _, entry in ipairs(room.entries) do
            entry.sprite = Catalog.defaultSprite(entry.faces)
            entry.faceIndex = nil
        end
        Catalog.sortEntries(room.entries)
        local cats, seen = {}, {}
        for _, entry in ipairs(room.entries) do
            if not seen[entry.cat] then
                seen[entry.cat] = true
                cats[#cats + 1] = entry.cat
            end
        end
        room.cats = cats
        room.count = #room.entries
    end
    return { rooms = rooms }
end

--- Returns a room's entries, or an empty list.
function Catalog.entries(catalog, room)
    local r = catalog and catalog.rooms[room]
    return r and r.entries or {}
end

--- Returns a room's categories in display order, or an empty list.
function Catalog.categories(catalog, room)
    local r = catalog and catalog.rooms[room]
    return r and r.cats or {}
end

--- Returns how many entries a room has.
function Catalog.count(catalog, room)
    local r = catalog and catalog.rooms[room]
    return r and r.count or 0
end

return Catalog
