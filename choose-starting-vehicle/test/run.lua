--- Minimal test runner: points require at the mod's Lua folders, then runs
--- every test file and reports failures. Run with: luajit test/run.lua
local root = arg[0]:match("^(.*)/test/run%.lua$") or "."
local lua = root .. "/mod/ChooseStartingVehicle/42/media/lua/"
package.path = lua .. "shared/?.lua;" .. lua .. "client/?.lua;" .. package.path
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

--- Asserts two lists hold the same values in order.
function listEq(actual, expected, label)
    local a = table.concat(actual or {}, ",")
    local e = table.concat(expected or {}, ",")
    if a ~= e then
        error((label or "list") .. ": expected {" .. e .. "}, got {" .. a .. "}", 2)
    end
end

for _, file in ipairs({
    "script-text_test", "vehicle-parts_test", "catalog_test", "build_test", "placement_test",
    "plan_test", "settings_test", "items_test", "ki5-scripts_test", "apply_test", "state_test",
    "script-resolver_test", "part-models_test", "runtime_test", "follow_test", "spawn_test", "translations_test",
    "overlay_test", "preview-plan_test", "preview-watch_test", "body-model_test", "preview-slot_test", "window_test",
}) do
    dofile(root .. "/test/" .. file .. ".lua")
end
write(string.format("%d passed, %d failed, %d skipped\n", passed, failed, skipped))
if failed > 0 then
    os.exit(1)
end
