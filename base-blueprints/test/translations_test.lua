--- The game's translator runs every string through a Java format call, so a
--- bare "%" (one not starting a %1-style placeholder) throws
--- UnknownFormatConversionException and the label never shows.
local DIR = TEST_ROOT .. "/mod/BaseBlueprints/42/media/lua/shared/Translate/EN/"

for _, name in ipairs({ "UI.json" }) do
    test("translations: " .. name .. " has no bare percent signs", function()
        local handle = assert(io.open(DIR .. name))
        local bad = {}
        for line in handle:lines() do
            local value = string.match(line, ':%s*"(.*)"')
            if value and string.find(string.gsub(value, "%%%d", ""), "%", 1, true) then
                bad[#bad + 1] = value
            end
        end
        handle:close()
        eq(#bad, 0, "bare % in: " .. table.concat(bad, " | "))
    end)
end
