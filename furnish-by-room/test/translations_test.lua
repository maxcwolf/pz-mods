--- The translation file: no bare "%" (the game's formatter throws on one)
--- and every UI_FBR_ key the code asks for exists.
local DIR = TEST_ROOT .. "/mod/FurnishByRoom/42/media/lua/"

--- Returns the file's text.
local function read(path)
    local handle = assert(io.open(path))
    local text = handle:read("*a")
    handle:close()
    return text
end

local json = read(DIR .. "shared/Translate/EN/UI.json")

test("translations: no bare percent signs", function()
    local bad = {}
    for value in string.gmatch(json, ':%s*"(.-)"%s*[,}\n]') do
        if string.find(string.gsub(value, "%%%d", ""), "%", 1, true) then
            bad[#bad + 1] = value
        end
    end
    eq(#bad, 0, "bare % in: " .. table.concat(bad, " | "))
end)

test("translations: every key the code uses exists", function()
    local keys = {}
    for key in string.gmatch(json, '"(UI_FBR_[%w_]+)"%s*:') do
        keys[key] = true
    end
    local Rooms = require("FurnishByRoom/rooms")
    local Classify = require("FurnishByRoom/classify")
    local needed = {}
    for _, room in ipairs(Rooms.ORDER) do needed[#needed + 1] = Rooms.labelKey(room) end
    for _, cat in ipairs(Classify.CATEGORIES) do needed[#needed + 1] = Classify.labelKey(cat) end
    for _, mode in ipairs({ "place", "floor", "remove", "strip" }) do needed[#needed + 1] = "UI_FBR_Hint_" .. mode end
    for _, kind in ipairs({ "place", "floor", "remove" }) do needed[#needed + 1] = "UI_FBR_Undone_" .. kind end
    needed[#needed + 1] = "UI_FBR_Cat_all"
    for _, file in ipairs({ "CatalogWindow", "ItemGrid", "ItemStrip", "PlacingChip", "controller", "menu", "options" }) do
        for key in string.gmatch(read(DIR .. "client/FurnishByRoom/" .. file .. ".lua"), '"(UI_FBR_[%w_]+)"') do
            if string.sub(key, -1) ~= "_" then
                needed[#needed + 1] = key
            end
        end
    end
    local missing = {}
    for _, key in ipairs(needed) do
        if not keys[key] then missing[#missing + 1] = key end
    end
    eq(#missing, 0, "missing: " .. table.concat(missing, ", "))
end)
