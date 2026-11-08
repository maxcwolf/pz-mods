--- Minimal test runner: loads the game stubs and the mod modules, then every
--- test file, and reports failures. Run with: luajit test/run.lua
local root = arg[0]:match("^(.*)/test/run%.lua$") or "."
local client = root .. "/mod/ClockAlarmShortcut/42/media/lua/client/ClockAlarmShortcut/"

local realPrint = print
PZ_Stubs = dofile(root .. "/test/harness/pz-stubs.lua")
for _, name in ipairs({ "bell-layout", "alarm-finder", "bell-overlay" }) do
    dofile(client .. name .. ".lua")
end

local passed, failed = 0, 0

--- Registers and immediately runs one named test on fresh fake game state.
function test(name, fn)
    PZ_Stubs.reset()
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        realPrint("FAIL " .. name .. "\n  " .. tostring(err))
    end
end

--- Asserts equality with a readable message.
function eq(actual, expected, label)
    if actual ~= expected then
        error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

for _, file in ipairs({ "bell-layout_test", "alarm-finder_test", "bell-overlay_test" }) do
    dofile(root .. "/test/" .. file .. ".lua")
end
realPrint(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
