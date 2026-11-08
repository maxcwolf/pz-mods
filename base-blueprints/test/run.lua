--- Minimal test runner: points require at the mod's Lua folders, then runs
--- every test file and reports failures. Run with: luajit test/run.lua
local root = arg[0]:match("^(.*)/test/run%.lua$") or "."
local lua = root .. "/mod/BaseBlueprints/42/media/lua/"
package.path = lua .. "shared/?.lua;" .. lua .. "client/?.lua;" .. root .. "/test/harness/?.lua;" .. package.path
TEST_ROOT = root

local write = io.write
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

--- Asserts a value is truthy.
function ok(value, label)
    if not value then
        error((label or "value") .. " should be truthy", 2)
    end
end

--- Forgets loaded mod modules so a test file can load them against fresh fakes.
function freshModules()
    for name in pairs(package.loaded) do
        if string.sub(name, 1, 14) == "BaseBlueprints" then
            package.loaded[name] = nil
        end
    end
end

for _, file in ipairs({
    "codec_test", "keys_test", "classify_test", "signature_test", "diff_test", "rects_test",
    "area_test", "factory_test", "blueprint_test", "library_test", "pending_test",
    "capture_test", "apply_test", "runtime_test", "window_test", "translations_test",
}) do
    dofile(root .. "/test/" .. file .. ".lua")
end
write(string.format("%d passed, %d failed\n", passed, failed))
if failed > 0 then
    os.exit(1)
end
