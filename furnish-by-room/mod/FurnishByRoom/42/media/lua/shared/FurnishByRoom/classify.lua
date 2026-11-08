--- Decides which rooms and categories a game tile belongs to, from its tile
--- sheet, its name (GroupName + CustomName) and its container type. Every
--- matching rule adds its rooms; the first rule to name a room sets the
--- category there. Tiles no rule names stay out of the catalog.
local Classify = {}

Classify.CATEGORIES = {
    "appliances", "counters", "storage", "tables", "seating", "beds",
    "electronics", "lighting", "decor", "games", "tools", "floors",
}

local WOOD = { "wood", "oak", "birch", "cinnamon", "chestnut", "acacia", "pine" }

--- Each rule: sheet (Lua pattern), has / hasnt / is (lowercase name tests),
--- container (any of), floor (true for floor tiles), name (label for tiles
--- the game left unnamed) and rooms (room -> category).
Classify.RULES = {
    -- Floors
    { sheet = "^floors_interior_tilesandwood_", floor = true, has = WOOD,
      rooms = { living = "floors", bedroom = "floors", dining = "floors", bar = "floors" } },
    { sheet = "^floors_interior_tilesandwood_", floor = true, hasnt = WOOD,
      rooms = { kitchen = "floors", dining = "floors", garage = "floors" } },
    { sheet = "^floors_interior_carpet_", floor = true, rooms = { bedroom = "floors", living = "floors" } },
    { sheet = "^location_restaurant_bar_", floor = true, rooms = { bar = "floors" } },
    { sheet = "^location_restaurant_diner_", floor = true, rooms = { kitchen = "floors", bar = "floors" } },
    { sheet = "^floors_exterior_street_", floor = true, name = "Concrete", rooms = { garage = "floors" } },

    -- Kitchen
    { sheet = "^appliances_refrigeration_", rooms = { kitchen = "appliances", bar = "appliances", garage = "appliances" } },
    { sheet = "^appliances_cooking_", hasnt = { "barbecue" }, rooms = { kitchen = "appliances" } },
    { sheet = "^appliances_cooking_", has = { "barbecue" }, rooms = { garage = "appliances" } },
    { sheet = "^fixtures_counters_", has = { "floating" }, rooms = { kitchen = "storage" } },
    { sheet = "^fixtures_counters_", rooms = { kitchen = "counters" } },
    { sheet = "^fixtures_sinks_", rooms = { kitchen = "counters" } },
    { sheet = "^fixtures_sinks_", has = { "industrial" }, rooms = { garage = "tools" } },
    { container = { "dishescabinet" }, rooms = { kitchen = "storage", dining = "storage" } },

    -- Bedroom
    { sheet = "^furniture_bedding_", rooms = { bedroom = "beds" } },
    { sheet = "^furniture_storage_", has = { "wardrobe", "drawers", "chest" }, rooms = { bedroom = "storage" } },
    { sheet = "^furniture_storage_", has = { "small table" }, rooms = { bedroom = "tables", living = "tables" } },
    { container = { "sidetable" }, rooms = { bedroom = "tables" } },

    -- Living room
    { sheet = "^furniture_seating_indoor_", has = { "couch", "ottoman" }, rooms = { living = "seating" } },
    { sheet = "^furniture_seating_indoor_", has = { "chair" }, rooms = { living = "seating", dining = "seating" } },
    { sheet = "^furniture_seating_indoor_", has = { "bench" }, rooms = { dining = "seating" } },
    { sheet = "^appliances_television_", rooms = { living = "electronics", bedroom = "electronics" } },
    { sheet = "^appliances_radio_", rooms = { living = "electronics", garage = "electronics" } },
    { sheet = "^appliances_com_", has = { "radio", "computer" }, rooms = { living = "electronics", garage = "electronics" } },
    { sheet = "^furniture_tables_low_", rooms = { living = "tables" } },
    { sheet = "^furniture_shelving_", hasnt = { "metal" }, rooms = { living = "storage" } },
    { sheet = "^recreational_01$", has = { "piano" }, rooms = { living = "decor" } },
    { sheet = "^floors_rugs_", rooms = { living = "decor", bedroom = "decor", dining = "decor" } },
    { sheet = "^vegetation_indoor_", hasnt = { "plantbed" }, rooms = { living = "decor", dining = "decor", bedroom = "decor" } },
    { sheet = "^walls_decoration_", has = { "painting", "mirror", "clock" }, rooms = { living = "decor", bedroom = "decor", dining = "decor" } },
    { sheet = "^location_entertainment_gallery_", has = { "painting" }, rooms = { living = "decor", dining = "decor" } },

    -- Lighting
    { sheet = "^lighting_indoor_", has = { "bar wall lamp" }, rooms = { bar = "lighting" } },
    { sheet = "^lighting_indoor_", has = { "fluorescent" }, rooms = { kitchen = "lighting", garage = "lighting" } },
    { sheet = "^lighting_indoor_", has = { "chandelier" }, rooms = { dining = "lighting", living = "lighting" } },
    { sheet = "^lighting_indoor_", has = { "wall lamp", "wall light" },
      rooms = { living = "lighting", bedroom = "lighting", dining = "lighting", bar = "lighting" } },
    { sheet = "^lighting_indoor_", has = { "lamp" }, rooms = { living = "lighting", bedroom = "lighting" } },

    -- Dining room
    { sheet = "^furniture_tables_high_", hasnt = { "desk" }, rooms = { dining = "tables", kitchen = "tables" } },
    { sheet = "^furniture_tables_high_", has = { "desk" }, rooms = { bedroom = "tables", living = "tables" } },

    -- Bar
    { sheet = "^location_restaurant_bar_01$", has = { "wall bar" }, rooms = { bar = "storage" } },
    { sheet = "^location_restaurant_bar_01$", has = { "counter", "tap" }, rooms = { bar = "counters" } },
    { sheet = "^location_restaurant_bar_01$", has = { "seating", "stool" }, rooms = { bar = "seating" } },
    { sheet = "^location_restaurant_bar_smutz$", has = { "dartboard" }, rooms = { bar = "games" } },
    { sheet = "^location_restaurant_bar_smutz$", has = { "table" }, rooms = { bar = "tables" } },
    { sheet = "^location_restaurant_bar_smutz$", has = { "painting", "flag" }, rooms = { bar = "decor" } },
    { sheet = "^location_restaurant_bar_smutz$", is = { "bar" }, rooms = { bar = "counters" } },
    { sheet = "^location_restaurant_diner_", has = { "barstool" }, rooms = { bar = "seating" } },
    { sheet = "^location_restaurant_diner_", has = { "seat" }, rooms = { dining = "seating", bar = "seating" } },
    { sheet = "^location_restaurant_diner_", has = { "neon sign" }, rooms = { bar = "decor" } },
    { sheet = "^recreational_01$", has = { "pool", "jukebox", "arcade", "pinball" }, rooms = { bar = "games" } },
    { sheet = "^recreational_01$", is = { "bar" }, rooms = { bar = "counters" } },
    { sheet = "^recreational_01$", is = { "stool" }, rooms = { bar = "seating" } },
    { sheet = "^signs_one%-off_lights_", has = { "neon" }, rooms = { bar = "decor" } },

    -- Garage
    { sheet = "^appliances_laundry_", hasnt = { "sign" }, rooms = { garage = "appliances" } },
    { sheet = "^furniture_seating_indoor_", has = { "folding", "office" }, rooms = { garage = "seating" } },
    { sheet = "^furniture_storage_", has = { "locker", "cartbox" }, rooms = { garage = "storage" } },
    { sheet = "^furniture_shelving_", has = { "metal" }, rooms = { garage = "storage" } },
    { sheet = "^location_shop_generic_", has = { "shelves" }, rooms = { garage = "storage" } },
    { sheet = "^recreational_01$", has = { "drum", "amplifier", "speaker" }, rooms = { garage = "games" } },
    { sheet = "^location_business_machinery_", has = { "workbench", "tool cabinet" }, rooms = { garage = "tools" } },
    { container = { "toolcabinet" }, rooms = { garage = "tools" } },
    { container = { "crate", "militarycrate", "metal_shelves", "locker", "militarylocker" }, rooms = { garage = "storage" } },
    { sheet = "^industry_01$", has = { "barrel" }, rooms = { garage = "storage" } },
    { sheet = "^location_military_generic_", has = { "barrel" }, rooms = { garage = "storage" } },
}

--- Returns the display name for a tile: GroupName and CustomName joined.
function Classify.label(group, custom)
    local text = (group or "") .. " " .. (custom or "")
    text = string.gsub(text, "%s+", " ")
    return (string.gsub(text, "^%s*(.-)%s*$", "%1"))
end

--- Returns true when text contains any of the words.
local function containsAny(text, words)
    for _, word in ipairs(words) do
        if string.find(text, word, 1, true) then
            return true
        end
    end
    return false
end

--- Returns true when value equals one of the list's entries.
local function oneOf(value, list)
    for _, v in ipairs(list) do
        if v == value then
            return true
        end
    end
    return false
end

--- Returns true when the rule applies to the tile record.
function Classify.matches(rule, record)
    if string.find(record.sheet or "", "_on$") then
        return false
    end
    if (rule.floor == true) ~= (record.floor == true) then
        return false
    end
    if not rule.floor and not record.moveable then
        return false
    end
    if rule.sheet and not string.find(record.sheet or "", rule.sheet) then
        return false
    end
    if rule.container and not oneOf(record.container, rule.container) then
        return false
    end
    local name = string.lower(Classify.label(record.group, record.custom))
    if rule.has and not containsAny(name, rule.has) then
        return false
    end
    if rule.hasnt and containsAny(name, rule.hasnt) then
        return false
    end
    if rule.is and not oneOf(name, rule.is) then
        return false
    end
    return true
end

--- Returns the record's places as a list of { room, cat }, plus the name
--- the first matching rule gives unnamed tiles.
function Classify.places(record, rules)
    local out, seen, fallback = {}, {}, nil
    for _, rule in ipairs(rules or Classify.RULES) do
        if Classify.matches(rule, record) then
            fallback = fallback or rule.name
            for room, cat in pairs(rule.rooms) do
                if not seen[room] then
                    seen[room] = true
                    out[#out + 1] = { room = room, cat = cat }
                end
            end
        end
    end
    table.sort(out, function(a, b) return a.room < b.room end)
    return out, fallback
end

--- Returns a category's position in the display order (unknown ones last).
function Classify.categoryRank(cat)
    for i, c in ipairs(Classify.CATEGORIES) do
        if c == cat then
            return i
        end
    end
    return #Classify.CATEGORIES + 1
end

--- Returns the translation key for a category label.
function Classify.labelKey(cat)
    return "UI_FBR_Cat_" .. tostring(cat)
end

return Classify
