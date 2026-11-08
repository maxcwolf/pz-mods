--- The game's translator runs every string through a Java format call, so a
--- bare "%" (one not starting a %1-style placeholder) throws
--- UnknownFormatConversionException and the label never shows. Every
--- sandbox option also needs a label and a tooltip.
local MOD = TEST_ROOT .. "/mod/VehicleStorageCapacity/42/media/"

--- Reads a whole file.
local function read(path)
    local handle = assert(io.open(path))
    local text = handle:read("*a")
    handle:close()
    return text
end

local sandbox = read(MOD .. "lua/shared/Translate/EN/Sandbox.json")

test("translations: no bare percent signs", function()
    local bad = {}
    for value in string.gmatch(sandbox, ':%s*"(.-)"') do
        if string.find(string.gsub(value, "%%%d", ""), "%", 1, true) then
            bad[#bad + 1] = value
        end
    end
    eq(#bad, 0, "bare % in: " .. table.concat(bad, " | "))
end)

test("translations: every sandbox option has a label and a tooltip", function()
    local options = read(MOD .. "sandbox-options.txt")
    local count = 0
    for key in string.gmatch(options, "translation%s*=%s*([%w_]+)") do
        count = count + 1
        ok(string.find(sandbox, '"Sandbox_' .. key .. '"', 1, true), "label for " .. key)
        ok(string.find(sandbox, '"Sandbox_' .. key .. '_tooltip"', 1, true), "tooltip for " .. key)
    end
    eq(count, 4, "options")
    ok(string.find(sandbox, '"Sandbox_VehicleStorageCapacity"', 1, true), "page name")
end)

test("translations: option names match what settings.lua reads", function()
    local options = read(MOD .. "sandbox-options.txt")
    for _, name in ipairs({ "TrunkPercent", "SeatPercent", "GloveBoxPercent", "TrailerPercent" }) do
        ok(string.find(options, "option VehicleStorageCapacity." .. name, 1, true), name)
    end
end)

test("sandbox options: minimum is 1 so typing a value never passes through an invalid one", function()
    local options = read(MOD .. "sandbox-options.txt")
    local count = 0
    for min in string.gmatch(options, "min%s*=%s*(%d+)") do
        count = count + 1
        eq(min, "1", "min")
    end
    eq(count, 4, "options with a min")
end)
