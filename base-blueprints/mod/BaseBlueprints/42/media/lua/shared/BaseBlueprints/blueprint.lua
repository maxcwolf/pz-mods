--- A saved base: what each square in it should hold. Stored as text lines,
--- one header, one line of details, then one line per square.
local Codec = require("BaseBlueprints/codec")
local Keys = require("BaseBlueprints/keys")
local Area = require("BaseBlueprints/area")

local Blueprint = {}

Blueprint.HEADER = "BaseBlueprints 1"
Blueprint.MAX_NAME = 48

--- Trims a name and limits its length; falls back to "Base".
function Blueprint.cleanName(name)
    name = string.gsub(tostring(name or ""), "[%c]", " ")
    name = string.match(name, "^%s*(.-)%s*$") or ""
    if #name > Blueprint.MAX_NAME then
        name = string.sub(name, 1, Blueprint.MAX_NAME)
    end
    if name == "" then
        name = "Base"
    end
    return name
end

--- Makes a file-safe id from a name and a time stamp number.
function Blueprint.makeId(name, stamp)
    local slug = string.lower(Blueprint.cleanName(name))
    slug = string.gsub(slug, "[^%w]+", "-")
    slug = string.gsub(slug, "^%-+", "")
    slug = string.gsub(slug, "%-+$", "")
    if slug == "" then
        slug = "base"
    end
    return string.sub(slug, 1, 24) .. "-" .. string.format("%d", math.floor(stamp or 0))
end

--- Copies records, dropping saved container contents.
function Blueprint.withoutContents(records)
    local copy = {}
    for i, record in ipairs(records) do
        local r = {}
        for k, v in pairs(record) do
            if k ~= "containers" then
                r[k] = v
            end
        end
        copy[i] = r
    end
    return copy
end

--- Counts squares, objects and containers with saved contents.
function Blueprint.count(squares)
    local nSquares, nObjects, nContents = 0, 0, 0
    for _, records in pairs(squares) do
        nSquares = nSquares + 1
        nObjects = nObjects + #records
        for _, record in ipairs(records) do
            if record.containers and #record.containers > 0 then
                nContents = nContents + 1
            end
        end
    end
    return nSquares, nObjects, nContents
end

--- Makes a blueprint from details and squares (key -> records).
function Blueprint.new(meta, squares)
    local nSquares, nObjects, nContents = Blueprint.count(squares)
    local m = {}
    for k, v in pairs(meta) do
        m[k] = v
    end
    m.name = Blueprint.cleanName(m.name)
    m.squares = nSquares
    m.objects = nObjects
    m.contents = nContents > 0
    return { meta = m, squares = squares }
end

--- Returns the text lines for a blueprint file.
function Blueprint.toLines(bp)
    local lines = { Blueprint.HEADER, Codec.encode(bp.meta) }
    for _, key in ipairs(Keys.sorted(bp.squares)) do
        lines[#lines + 1] = key .. "\t" .. Codec.encode(bp.squares[key])
    end
    return lines
end

--- Reads a blueprint from text lines. Returns it, or nil and a reason.
function Blueprint.fromLines(lines)
    if not lines or lines[1] ~= Blueprint.HEADER then
        return nil, "not a blueprint file"
    end
    local meta, err = Codec.decode(lines[2])
    if type(meta) ~= "table" then
        return nil, "bad details: " .. tostring(err)
    end
    if not Area.isValid(meta.area) then
        return nil, "bad area"
    end
    local squares = {}
    for i = 3, #lines do
        local line = lines[i]
        if line ~= "" then
            local key, body = string.match(line, "^([^\t]+)\t(.*)$")
            if not key or not Keys.parse(key) then
                return nil, "bad square line " .. i
            end
            local records, recErr = Codec.decode(body)
            if type(records) ~= "table" then
                return nil, "bad square " .. key .. ": " .. tostring(recErr)
            end
            squares[key] = records
        end
    end
    return { meta = meta, squares = squares }
end

--- Returns the squares to apply, without contents unless asked for.
function Blueprint.squaresToApply(bp, withContents)
    local out = {}
    for key, records in pairs(bp.squares) do
        out[key] = withContents and records or Blueprint.withoutContents(records)
    end
    return out
end

return Blueprint
