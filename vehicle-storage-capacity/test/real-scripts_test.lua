--- Classifies every storage part found in the installed game and Workshop
--- vehicle scripts (vanilla, KI5 and anything else subscribed), so a new
--- vehicle mod's naming shows up here first. Skips when the folders are missing.
local Classify = require("VehicleStorageCapacity/classify")

local HOME = os.getenv("HOME") or ""
local STEAM = HOME .. "/Library/Application Support/Steam/steamapps"
local GAME = STEAM .. "/common/ProjectZomboid/Project Zomboid.app/Contents/Java/media/scripts"
local WORKSHOP = STEAM .. "/workshop/content/108600"

--- Lists .txt files under a folder, or an empty list when it is missing.
local function textFiles(dir)
    local files = {}
    local pipe = io.popen('find "' .. dir .. '" -name "*.txt" -path "*scripts*" 2>/dev/null')
    if pipe then
        for line in pipe:lines() do
            files[#files + 1] = line
        end
        pipe:close()
    end
    return files
end

--- Returns the text between the brace at `open` and its match.
local function block(text, open)
    local depth, i = 1, open + 1
    while i <= #text and depth > 0 do
        local c = string.sub(text, i, i)
        if c == "{" then depth = depth + 1 elseif c == "}" then depth = depth - 1 end
        i = i + 1
    end
    return string.sub(text, open + 1, i - 2)
end

--- Collects item-storage parts: {id, seatNumber, itemTypes, file}.
local function storageParts(files)
    local parts = {}
    for _, path in ipairs(files) do
        local handle = io.open(path)
        local text = handle and handle:read("*a") or ""
        if handle then handle:close() end
        text = string.gsub(text, "/%*.-%*/", "")
        for start, id, open in string.gmatch(text, "()%f[%w]part%s+([%w_%*]+)%s*(){") do
            local body = block(text, open)
            local container = string.match(body, "container%s*(%b{})")
            if container and not string.find(container, "contentType", 1, true) then
                local itemTypes = {}
                local list = string.match(body, "itemType%s*=%s*([%w%._;]+)")
                for itemType in string.gmatch(list or "", "[^;]+") do
                    itemTypes[#itemTypes + 1] = itemType
                end
                local seat = string.find(container, "%f[%w]seat%s*=") and 0 or -1
                parts[#parts + 1] = { id = id, seatNumber = seat, itemTypes = itemTypes, file = path, at = start }
            end
        end
    end
    return parts
end

local files = textFiles(GAME)
for _, file in ipairs(textFiles(WORKSHOP)) do
    files[#files + 1] = file
end

if #files == 0 then
    skip("real scripts", "no game or Workshop scripts at " .. STEAM)
    return
end

local parts = storageParts(files)

test("real scripts: found the installed storage parts", function()
    ok(#parts > 100, "storage parts found: " .. #parts)
end)

test("real scripts: every storage part gets a category", function()
    local counts = { seat = 0, glovebox = 0, trunk = 0, trailer = 0 }
    for _, part in ipairs(parts) do
        local category = Classify.category(part, false)
        ok(counts[category] ~= nil, "category for " .. part.id)
        counts[category] = counts[category] + 1
    end
    ok(counts.seat > 0 and counts.glovebox > 0 and counts.trunk > 0, "seats, glove boxes and trunks all present")
end)

test("real scripts: seat containers are seats and glove boxes are glove boxes", function()
    for _, part in ipairs(parts) do
        if part.seatNumber >= 0 then
            eq(Classify.category(part, false), "seat", part.id .. " in " .. part.file)
        end
        if part.id == "GloveBox" then
            eq(Classify.category(part, false), "glovebox", part.id .. " in " .. part.file)
        end
    end
end)

test("real scripts: no trunk-like part is mistaken for a seat or glove box", function()
    for _, part in ipairs(parts) do
        local id = string.lower(part.id)
        if string.find(id, "trunk", 1, true) or string.find(id, "roofrack", 1, true)
            or string.find(id, "truckbed", 1, true) then
            eq(Classify.category(part, false), "trunk", part.id .. " in " .. part.file)
        end
    end
end)
