--- Turns plain Lua values (strings, numbers, booleans and tables of them)
--- into one line of text and back. Blueprint files and save data use it, so
--- nothing is ever loaded as code. Output is deterministic: map keys are
--- sorted, so the same value always gives the same text.
local Codec = {}

local IDENT = "^[%a_][%w_]*$"

--- Escapes a string for a quoted literal.
local function quote(s)
    s = string.gsub(s, "\\", "\\\\")
    s = string.gsub(s, "\"", "\\\"")
    s = string.gsub(s, "\n", "\\n")
    s = string.gsub(s, "\r", "\\r")
    s = string.gsub(s, "\t", "\\t")
    return "\"" .. s .. "\""
end

--- Returns the length of the array part (1..n with no gaps).
local function arrayLength(t)
    local n = 0
    while t[n + 1] ~= nil do
        n = n + 1
    end
    return n
end

--- Orders map keys: numbers first, then strings.
local function keyLess(a, b)
    local ta, tb = type(a), type(b)
    if ta ~= tb then
        return ta == "number"
    end
    return a < b
end

local encodeValue

--- Encodes a table: array values first, then sorted key=value pairs.
local function encodeTable(t, depth)
    if depth > 40 then
        error("Codec: table nested too deeply")
    end
    local parts = {}
    local n = arrayLength(t)
    for i = 1, n do
        parts[#parts + 1] = encodeValue(t[i], depth + 1)
    end
    local keys = {}
    for k, v in pairs(t) do
        local isArray = type(k) == "number" and k >= 1 and k <= n and k == math.floor(k)
        local storable = type(v) == "string" or type(v) == "number" or type(v) == "boolean" or type(v) == "table"
        if not isArray and storable and (type(k) == "string" or type(k) == "number") then
            keys[#keys + 1] = k
        end
    end
    table.sort(keys, keyLess)
    for _, k in ipairs(keys) do
        local key
        if type(k) == "number" then
            key = "[" .. tostring(k) .. "]"
        elseif string.find(k, IDENT) and k ~= "true" and k ~= "false" then
            key = k
        else
            key = "[" .. quote(k) .. "]"
        end
        parts[#parts + 1] = key .. "=" .. encodeValue(t[k], depth + 1)
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

--- Encodes any supported value.
encodeValue = function(v, depth)
    local tv = type(v)
    if tv == "string" then
        return quote(v)
    elseif tv == "number" then
        if v ~= v or v == math.huge or v == -math.huge then
            return "0"
        end
        return tostring(v)
    elseif tv == "boolean" then
        return v and "true" or "false"
    elseif tv == "table" then
        return encodeTable(v, depth)
    end
    return "false"
end

--- Encodes a value to one line of text.
function Codec.encode(value)
    return encodeValue(value, 0)
end

local ESCAPES = { n = "\n", r = "\r", t = "\t", ["\\"] = "\\", ["\""] = "\"" }

--- Reads a quoted string starting at pos (on the opening quote).
local function readString(text, pos)
    local out = {}
    local i = pos + 1
    local len = #text
    while i <= len do
        local c = string.sub(text, i, i)
        if c == "\"" then
            return table.concat(out), i + 1
        elseif c == "\\" then
            local e = string.sub(text, i + 1, i + 1)
            out[#out + 1] = ESCAPES[e] or e
            i = i + 2
        else
            local stop = string.find(text, "[\"\\]", i)
            if not stop then
                break
            end
            out[#out + 1] = string.sub(text, i, stop - 1)
            i = stop
        end
    end
    error("Codec: unterminated string at " .. pos)
end

local readValue

--- Reads a table starting at pos (on the opening brace).
local function readTable(text, pos)
    local t = {}
    local n = 0
    local i = pos + 1
    if string.sub(text, i, i) == "}" then
        return t, i + 1
    end
    while true do
        local c = string.sub(text, i, i)
        local key
        if c == "[" then
            local k, after = readValue(text, i + 1)
            if string.sub(text, after, after + 1) ~= "]=" then
                error("Codec: expected ]= at " .. after)
            end
            key = k
            i = after + 2
        else
            local s, e = string.find(text, "^[%a_][%w_]*=", i)
            if s and not (string.sub(text, i, e - 1) == "true" or string.sub(text, i, e - 1) == "false") then
                key = string.sub(text, i, e - 1)
                i = e + 1
            end
        end
        local value
        value, i = readValue(text, i)
        if key == nil then
            n = n + 1
            t[n] = value
        else
            t[key] = value
        end
        local sep = string.sub(text, i, i)
        if sep == "," then
            i = i + 1
        elseif sep == "}" then
            return t, i + 1
        else
            error("Codec: expected , or } at " .. i)
        end
    end
end

--- Reads any value starting at pos.
readValue = function(text, pos)
    local c = string.sub(text, pos, pos)
    if c == "\"" then
        return readString(text, pos)
    elseif c == "{" then
        return readTable(text, pos)
    elseif string.sub(text, pos, pos + 3) == "true" then
        return true, pos + 4
    elseif string.sub(text, pos, pos + 4) == "false" then
        return false, pos + 5
    end
    local s, e = string.find(text, "^[-+%deE%.]+", pos)
    if s then
        local number = tonumber(string.sub(text, s, e))
        if number then
            return number, e + 1
        end
    end
    error("Codec: unexpected '" .. c .. "' at " .. pos)
end

--- Decodes one line of text. Returns the value, or nil and an error.
function Codec.decode(text)
    if type(text) ~= "string" or text == "" then
        return nil, "empty"
    end
    local ok, value, after = pcall(readValue, text, 1)
    if not ok then
        return nil, tostring(value)
    end
    if after <= #text then
        return nil, "trailing text at " .. after
    end
    return value
end

--- Returns a deep copy holding only storable values (drops functions, Java
--- objects and anything nested deeper than the limit).
function Codec.plain(value, depth)
    depth = depth or 0
    local tv = type(value)
    if tv == "string" or tv == "boolean" then
        return value
    elseif tv == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            return nil
        end
        return value
    elseif tv == "table" and depth < 12 then
        local copy = {}
        for k, v in pairs(value) do
            if type(k) == "string" or type(k) == "number" then
                local inner = Codec.plain(v, depth + 1)
                if inner ~= nil then
                    copy[k] = inner
                end
            end
        end
        return copy
    end
    return nil
end

return Codec
