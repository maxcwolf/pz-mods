--- The mod's actions: claim a building, find what changed, save a
--- blueprint, list, delete and apply blueprints. Blueprint files live in
--- ~/Zomboid/Lua; the claim and the squares still waiting to be applied live
--- in the save's mod data.
local Area = require("BaseBlueprints/area")
local Blueprint = require("BaseBlueprints/blueprint")
local Capture = require("BaseBlueprints/capture")
local Diff = require("BaseBlueprints/diff")
local Files = require("BaseBlueprints/files")
local Keys = require("BaseBlueprints/keys")
local Library = require("BaseBlueprints/library")
local Pending = require("BaseBlueprints/pending")
local Apply = require("BaseBlueprints/apply")

local Runtime = {}

--- Formats a number for game text (the translator would print 12.0).
function Runtime.int(value)
    return string.format("%d", math.floor(tonumber(value) or 0))
end

Runtime.TAG = "[BaseBlueprints]"
Runtime.cache = nil
Runtime.dirty = {}
Runtime.hasDirty = false
Runtime.changes = nil

--- Prints a tagged line to the console.
function Runtime.log(text)
    print(Runtime.TAG .. " " .. text)
end

--- Returns the save's mod data table for this mod.
function Runtime.state()
    local root = ModData.getOrCreate("BaseBlueprints")
    Pending.init(root)
    Runtime.cache = root
    return root
end

--- Returns building bounds for the building on a square, or nil.
function Runtime.buildingAt(square)
    local building = square and square:getBuilding()
    local def = building and building:getDef()
    if not def then
        return nil
    end
    return {
        x = def:getX(), y = def:getY(), w = def:getW(), h = def:getH(),
        minLevel = def:getMinLevel(), maxLevel = def:getMaxLevel(),
    }
end

--- Returns the current claim, or nil.
function Runtime.claim()
    return Runtime.state().claim
end

--- Claims the building on a square with a yard margin and records how it
--- looks now. Returns ok, message.
function Runtime.claimBuilding(square, margin)
    local def = Runtime.buildingAt(square)
    if not def then
        return false, getText("UI_BBP_NoBuilding")
    end
    local area = Area.fromBuilding(def, margin)
    if not Area.isValid(area) then
        return false, getText("UI_BBP_TooBig")
    end
    local sigs, _, unloaded = Capture.signatures(area)
    if unloaded > 0 then
        return false, getText("UI_BBP_NotLoaded")
    end
    local root = Runtime.state()
    root.claim = { area = area, baseline = sigs, building = def, margin = margin }
    Runtime.changes = nil
    Runtime.log(string.format("claimed %d,%d %dx%d levels %d-%d (%d squares)", def.x, def.y, def.w, def.h, area.z1, area.z2, Area.count(area)))
    return true, getText("UI_BBP_Claimed")
end

--- Drops the claim.
function Runtime.unclaim()
    Runtime.state().claim = nil
    Runtime.changes = nil
end

--- Compares the claimed area with how it looked when claimed. Returns
--- { keys = changed keys, unloaded = count } or nil without a claim.
function Runtime.findChanges()
    local claim = Runtime.claim()
    if not claim then
        Runtime.changes = nil
        return nil
    end
    local current, unknown, unloaded = Capture.signatures(claim.area)
    local keys = Diff.changedKeys(claim.baseline, current, Area.keys(claim.area), unknown)
    Runtime.changes = { keys = keys, unloaded = unloaded, at = getTimestampMs() }
    return Runtime.changes
end

--- Returns the saved blueprint list.
function Runtime.entries()
    return Library.parseIndex(Files.readLines(Library.INDEX))
end

--- Writes the saved blueprint list.
local function writeEntries(entries)
    Files.writeLines(Library.INDEX, Library.indexLines(entries))
end

--- Saves the claimed base as a blueprint. `opts.everyTile` saves every
--- square instead of only the changed ones; `opts.contents` saves container
--- contents. A blueprint with the same name is replaced. Returns entry or
--- nil, message.
function Runtime.save(name, opts)
    opts = opts or {}
    local claim = Runtime.claim()
    if not claim then
        return nil, getText("UI_BBP_NoClaim")
    end
    local keys = nil
    if not opts.everyTile then
        local changes = Runtime.findChanges()
        keys = changes.keys
        if #keys == 0 then
            return nil, getText("UI_BBP_NothingChanged")
        end
    end
    local squares = Capture.records(claim.area, keys, { contents = opts.contents == true })
    local entries = Runtime.entries()
    local clean = Blueprint.cleanName(name)
    local id = Library.idForName(entries, clean) or Blueprint.makeId(clean, getTimestamp())
    local old = Library.find(entries, id) and entries[Library.find(entries, id)]
    local bp = Blueprint.new({
        id = id,
        name = clean,
        area = claim.area,
        building = claim.building,
        changedOnly = not opts.everyTile,
        created = getTimestamp(),
    }, squares)
    if not Files.writeLines(Library.fileFor(id), Blueprint.toLines(bp)) then
        return nil, getText("UI_BBP_WriteFailed")
    end
    local entry = Library.entryFor(bp, old and old.auto)
    entry.useContents = old and old.useContents and entry.contents or false
    Library.upsert(entries, entry)
    writeEntries(entries)
    Runtime.log(string.format("saved %s: %d squares, %d objects", id, bp.meta.squares, bp.meta.objects))
    return entry, getText("UI_BBP_Saved", clean, Runtime.int(bp.meta.squares))
end

--- Reads a blueprint file. Returns it, or nil and a reason.
function Runtime.load(id)
    local lines = Files.readLines(Library.fileFor(id))
    if not lines then
        return nil, "missing file"
    end
    return Blueprint.fromLines(lines)
end

--- Deletes a blueprint (its file is emptied; Lua cannot remove files).
function Runtime.delete(id)
    local entries = Runtime.entries()
    Library.remove(entries, id)
    writeEntries(entries)
    Files.writeLines(Library.fileFor(id), {})
end

--- Sets one flag ("auto" or "useContents") on a saved blueprint.
function Runtime.setFlag(id, flag, value)
    local entries = Runtime.entries()
    local i = Library.find(entries, id)
    if i then
        entries[i][flag] = value == true
        writeEntries(entries)
    end
end

--- Applies every waiting square in one loaded column.
function Runtime.processColumn(root, col)
    local entries = Pending.take(root, col)
    if not entries then
        return 0
    end
    local x, y = Keys.parseColumn(col)
    for _, entry in ipairs(entries) do
        local stats = Apply.square(x, y, entry.z, entry.objects)
        Pending.record(root, entry.bp, stats)
        for _, problem in ipairs(stats.problems) do
            Runtime.log(string.format("%s at %d,%d,%d: skipped %s", entry.bp, x, y, entry.z, problem))
        end
        local run = root.runs[entry.bp]
        if run and run.done == run.total then
            Runtime.log(string.format("finished %s: %d removed, %d added, %d skipped", entry.bp, run.removed, run.added, run.skipped))
        end
    end
    return #entries
end

--- Applies waiting squares in every column whose map is loaded right now.
function Runtime.processLoaded()
    local root = Runtime.state()
    local applied = 0
    for _, col in ipairs(Pending.columns(root)) do
        local x, y = Keys.parseColumn(col)
        if Capture.isLoaded(x, y) then
            applied = applied + Runtime.processColumn(root, col)
        end
    end
    if applied > 0 then
        triggerEvent("OnContainerUpdate")
        Runtime.changes = nil
    end
    return applied
end

--- Queues a saved blueprint for this world and applies what is loaded.
--- Returns ok, message.
function Runtime.apply(id, withContents)
    local bp, err = Runtime.load(id)
    if not bp then
        return false, getText("UI_BBP_LoadFailed", tostring(err))
    end
    local squares = Blueprint.squaresToApply(bp, withContents == true)
    local total = Pending.schedule(Runtime.state(), id, bp.meta.name, squares)
    Runtime.log(string.format("applying %s: %d squares%s", id, total, withContents and " with contents" or ""))
    Runtime.processLoaded()
    local left = Pending.left(Runtime.state(), id)
    if left > 0 then
        return true, getText("UI_BBP_ApplyingLater", bp.meta.name, Runtime.int(total - left), Runtime.int(total))
    end
    return true, getText("UI_BBP_Applied", bp.meta.name, Runtime.int(total))
end

--- Applies every blueprint marked for new games.
function Runtime.applyAuto()
    for _, entry in ipairs(Runtime.entries()) do
        if entry.auto then
            local okay, message = Runtime.apply(entry.id, entry.useContents == true)
            Runtime.log((okay and "auto: " or "auto failed: ") .. message)
        end
    end
end

--- Notes a loaded square whose column has waiting blueprint squares.
function Runtime.onLoadGridsquare(square)
    local root = Runtime.cache
    if not root or not square then
        return
    end
    local col = Keys.column(square:getX(), square:getY())
    if root.columns[col] then
        Runtime.dirty[col] = true
        Runtime.hasDirty = true
    end
end

--- Applies columns noted by onLoadGridsquare, one tick after they load.
function Runtime.onTick()
    if not Runtime.hasDirty then
        return
    end
    local cols = {}
    for col in pairs(Runtime.dirty) do
        cols[#cols + 1] = col
    end
    Runtime.dirty = {}
    Runtime.hasDirty = false
    local root = Runtime.state()
    local applied = 0
    for _, col in ipairs(cols) do
        local x, y = Keys.parseColumn(col)
        if Capture.isLoaded(x, y) then
            applied = applied + Runtime.processColumn(root, col)
        end
    end
    if applied > 0 then
        triggerEvent("OnContainerUpdate")
    end
end

return Runtime
