--- Session state: the current selection, the lazily built item catalog, the
--- remembered last selection on disk, the gear saved with each vanilla build,
--- and the flag that tells the spawn code a selection is waiting to be applied.
require "ChooseStartingGear/runtime"
require "ChooseStartingGear/builds"

CSG_State = CSG_State or {}
local State = CSG_State

State.selection = State.selection or CSG_Selection.new()
State.entries = State.entries or nil
State.entryMap = State.entryMap or nil
State.weaponEntries = State.weaponEntries or nil
State.build = nil
State.pending = State.pending or false
State.loaded = State.loaded or false
State.wornAtPlay = State.wornAtPlay or nil

local FILE = "ChooseStartingGear_last.txt"
local BUILDS_FILE = "ChooseStartingGear_builds.txt"
local CHUNK = 250

--- Starts the incremental catalog build if it has not started yet.
function State.beginCatalog()
    if State.entries or State.build then
        return
    end
    State.build = { all = getScriptManager():getAllItems(), index = 0, raws = {} }
end

--- Processes up to `count` script items; returns true once the catalog is ready.
function State.stepCatalog(count)
    if State.entries then
        return true
    end
    State.beginCatalog()
    local build = State.build
    local total = build.all:size()
    local stop = math.min(total, build.index + (count or CHUNK))
    while build.index < stop do
        local ok, raw = pcall(CSG_Runtime.rawItem, build.all:get(build.index))
        if ok and raw then
            table.insert(build.raws, raw)
        end
        build.index = build.index + 1
    end
    if build.index >= total then
        State.entries = CSG_Catalog.buildEntries(build.raws)
        State.entryMap = CSG_Catalog.byFullType(State.entries)
        State.weaponEntries = {}
        for _, entry in ipairs(State.entries) do
            if entry.isWeapon then
                table.insert(State.weaponEntries, entry)
            end
        end
        State.build = nil
        CSG_Selection.pruneUnknown(State.selection, State.isKnown)
        print("[ChooseStartingGear] catalog ready: " .. tostring(#State.entries) .. " items")
        return true
    end
    return false
end

--- Finishes the catalog build synchronously.
function State.finishCatalog()
    while not State.stepCatalog(100000) do end
end

--- Returns true when the catalog can be queried.
function State.catalogReady()
    return State.entries ~= nil
end

--- Returns build progress from 0 to 1.
function State.catalogProgress()
    if State.entries then
        return 1
    end
    if not State.build then
        return 0
    end
    local total = State.build.all:size()
    if total == 0 then
        return 1
    end
    return State.build.index / total
end

--- Returns the catalog entry for a full type, or nil.
function State.entry(fullType)
    return State.entryMap and State.entryMap[fullType] or nil
end

--- Returns true when the full type is in the catalog.
function State.isKnown(fullType)
    return State.entry(fullType) ~= nil
end

--- Returns the weight of one item of the given type.
function State.weightOf(fullType)
    local entry = State.entry(fullType)
    return entry and entry.weight or 0
end

--- Saves the current selection to the player's Zomboid/Lua folder.
function State.save()
    local writer = getFileWriter(FILE, true, false)
    if not writer then
        return
    end
    writer:write(CSG_Selection.serialize(State.selection))
    writer:close()
end

--- Reads a whole file from the player's Zomboid/Lua folder, or nil when it
--- does not exist.
local function readFile(name)
    local reader = getFileReader(name, false)
    if not reader then
        return nil
    end
    local lines = {}
    local line = reader:readLine()
    while line do
        table.insert(lines, line)
        line = reader:readLine()
    end
    reader:close()
    return table.concat(lines, "\n")
end

--- Loads the last saved selection, once per game session.
function State.load()
    if State.loaded then
        return
    end
    State.loaded = true
    local text = readFile(FILE)
    if not text then
        return
    end
    State.selection = CSG_Selection.deserialize(text)
    if State.entries then
        CSG_Selection.pruneUnknown(State.selection, State.isKnown)
    end
end

--- Replaces the current selection and remembers it as the last one.
function State.replaceSelection(selection)
    State.selection = selection
    if State.entries then
        CSG_Selection.pruneUnknown(State.selection, State.isKnown)
    end
    State.save()
end

--- Returns the gear saved with every vanilla build, name -> selection.
function State.readBuilds()
    return CSG_Builds.deserializeGear(readFile(BUILDS_FILE))
end

--- Writes the gear of every vanilla build.
local function writeBuilds(gearByName)
    local writer = getFileWriter(BUILDS_FILE, true, false)
    if not writer then
        return
    end
    writer:write(CSG_Builds.serializeGear(gearByName))
    writer:close()
end

--- Stores the current selection as the gear of a vanilla build.
function State.saveBuild(name)
    local builds = State.readBuilds()
    builds[name] = CSG_Selection.deserialize(CSG_Selection.serialize(State.selection))
    writeBuilds(builds)
end

--- Makes a vanilla build's gear the current selection; returns false when
--- that build has no gear saved, in which case the selection is left alone.
function State.loadBuild(name)
    local gear = State.readBuilds()[name]
    if not gear then
        return false
    end
    State.replaceSelection(gear)
    return true
end

--- Forgets the gear of a vanilla build.
function State.deleteBuild(name)
    local builds = State.readBuilds()
    if builds[name] == nil then
        return
    end
    builds[name] = nil
    writeBuilds(builds)
end

--- Forgets every chosen item.
function State.reset()
    State.selection = CSG_Selection.new()
    State.save()
end

--- Called when Play is pressed: persists the selection, remembers what the
--- character wears (the screen's desc is gone by the time the player spawns)
--- and arms the spawn hook.
function State.markPending()
    State.pending = not CSG_Selection.isEmpty(State.selection)
    local desc = MainScreen and MainScreen.instance and MainScreen.instance.desc
    State.wornAtPlay = desc and CSG_Runtime.wornTypes(desc) or nil
    State.save()
end
