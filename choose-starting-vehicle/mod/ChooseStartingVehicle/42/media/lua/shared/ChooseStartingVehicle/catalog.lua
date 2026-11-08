--- Turns resolved vehicle facts into what the picker shows: which vehicles to
--- list, their paint names, and the part "slots" you can choose for, with parts
--- that share a position-free name and the same options merged into one slot
--- (four tires become one Tires row). Pure: labels and item checks come in
--- through a `lookups` table.
local Catalog = {}

Catalog.SOURCE_KI5 = "ki5"
Catalog.SOURCE_GAME = "game"
Catalog.SOURCE_MOD = "mod"

local POSITION_WORDS = { Front = true, Rear = true, Back = true, Middle = true, Left = true, Right = true }

-- Vanilla part ids whose slot always exists on the car; these never offer
-- "None" because removing them would leave the vehicle broken or unusable.
local STRUCTURAL_STEMS = {
    Engine = true, EngineDoor = true, Battery = true, GasTank = true, Muffler = true,
    Brake = true, Suspension = true, Tire = true, Door = true, Window = true,
    Windshield = true, Windhield = true, Seat = true, Headlight = true, TrunkDoor = true,
    GloveBox = true, Heater = true, PassengerCompartment = true, TruckBed = true, Trunk = true,
    TruckBedOpen = true, Radio = true, Hood = true,
}

local HIDDEN_CATEGORIES = { nodisplay = true }

--- Splits a camel-case id into words ("DAMNFrontLeftArmor" -> DAMN, Front, Left, Armor).
function Catalog.idWords(id)
    local words = {}
    local current = ""
    local len = #id
    for i = 1, len do
        local ch = string.sub(id, i, i)
        local prev = i > 1 and string.sub(id, i - 1, i - 1) or ""
        local nextCh = i < len and string.sub(id, i + 1, i + 1) or ""
        local isUpper = string.find(ch, "%u") ~= nil
        local startsWord = false
        if current ~= "" then
            if isUpper and string.find(prev, "[%l%d]") then
                startsWord = true
            elseif isUpper and string.find(prev, "%u") and string.find(nextCh, "%l") then
                startsWord = true
            elseif string.find(ch, "%d") and not string.find(prev, "%d") then
                startsWord = true
            elseif string.find(ch, "%a") and string.find(prev, "%d") then
                startsWord = true
            end
        end
        if startsWord then
            words[#words + 1] = current
            current = ""
        end
        current = current .. ch
    end
    if current ~= "" then
        words[#words + 1] = current
    end
    return words
end

--- Returns a part id with its position words removed ("TireFrontLeft" -> "Tire").
function Catalog.stem(id)
    local kept = {}
    for _, word in ipairs(Catalog.idWords(id)) do
        if not POSITION_WORDS[word] then
            kept[#kept + 1] = word
        end
    end
    if #kept == 0 then
        return id
    end
    return table.concat(kept)
end

-- Last words of container part ids that hold the vehicle's own storage (KI5's
-- DEF89Trunk, CHR69Trunk, DEF89CenterConsole); these are never add-ons.
local STORAGE_WORDS = { Trunk = true, Bed = true, GloveBox = true, Glovebox = true, Console = true }

--- True when the part is one every car of this kind has (engine, doors, seats,
--- trunk storage...).
function Catalog.isStructural(part)
    if part.door or part.window or part.wheel then
        return true
    end
    if part.container then
        local words = Catalog.idWords(part.id)
        if STORAGE_WORDS[words[#words]] then
            return true
        end
    end
    return STRUCTURAL_STEMS[Catalog.stem(part.id)] == true
end

--- True when an item name looks like a real item ("Module.Type"), not "nil".
function Catalog.isItemName(name)
    return type(name) == "string" and string.find(name, ".", 1, true) ~= nil
end

--- Returns the words that appear in every label, in the first label's order,
--- so "Front Left Tire" and "Rear Right Tire" share the label "Tire".
function Catalog.commonLabel(labels)
    if #labels == 0 then
        return ""
    end
    if #labels == 1 then
        return labels[1]
    end
    local counts = {}
    for _, label in ipairs(labels) do
        local seen = {}
        for word in string.gmatch(label, "%S+") do
            if not seen[word] then
                seen[word] = true
                counts[word] = (counts[word] or 0) + 1
            end
        end
    end
    local kept = {}
    for word in string.gmatch(labels[1], "%S+") do
        if counts[word] == #labels then
            kept[#kept + 1] = word
        end
    end
    if #kept == 0 then
        return labels[1]
    end
    return table.concat(kept, " ")
end

--- Turns a camel-case or lower-case word run into title case ("chestnutBrown" -> "Chestnut Brown").
function Catalog.titleCase(text)
    local spaced = string.gsub(text, "(%l)(%u)", "%1 %2")
    spaced = string.gsub(spaced, "[_%-]+", " ")
    local words = {}
    for word in string.gmatch(spaced, "%S+") do
        words[#words + 1] = string.upper(string.sub(word, 1, 1)) .. string.sub(word, 2)
    end
    return table.concat(words, " ")
end

--- Names a paint from its texture path ("Vehicles/Vehicles_84jeepXJ4_Shell_silver" -> "Silver"),
--- or returns nil when the texture name says nothing useful.
function Catalog.skinLabel(texture)
    if type(texture) ~= "string" or texture == "" then
        return nil
    end
    local name = string.match(texture, "([^/]+)$") or texture
    local after = string.match(name, "_[Ss]hell_(.+)$")
    if not after then
        after = string.match(name, "_([^_]+)$")
    end
    if not after or after == "" or string.find(after, "^%d+$") then
        return nil
    end
    return Catalog.titleCase(after)
end

--- Builds the paint list: one label per skin, falling back to "Paint N" and
--- numbering repeated names so every entry is distinct.
function Catalog.skinLabels(textures, skinCount, fallbackPrefix)
    local labels = {}
    local seen = {}
    local count = skinCount or #textures
    local useTextures = #textures == count
    for i = 1, count do
        local label = useTextures and Catalog.skinLabel(textures[i]) or nil
        if not label then
            label = (fallbackPrefix or "Paint") .. " " .. tostring(i)
        end
        seen[label] = (seen[label] or 0) + 1
        if seen[label] > 1 then
            label = label .. " " .. tostring(seen[label])
        end
        labels[i] = label
    end
    return labels
end

--- True when a script name is a trailer, by the same rule vanilla's tow menu uses.
function Catalog.isTrailerName(name)
    return string.find(name or "", "Trailer", 1, true) ~= nil
end

--- True when the vehicle is a wreck or burnt shell that should not be offered.
function Catalog.isWreckName(name)
    name = name or ""
    return string.find(name, "Burnt", 1, true) ~= nil or string.find(name, "Smashed", 1, true) ~= nil
end

--- Works out where a vehicle comes from: KI5 when any referenced template is a
--- damnlib (DAMN...) template, the game when the mod id is vanilla, else a mod.
function Catalog.source(modId, templateNames)
    for _, name in ipairs(templateNames or {}) do
        if string.sub(name, 1, 4) == "DAMN" then
            return Catalog.SOURCE_KI5
        end
    end
    if modId == nil or modId == "" or modId == "pz-vanilla" or modId == "Base" then
        return Catalog.SOURCE_GAME
    end
    return Catalog.SOURCE_MOD
end

--- Builds the choosable slots from resolved parts. `lookups.itemLabel(type)`
--- returns a display name or nil when the item does not exist;
--- `lookups.partLabel(id)` returns the part's display name.
function Catalog.buildSlots(resolved, mechanicType, lookups, installableTypes)
    local groups = {}
    local order = {}
    for _, id in ipairs(resolved.order) do
        local part = resolved.byId[id]
        if not HIDDEN_CATEGORIES[part.category or ""] then
            local options = {}
            for _, itemType in ipairs(installableTypes(part, mechanicType)) do
                if Catalog.isItemName(itemType) then
                    local label = lookups.itemLabel(itemType)
                    if label then
                        options[#options + 1] = { itemType = itemType, label = label }
                    end
                end
            end
            local structural = Catalog.isStructural(part)
            local allowNone = not structural
            if #options > 0 and (#options >= 2 or allowNone) then
                local signature = {}
                for _, option in ipairs(options) do
                    signature[#signature + 1] = option.itemType
                end
                local key = Catalog.stem(id) .. "|" .. table.concat(signature, ";")
                local group = groups[key]
                if not group then
                    group = { key = key, partIds = {}, labels = {}, options = options, allowNone = allowNone }
                    groups[key] = group
                    order[#order + 1] = group
                end
                group.partIds[#group.partIds + 1] = id
                group.labels[#group.labels + 1] = lookups.partLabel(id) or id
            end
        end
    end
    local slots = {}
    for _, group in ipairs(order) do
        slots[#slots + 1] = {
            key = group.partIds[1],
            partIds = group.partIds,
            label = Catalog.commonLabel(group.labels),
            options = group.options,
            allowNone = group.allowNone,
        }
    end
    return slots
end

--- Returns every part the mechanics window would show, in the vehicle's part
--- order, each with its label and the slot that controls it (nil when the
--- part has nothing to choose).
function Catalog.displayParts(resolved, slots, lookups)
    local slotOf = {}
    for _, slot in ipairs(slots) do
        for _, id in ipairs(slot.partIds) do
            slotOf[id] = slot
        end
    end
    local parts = {}
    for _, id in ipairs(resolved.order) do
        local part = resolved.byId[id]
        if not HIDDEN_CATEGORIES[part.category or ""] then
            parts[#parts + 1] = {
                id = id,
                label = lookups.partLabel(id) or id,
                category = part.category or "Other",
                slot = slotOf[id],
                itemTypes = part.itemTypes or {},
                models = part.models or {},
                container = part.container,
                capacity = part.capacity or 0,
                door = part.door,
                window = part.window,
                wheel = part.wheel,
            }
        end
    end
    return parts
end

-- Categories vanilla's mechanics window puts in its right-hand list.
local RIGHT_COLUMN = { door = true, bodywork = true, lights = true }

--- Groups parts by category the way the mechanics window does: categories in
--- order of first appearance, doors, bodywork and lights on the right.
function Catalog.mechanicsColumns(parts)
    local columns = { left = {}, right = {} }
    local groups = {}
    for _, part in ipairs(parts) do
        local group = groups[part.category]
        if not group then
            group = { category = part.category, parts = {} }
            groups[part.category] = group
            local side = RIGHT_COLUMN[part.category] and columns.right or columns.left
            side[#side + 1] = group
        end
        group.parts[#group.parts + 1] = part
    end
    return columns
end

--- Sorts entries by source (KI5, game, other mods) and then display name.
function Catalog.sortEntries(entries)
    local rank = { [Catalog.SOURCE_KI5] = 1, [Catalog.SOURCE_GAME] = 2, [Catalog.SOURCE_MOD] = 3 }
    table.sort(entries, function(a, b)
        local ra, rb = rank[a.source] or 9, rank[b.source] or 9
        if ra ~= rb then
            return ra < rb
        end
        local na, nb = string.lower(a.displayName or a.name), string.lower(b.displayName or b.name)
        if na ~= nb then
            return na < nb
        end
        return a.name < b.name
    end)
    return entries
end

--- Returns the entries that match a source filter ("all" keeps everything).
function Catalog.filter(entries, source, trailers)
    local kept = {}
    for _, entry in ipairs(entries) do
        if (entry.isTrailer == trailers) and (source == "all" or entry.source == source) then
            kept[#kept + 1] = entry
        end
    end
    return kept
end

--- Finds an entry by script name.
function Catalog.find(entries, name)
    for _, entry in ipairs(entries) do
        if entry.name == name then
            return entry
        end
    end
    return nil
end

--- Finds the slot that controls a part id.
function Catalog.slotForPart(entry, partId)
    for _, slot in ipairs(entry and entry.slots or {}) do
        for _, id in ipairs(slot.partIds) do
            if id == partId then
                return slot
            end
        end
    end
    return nil
end

return Catalog
