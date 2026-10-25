--- Minimal test runner: loads the shared mod modules, then every test/*_test.lua
--- file, and reports failures. Run with: luajit test/run.lua
local root = arg[0]:match("^(.*)/test/run%.lua$") or "."
local shared = root .. "/mod/ChooseStartingGear/42/media/lua/shared/ChooseStartingGear/"
for _, name in ipairs({ "slot-logic", "catalog", "selection", "plan" }) do
    dofile(shared .. name .. ".lua")
end

local passed, failed = 0, 0
local current = ""

--- Registers and immediately runs one named test.
function test(name, fn)
    current = name
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL " .. name .. "\n  " .. tostring(err))
    end
end

--- Asserts equality with a readable message.
function eq(actual, expected, label)
    if actual ~= expected then
        error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local files = { "slot-logic_test", "catalog_test", "selection_test", "plan_test", "client-smoke_test" }
for _, file in ipairs(files) do
    dofile(root .. "/test/" .. file .. ".lua")
end
print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
