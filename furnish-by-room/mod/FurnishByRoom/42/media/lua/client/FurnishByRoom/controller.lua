--- The one place both layouts talk to: what is being browsed, what the
--- mouse is doing (placing, painting, removing), the undo list, and
--- switching between the catalog window and the bottom strip.
local Rooms = require("FurnishByRoom/rooms")
local Browse = require("FurnishByRoom/browse")
local Catalog = require("FurnishByRoom/catalog")
local History = require("FurnishByRoom/history")
local Layout = require("FurnishByRoom/layout")
local Tiles = require("FurnishByRoom/tiles")
local Cursors = require("FurnishByRoom/cursors")
local Undo = require("FurnishByRoom/undo")
local Options = require("FurnishByRoom/options")

local Controller = {
    view = nil,
    placing = nil,
    lastRoom = nil,
    views = {},
}

--- Writes a line to the console with the mod's tag.
function Controller.log(text)
    print("[FurnishByRoom] " .. tostring(text))
end

--- Returns the local player.
function Controller.player()
    return getSpecificPlayer(0)
end

--- Shows a short message over the player's head.
function Controller.say(text)
    local player = Controller.player()
    if player then
        player:setHaloNote(text, 220, 220, 140, 250)
    end
end

--- Returns the catalog, scanning the game's tiles the first time.
function Controller.catalog()
    if not Controller.catalog_ then
        local started = getTimestampMs and getTimestampMs() or 0
        local records = Tiles.scan()
        Controller.catalog_ = Catalog.build(records)
        local took = (getTimestampMs and getTimestampMs() or 0) - started
        Controller.log("catalog: " .. #records .. " tiles read in " .. took .. " ms")
    end
    return Controller.catalog_
end

--- Returns the browse state, creating it on first use.
function Controller.browse()
    if not Controller.browse_ then
        Controller.browse_ = Browse.new(Rooms.ORDER[1])
    end
    return Controller.browse_
end

--- Returns the undo list.
function Controller.history()
    if not Controller.history_ then
        Controller.history_ = History.new()
    end
    return Controller.history_
end

--- Returns the room the player is standing in, or nil.
function Controller.detectRoom()
    local player = Controller.player()
    local square = player and player:getCurrentSquare()
    local room = square and square:getRoom()
    return room and Rooms.fromGameName(room:getName()) or nil
end

--- Returns true when the placement rules are off.
function Controller.anywhere()
    return Options.anywhere()
end

--- Returns the items the current view shows.
function Controller.items()
    return Browse.items(Controller.catalog(), Controller.browse())
end

--- Returns the category filters for the current room.
function Controller.filters()
    return Browse.filters(Controller.catalog(), Controller.browse())
end

--- Returns how many items a room has.
function Controller.count(room)
    return Catalog.count(Controller.catalog(), room)
end

--- Asks the open view to redraw its lists.
function Controller.refresh()
    if Controller.view then
        Controller.view:refresh()
    end
end

--- Registers a layout's view factory: create(controller) returns a view
--- with show, dismiss, isShown, refresh, onPlacingStarted and onPlacingEnded.
function Controller.registerView(layout, factory)
    Controller.views[layout] = factory
end

--- Opens the chosen layout on a room (the one the player stands in, else
--- the last one used).
function Controller.open(room)
    local detected = Controller.detectRoom()
    Controller.detected = detected
    local target = Rooms.pick(room or detected, Controller.lastRoom)
    local browse = Controller.browse()
    if browse.room ~= target then
        Browse.setRoom(browse, target)
    end
    Controller.lastRoom = target
    Controller.showView()
end

--- Shows the view for the chosen layout, replacing one of the other kind.
function Controller.showView()
    local layout = Options.layout()
    if Controller.view and Controller.view.layout ~= layout then
        Controller.view:dismiss()
        Controller.view = nil
    end
    if not Controller.view then
        local factory = Controller.views[layout] or Controller.views[Layout.CATALOG]
        if not factory then
            return
        end
        Controller.view = factory(Controller)
        Controller.view.layout = layout
    end
    Controller.view:show()
    Controller.view:refresh()
    if Controller.placing then
        Controller.view:onPlacingStarted(Controller.placing)
    end
end

--- Closes the view and stops any mouse mode.
function Controller.close()
    Controller.stop()
    if Controller.view then
        Controller.view:dismiss()
        Controller.view = nil
    end
end

--- Opens the mod when closed, closes it when open.
function Controller.toggle()
    if Controller.view and Controller.view:isShown() then
        Controller.close()
    else
        Controller.open()
    end
end

--- Switches to the other layout and remembers the choice.
function Controller.setLayout(layout)
    Options.setLayout(layout)
    if Controller.view then
        Controller.showView()
    end
end

--- Switches rooms.
function Controller.selectRoom(room)
    Browse.setRoom(Controller.browse(), room)
    Controller.lastRoom = room
    Controller.refresh()
end

--- Switches category.
function Controller.selectCategory(cat)
    Browse.setCategory(Controller.catalog(), Controller.browse(), cat)
    Controller.refresh()
end

--- Steps to the next category (the strip's cycle button).
function Controller.nextCategory()
    Controller.selectCategory(Browse.nextCategory(Controller.catalog(), Controller.browse()))
end

--- Sets the search text.
function Controller.setQuery(text)
    Controller.browse().query = text or ""
    Controller.refresh()
end

--- Starts a mouse mode with the cursor; the old one ends quietly.
local function start(placing)
    local player = Controller.player()
    if not player then
        return
    end
    Controller.placing = placing
    getCell():setDrag(placing.cursor, player:getPlayerNum())
    if Controller.view then
        Controller.view:onPlacingStarted(placing)
    end
end

--- Picks an entry: placing for furniture, painting for floors.
function Controller.pick(entry)
    local player = Controller.player()
    if not player or not entry then
        return
    end
    Controller.picked = entry.key
    local cursor = Cursors.forEntry(entry, player, Controller)
    start({ entry = entry, cursor = cursor, mode = entry.floor and "floor" or "place", count = 0 })
end

--- Picks the next (step 1) or previous (step -1) item in the list.
function Controller.pickNeighbor(step)
    local entry = Browse.neighbor(Controller.items(), Controller.picked, step)
    if entry then
        Controller.pick(entry)
    end
end

--- Starts the Remove tool.
function Controller.startRemove()
    local player = Controller.player()
    if not player then
        return
    end
    Controller.picked = nil
    start({ entry = nil, cursor = Cursors.remover(player, Controller), mode = "remove", count = 0 })
end

--- Ends the current mouse mode, if any.
function Controller.stop()
    local player = Controller.player()
    if Controller.placing and player then
        getCell():setDrag(nil, player:getPlayerNum())
    end
    Controller.placing = nil
end

--- Called by a cursor when it is put away. Ignored for a cursor that a new
--- pick already replaced.
function Controller.cursorEnded(cursor)
    if Controller.placing and Controller.placing.cursor == cursor then
        Controller.placing = nil
        if Controller.view then
            Controller.view:onPlacingEnded()
        end
    end
end

--- Counts one more piece or paint for the mode's status line.
local function bump()
    if Controller.placing then
        Controller.placing.count = (Controller.placing.count or 0) + 1
    end
    Controller.refresh()
end

--- Records placed parts for undo.
function Controller.placed(entry, parts)
    if History.push(Controller.history(), { kind = "place", parts = parts, label = entry.label }) then
        bump()
    end
end

--- Records painted floor tiles for undo.
function Controller.painted(entry, tiles)
    if History.push(Controller.history(), { kind = "floor", tiles = tiles, label = entry.label }) then
        bump()
    end
end

--- Records removed parts for undo.
function Controller.removed(parts)
    if History.push(Controller.history(), { kind = "remove", parts = parts }) then
        bump()
    end
end

--- Undoes the newest change.
function Controller.undo()
    local action = History.pop(Controller.history())
    if not action then
        Controller.say(getText("UI_FBR_NothingToUndo"))
        return false
    end
    Undo.apply(action, Controller.player())
    Controller.say(getText("UI_FBR_Undone_" .. action.kind))
    Controller.refresh()
    return true
end

--- Returns how many changes can be undone.
function Controller.undoCount()
    return History.size(Controller.history())
end

--- Forgets the catalog so the next open scans again (after mods change).
function Controller.reset()
    Controller.catalog_ = nil
end

return Controller
