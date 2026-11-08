--- Holds the build being edited, the saved builds and the "spawn this on the
--- next new game" flag, and reads and writes them under ~/Zomboid/Lua.
local Build = require("ChooseStartingVehicle/build")
require "ChooseStartingVehicle/runtime"

CSV_State = CSV_State or {}

CSV_State.BUILDS_FILE = "ChooseStartingVehicle_builds.txt"
CSV_State.LAST_FILE = "ChooseStartingVehicle_last.txt"

CSV_State.build = CSV_State.build or Build.new(nil)
CSV_State.builds = CSV_State.builds or {}
CSV_State.pending = CSV_State.pending or false
CSV_State.loaded = CSV_State.loaded or false

--- Reads every line of a file under ~/Zomboid/Lua, or an empty list.
local function readLines(fileName)
    local lines = {}
    local reader = getFileReader(fileName, false)
    if not reader then
        return lines
    end
    local line = reader:readLine()
    while line ~= nil do
        lines[#lines + 1] = line
        line = reader:readLine()
    end
    reader:close()
    return lines
end

--- Replaces a file under ~/Zomboid/Lua with the given lines.
local function writeLines(fileName, lines)
    local writer = getFileWriter(fileName, true, false)
    if not writer then
        print("[ChooseStartingVehicle] cannot write " .. fileName)
        return
    end
    for _, line in ipairs(lines) do
        writer:write(line .. "\n")
    end
    writer:close()
end

--- Loads the saved builds and the last edited build once per session.
function CSV_State.load()
    if CSV_State.loaded then
        return
    end
    CSV_State.loaded = true
    CSV_State.builds = Build.parse(readLines(CSV_State.BUILDS_FILE))
    local last = CSV_State.readLast()
    if last then
        CSV_State.setBuild(last)
    end
end

--- Writes the saved builds file.
function CSV_State.saveBuilds()
    writeLines(CSV_State.BUILDS_FILE, Build.serialize(CSV_State.builds))
end

--- Remembers the build being edited so the next game starts from it; with
--- `pending` the file also tells the next new game to spawn it.
function CSV_State.saveLast(pending)
    local last = Build.clone(CSV_State.build)
    local lines
    if Build.isEmpty(last) then
        lines = { "version=" .. tostring(Build.FORMAT_VERSION) }
    else
        last.name = ""
        lines = Build.serialize({ last })
    end
    if pending then
        table.insert(lines, 2, "pending=1")
    end
    writeLines(CSV_State.LAST_FILE, lines)
end

--- Reads the last build file; returns the build (or nil) and the pending flag.
function CSV_State.readLast()
    local lines = readLines(CSV_State.LAST_FILE)
    local pending = false
    for _, line in ipairs(lines) do
        if line == "pending=1" then
            pending = true
        end
    end
    return Build.parse(lines)[1], pending
end

--- Takes the build armed at Play, from memory or from the last build file,
--- and clears the flag so it spawns once. Returns nil when nothing is armed.
function CSV_State.takePending()
    CSV_State.load()
    local build = nil
    if CSV_State.pending then
        build = Build.clone(CSV_State.build)
    else
        local last, pending = CSV_State.readLast()
        if pending and last then
            build = last
            CSV_State.build = Build.clone(last)
        end
    end
    CSV_State.pending = false
    CSV_State.saveLast(false)
    if Build.isEmpty(build) then
        return nil
    end
    return build
end

--- Replaces the build being edited, dropping choices that no longer exist.
--- Returns the notes about what was dropped.
function CSV_State.setBuild(build)
    local clean, notes = Build.sanitize(build, CSV_Runtime.findEntry, CSV_Runtime.itemExists)
    CSV_State.build = clean or Build.new(nil)
    if #notes > 0 then
        print("[ChooseStartingVehicle] dropped from build: " .. table.concat(notes, ", "))
    end
    return notes
end

--- Saves the current build under a name.
function CSV_State.saveAs(name)
    Build.upsert(CSV_State.builds, name, CSV_State.build)
    CSV_State.saveBuilds()
end

--- Loads a saved build by name; returns the dropped-choice notes or nil.
function CSV_State.loadNamed(name)
    local index = Build.indexOf(CSV_State.builds, name)
    if not index then
        return nil
    end
    return CSV_State.setBuild(CSV_State.builds[index])
end

--- Deletes a saved build by name.
function CSV_State.deleteNamed(name)
    Build.remove(CSV_State.builds, name)
    CSV_State.saveBuilds()
end

--- Called when Play is pressed: remember the build and arm the spawn.
function CSV_State.markPending()
    CSV_State.pending = not Build.isEmpty(CSV_State.build)
    CSV_State.saveLast(CSV_State.pending)
end
