--- Loads the real vehicle scripts installed on this machine (Steam workshop
--- KI5 mods plus the game's own) the way the game would pick them: each mod's
--- highest 42.x folder that is not newer than the game, plus its common folder.
--- Returns nil when the game is not installed here.
local ScriptText = require("ChooseStartingVehicle/script-text")

local RealScripts = {}

local HOME = os.getenv("HOME") or ""
RealScripts.STEAM = HOME .. "/Library/Application Support/Steam/steamapps"
RealScripts.WORKSHOP = RealScripts.STEAM .. "/workshop/content/108600"
RealScripts.GAME_SCRIPTS = RealScripts.STEAM .. "/common/ProjectZomboid/Project Zomboid.app/Contents/Java/media/scripts/generated/vehicles"
local VERSION_FOLDERS = { "42", "42.0", "42.13", "42.17", "42.20" }

--- Runs a shell command and returns its output lines.
local function lines(command)
    local out = {}
    local pipe = io.popen(command)
    if not pipe then
        return out
    end
    for line in pipe:lines() do
        out[#out + 1] = line
    end
    pipe:close()
    return out
end

--- Quotes a path for the shell.
local function q(path)
    return "'" .. string.gsub(path, "'", "'\\''") .. "'"
end

--- True when a directory exists.
local function isDir(path)
    return #lines("test -d " .. q(path) .. " && echo y") > 0
end

--- Lists the vehicle script files of one mod folder (mods/<id>/).
local function modFiles(modDir)
    local files = {}
    local best = nil
    for _, v in ipairs(VERSION_FOLDERS) do
        if isDir(modDir .. "/" .. v .. "/media/scripts") then
            best = modDir .. "/" .. v
        end
    end
    for _, dir in ipairs({ best, modDir .. "/common" }) do
        if dir and isDir(dir .. "/media/scripts") then
            for _, f in ipairs(lines("grep -rlE '^[[:space:]]*(template[[:space:]]+)?vehicle ' " .. q(dir .. "/media/scripts"))) do
                files[#files + 1] = f
            end
        end
    end
    return files
end

--- Loads every template and vehicle block; returns {templates, vehicles, order, modOf}.
function RealScripts.load()
    if not isDir(RealScripts.WORKSHOP) then
        return nil
    end
    local result = { templates = {}, vehicles = {}, order = {}, modOf = {} }
    local function addFile(path, modId)
        local f = io.open(path)
        if not f then
            return
        end
        local text = f:read("*a")
        f:close()
        local function walk(block)
            for _, item in ipairs(block.items) do
                local b = item.block
                if b then
                    if b.kind == "template" and b.words[2] == "vehicle" then
                        result.templates[b.name] = b
                    elseif b.kind == "vehicle" then
                        if not result.vehicles[b.name] then
                            result.vehicles[b.name] = {}
                            result.order[#result.order + 1] = b.name
                            result.modOf[b.name] = modId
                        end
                        table.insert(result.vehicles[b.name], b)
                    elseif b.kind == "module" then
                        walk(b)
                    end
                end
            end
        end
        walk(ScriptText.parse(text))
    end
    for _, f in ipairs(lines("find " .. q(RealScripts.GAME_SCRIPTS) .. " -name '*.txt' 2>/dev/null | sort")) do
        addFile(f, "pz-vanilla")
    end
    for _, modDir in ipairs(lines("ls -d " .. q(RealScripts.WORKSHOP) .. "/*/mods/*/ 2>/dev/null | sort")) do
        modDir = string.gsub(modDir, "/$", "")
        local modId = string.match(modDir, "([^/]+)$")
        for _, f in ipairs(modFiles(modDir)) do
            addFile(f, modId)
        end
    end
    return result
end

return RealScripts
