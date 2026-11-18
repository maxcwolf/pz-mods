--- Checks that every text key the mod asks for is in its English translation files.
require "ALifeRepEditor/crew-rows"
local root = arg[0]:match("^(.*)/test/run%.lua$") or "."
local translate = root .. "/mod/ALifeRepEditor/42/media/lua/shared/Translate/EN/"

--- Returns the set of keys defined in the English translation files.
local function definedKeys()
    local keys = {}
    for _, name in ipairs({ "UI.json", "ContextMenu.json", "Sandbox.json" }) do
        local file = io.open(translate .. name, "r")
        if file ~= nil then
            for key in file:read("*a"):gmatch('"([%w_]+)"%s*:') do keys[key] = true end
            file:close()
        end
    end
    return keys
end

test("every getText key the mod uses is translated", function()
    local keys, missing = definedKeys(), {}
    local pipe = io.popen('grep -rhoE \'getText\\("[A-Za-z_]+"\' "' .. root .. '/mod"')
    for line in pipe:lines() do
        local key = line:match('"([%w_]+)"')
        if key ~= nil and key:sub(-1) ~= "_" and not keys[key] then missing[#missing + 1] = key end
    end
    pipe:close()
    for _, id in ipairs(ALifeRepEditor.CrewRows.SKILLS) do
        if not keys["UI_ALifeRepEditor_Skill_" .. id] then missing[#missing + 1] = "UI_ALifeRepEditor_Skill_" .. id end
    end
    for _, id in ipairs(ALifeRepEditor.CrewRows.RATINGS) do
        if not keys["UI_ALifeRepEditor_Rating_" .. id] then missing[#missing + 1] = "UI_ALifeRepEditor_Rating_" .. id end
    end
    eq(#missing, 0, "missing translations: " .. table.concat(missing, ", "))
end)
