--- Guards against Kahlua quirks LuaJIT doesn't share. In the game, a call
--- that ends in a chain of tail calls can hand back extra values, and Kahlua's
--- tonumber treats any second argument as a number base and casts the first
--- argument to a string, which throws for a number.
local World = ARE_World
local Hooks = ALifeRepEditor.Hooks
local root = arg[0]:match("^(.*)/test/run%.lua$") or "."

--- Lists the mod's Lua files.
local function luaFiles()
    local files = {}
    local pipe = io.popen('find "' .. root .. '/mod" -name "*.lua"')
    for line in pipe:lines() do files[#files + 1] = line end
    pipe:close()
    return files
end

--- Runs fn with a tonumber that throws the way Kahlua's does when given two arguments.
local function withKahluaTonumber(fn)
    local real = tonumber
    tonumber = function(...)
        local value = ...
        if select("#", ...) > 1 and type(value) ~= "string" then
            error("ClassCastException: Double cannot be cast to String (tonumber)")
        end
        return real(...)
    end
    local ran, err = pcall(fn)
    tonumber = real
    if not ran then error(err, 0) end
end

test("no tonumber call takes a function call's results directly", function()
    local offenders = {}
    for _, path in ipairs(luaFiles()) do
        local number = 0
        for line in io.lines(path) do
            number = number + 1
            if string.find(line, "tonumber%(%s*[%w_%.:%[%]\"]+%s*%b()%s*%)") then
                offenders[#offenders + 1] = path:match("[^/]+$") .. ":" .. number
            end
        end
    end
    eq(#offenders, 0, "tonumber(f()) sites (wrap the call in parentheses): " .. table.concat(offenders, ", "))
end)

test("the window state builds when A-Life's opinion baseline hands back extra values", function()
    local world = World.new()
    local mate = World.addNpc("k1", "ash", "gk", "Kim")
    mate.memory.opinion = { [world.key] = { v = -30, at = 0 } }
    local baseline = ProjectALife.NpcOpinion.baseline
    ProjectALife.NpcOpinion.baseline = function(record, player) return baseline(record, player), 1 end
    local state
    local ran, err = pcall(withKahluaTonumber, function() state = Hooks.handle(world.player, "nudge", { delta = 5 }) end)
    ProjectALife.NpcOpinion.baseline = baseline
    if not ran then error(err, 0) end
    ok(not state.failed, state.message); eq(state.personal.score, 5)
end)
