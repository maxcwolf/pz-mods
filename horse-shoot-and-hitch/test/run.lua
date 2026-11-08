--- Minimal test runner: points require at the mod's shared Lua folder, then runs
--- every test file and reports failures. Run with: luajit test/run.lua
local root = arg[0]:match("^(.*)/test/run%.lua$") or "."
local lua = root .. "/mod/HorseShootAndHitch/42/media/lua/"
package.path = lua .. "shared/?.lua;" .. lua .. "client/?.lua;" .. package.path

local write = io.write
HSH_Stubs = dofile(root .. "/test/harness/pz-stubs.lua")

local passed, failed = 0, 0

--- Registers and immediately runs one named test.
function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        write("FAIL " .. name .. "\n  " .. tostring(err) .. "\n")
    end
end

--- Asserts equality with a readable message.
function eq(actual, expected, label)
    if actual ~= expected then
        error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

--- Asserts two numbers are within a small tolerance.
function near(actual, expected, label)
    if math.abs(actual - expected) > 1e-6 then
        error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

for _, file in ipairs({ "mounted-aim_test", "tether_test", "settings_test", "tether-world_test", "mounted-shooting_test", "tie-menu_test" }) do
    dofile(root .. "/test/" .. file .. ".lua")
end
write(string.format("%d passed, %d failed\n", passed, failed))
if failed > 0 then os.exit(1) end
