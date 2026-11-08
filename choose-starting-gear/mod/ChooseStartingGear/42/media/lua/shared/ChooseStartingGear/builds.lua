--- Pure helpers for the vanilla saved-builds file and for the mod's own
--- per-build gear file. Vanilla splits each saved line on every colon, which
--- truncates builds that wear modded clothing whose body-location keys carry
--- a namespace such as "alicesweaponsling:slingback"; the parser here splits
--- at the first colon only.
local Builds = {}

Builds.OUTFITS_VERSION = 1

--- Parses the lines of vanilla's saved_outfits.txt into name -> build string,
--- keeping only builds written under the version this parser understands.
function Builds.parseOutfitLines(lines)
    local builds = {}
    local version = 0
    for _, line in ipairs(lines or {}) do
        local header = string.match(line, "^VERSION=(%d+)")
        if header then
            version = tonumber(header)
        elseif version == Builds.OUTFITS_VERSION then
            local name, value = string.match(line, "^([^:]+):(.*)$")
            if name and name ~= "" then
                builds[name] = value
            end
        end
    end
    return builds
end

--- Returns the sorted keys of a table, for deterministic output.
local function sortedKeys(t)
    local keys = {}
    for k in pairs(t) do
        table.insert(keys, k)
    end
    table.sort(keys)
    return keys
end

--- Serializes name -> selection into one text: a "build" header line per
--- build followed by that build's selection lines.
function Builds.serializeGear(gearByName)
    local lines = {}
    for _, name in ipairs(sortedKeys(gearByName)) do
        table.insert(lines, "build\t" .. name)
        local body = CSG_Selection.serialize(gearByName[name])
        if body ~= "" then
            table.insert(lines, body)
        end
    end
    return table.concat(lines, "\n")
end

--- Parses text produced by serializeGear back into name -> selection.
function Builds.deserializeGear(text)
    local gearByName = {}
    local name = nil
    local body = {}
    local function flush()
        if name then
            gearByName[name] = CSG_Selection.deserialize(table.concat(body, "\n"))
        end
        body = {}
    end
    for line in string.gmatch(text or "", "[^\r\n]+") do
        local header = string.match(line, "^build\t(.+)$")
        if header then
            flush()
            name = header
        elseif name then
            table.insert(body, line)
        end
    end
    flush()
    return gearByName
end

CSG_Builds = Builds
return Builds
