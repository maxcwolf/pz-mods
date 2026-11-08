--- Minimal test runner: points require at the mod's Lua folders, then runs
--- every test file and reports failures. Run with: luajit test/run.lua
local root = arg[0]:match("^(.*)/test/run%.lua$") or "."
local lua = root .. "/mod/VehicleStorageCapacity/42/media/lua/"
package.path = lua .. "shared/?.lua;" .. lua .. "client/?.lua;" .. root .. "/test/harness/?.lua;" .. package.path
TEST_ROOT = root

local write = io.write
local passed, failed, skipped = 0, 0, 0

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

--- Records a test that cannot run on this machine.
function skip(name, reason)
    skipped = skipped + 1
    write("SKIP " .. name .. ": " .. reason .. "\n")
end

--- Asserts equality with a readable message.
function eq(actual, expected, label)
    if actual ~= expected then
        error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

--- Asserts a value is truthy.
function ok(value, label)
    if not value then
        error((label or "value") .. " should be truthy", 2)
    end
end

--- Forgets loaded mod modules so a test file can load them against fresh fakes.
function freshModules()
    for name in pairs(package.loaded) do
        if string.sub(name, 1, 22) == "VehicleStorageCapacity" then
            package.loaded[name] = nil
        end
    end
end

for _, file in ipairs({
    "settings_test", "classify_test", "capacity_test", "vehicles_test", "hooks_test",
    "translations_test", "real-scripts_test",
}) do
    dofile(root .. "/test/" .. file .. ".lua")
end
write(string.format("%d passed, %d failed, %d skipped\n", passed, failed, skipped))
if failed > 0 then
    os.exit(1)
end
