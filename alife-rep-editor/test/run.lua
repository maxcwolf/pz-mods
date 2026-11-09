--- Minimal test runner: points require at the mod's Lua folders and at the
--- installed Project A-Life mod, then runs every test file and reports
--- failures. Run with: luajit test/run.lua (set ALIFE_LUA to override A-Life's path).
local root = arg[0]:match("^(.*)/test/run%.lua$") or "."
local lua = root .. "/mod/ALifeRepEditor/42/media/lua/"
local home = os.getenv("HOME") or ""
local alife = os.getenv("ALIFE_LUA") or (home .. "/Library/Application Support/Steam/steamapps/workshop/content/108600/"
    .. "3803984183/mods/ProjectALifeNPCs/42.20/media/lua")
package.path = lua .. "shared/?.lua;" .. lua .. "server/?.lua;" .. lua .. "client/?.lua;" .. package.path

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

--- Asserts a condition with a readable message.
function ok(condition, label)
    if not condition then error((label or "condition") .. " was false", 2) end
end

for _, file in ipairs({ "score_test", "kill-ledger_test", "faction-restore_test", "pause_test", "permissions_test",
    "faction-rows_test", "hud-prefs_test", "look_test" }) do
    dofile(root .. "/test/" .. file .. ".lua")
end

local probe = io.open(alife .. "/server/ProjectALife/Decisions/ALifeReputation.lua", "r")
if probe ~= nil then
    probe:close()
    package.path = alife .. "/shared/?.lua;" .. alife .. "/server/?.lua;" .. package.path
    function isClient() return false end
    function isServer() return false end
    print = function() end
    require "ALifeRepEditor/hooks"
    ARE_World = dofile(root .. "/test/harness/alife-world.lua")
    ARE_UI = dofile(root .. "/test/harness/ui-stubs.lua")
    for _, file in ipairs({ "editor_test", "hooks_test", "ui_test", "kahlua_test" }) do
        dofile(root .. "/test/" .. file .. ".lua")
    end
else
    write("SKIP editor and hooks tests: Project A-Life not found at " .. alife .. "\n")
end

write(string.format("%d passed, %d failed\n", passed, failed))
if failed > 0 then os.exit(1) end
