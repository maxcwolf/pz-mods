--- The three mouse modes, built on the game's build cursor
--- (ISBuildingObject) so clicking, the see-through preview, right-click to
--- stop and the Rotate Building key (R) all work the vanilla way:
--- placing furniture, painting floors and removing furniture.
local Place = require("FurnishByRoom/place")
local Floors = require("FurnishByRoom/floors")
local Faces = require("FurnishByRoom/faces")

local Cursors = {}

--- Returns a cached see-through sprite for a tile name.
function Cursors.ghost(name)
    Cursors.ghosts = Cursors.ghosts or {}
    local sprite = Cursors.ghosts[name]
    if not sprite then
        sprite = IsoSprite.new()
        sprite:LoadSingleTexture(name)
        Cursors.ghosts[name] = sprite
    end
    return sprite
end

--- Draws parts green (or red when blocked) at their squares.
function Cursors.drawParts(parts, valid)
    for _, part in ipairs(parts) do
        local ghost = Cursors.ghost(part.sprite)
        if valid then
            ghost:RenderGhostTile(part.x, part.y, part.z)
        else
            ghost:RenderGhostTileRed(part.x, part.y, part.z)
        end
    end
end

--- Sets the fields every mode shares: no walking, no hammer, no timed
--- action, keep placing after each click.
local function setup(o, spriteName, player, controller)
    o:init()
    o:setSprite(spriteName)
    o:setNorthSprite(spriteName)
    o.character = player
    o.player = player:getPlayerNum()
    o.controller = controller
    o.skipBuildAction = true
    o.skipWalk2 = true
    o.noNeedHammer = true
    o.dragNilAfterPlace = false
    o.isFurnishCursor = true
end

--- Defines the cursor classes once the game's build cursor is loaded.
function Cursors.ensure()
    if Cursors.Place then
        return
    end
    if not ISBuildingObject then
        require "BuildingObjects/ISBuildingObject"
    end

    local PlaceCursor = ISBuildingObject:derive("FBR_PlaceCursor")

    --- Starts placing an entry.
    function PlaceCursor:new(entry, player, controller)
        local o = {}
        setmetatable(o, self)
        self.__index = self
        setup(o, entry.sprite, player, controller)
        o.entry = entry
        o.current = entry.sprite
        return o
    end

    --- Returns the facing being placed.
    function PlaceCursor:getSprite()
        return self.current
    end

    --- Steps to the next facing on the Rotate Building key.
    function PlaceCursor:rotateKey(key)
        if getCore():isKey(KeybindId.ROTATE_BUILDING, key) then
            self.current = Faces.next(self.entry, self.current)
        end
    end

    --- Ignores mouse-drag rotation so a click places straight away.
    function PlaceCursor:rotateMouse()
    end

    --- Returns the parts under the square for the current facing.
    function PlaceCursor:partsAt(square)
        return Place.parts(self.current, square:getX(), square:getY(), square:getZ())
    end

    --- Returns true when the piece fits with its first tile on the square.
    function PlaceCursor:isValid(square)
        return square ~= nil and Place.canPlace(self.character, self:partsAt(square), self.controller.anywhere())
    end

    --- Draws the see-through piece.
    function PlaceCursor:render(x, y, z, square)
        if square then
            Cursors.drawParts(self:partsAt(square), self:isValid(square))
        end
    end

    --- Places the piece where the player clicked.
    function PlaceCursor:create(x, y, z)
        local square = getCell():getGridSquare(x, y, z)
        if not self:isValid(square) then
            return
        end
        local placed = Place.place(self.character, self:partsAt(square))
        self.controller.placed(self.entry, placed)
    end

    --- Tells the controller the mode ended (right-click, Esc or a new pick).
    function PlaceCursor:deactivate()
        self.controller.cursorEnded(self)
    end

    local FloorCursor = ISBuildingObject:derive("FBR_FloorCursor")

    --- Starts painting a floor entry.
    function FloorCursor:new(entry, player, controller)
        local o = {}
        setmetatable(o, self)
        self.__index = self
        setup(o, entry.sprite, player, controller)
        o.entry = entry
        return o
    end

    --- Returns the floor tile being painted.
    function FloorCursor:getSprite()
        return self.entry.sprite
    end

    --- Remembers where a drag has reached.
    function FloorCursor:rotateMouse(x, y)
        self.dragEnd = { x = x, y = y }
    end

    --- Returns true while a drag covers more than the square it started on.
    function FloorCursor:isDragging(square)
        local d = self.dragEnd
        return d ~= nil and (d.x ~= square:getX() or d.y ~= square:getY())
    end

    --- Returns the squares a click or drag starting on the square paints.
    function FloorCursor:targets(square)
        if self:isDragging(square) then
            return Floors.rectSquares(square:getX(), square:getY(), self.dragEnd.x, self.dragEnd.y, square:getZ()) or {}
        end
        if not Floors.paintable(square) then
            return {}
        end
        return Floors.roomSquares(square)
    end

    --- Returns true when there is something to paint.
    function FloorCursor:isValid(square)
        return square ~= nil and #self:targets(square) > 0
    end

    --- Draws the new floor over every square it would cover.
    function FloorCursor:render(x, y, z, square)
        if not self.isLeftDown and not self.build then
            self.dragEnd = nil
        end
        if not square then
            return
        end
        local targets = self:targets(square)
        local ghost = Cursors.ghost(self.entry.sprite)
        for _, sq in ipairs(targets) do
            ghost:RenderGhostTile(sq:getX(), sq:getY(), sq:getZ())
        end
        if #targets == 0 then
            ghost:RenderGhostTileRed(x, y, z)
        end
    end

    --- Paints the room, or the dragged rectangle.
    function FloorCursor:create(x, y, z)
        local square = getCell():getGridSquare(x, y, z)
        if not square then
            return
        end
        local tiles = Floors.paintAll(self:targets(square), self.entry.sprite)
        self.dragEnd = nil
        self.controller.painted(self.entry, tiles)
    end

    --- Tells the controller the mode ended.
    function FloorCursor:deactivate()
        self.controller.cursorEnded(self)
    end

    local RemoveCursor = ISBuildingObject:derive("FBR_RemoveCursor")

    --- Starts the Remove tool.
    function RemoveCursor:new(player, controller)
        local o = {}
        setmetatable(o, self)
        self.__index = self
        setup(o, "", player, controller)
        o.entry = { key = "remove", label = "", sprite = "" }
        return o
    end

    --- Returns nothing to draw by default; render shows the target instead.
    function RemoveCursor:getSprite()
        return ""
    end

    --- Ignores mouse-drag rotation.
    function RemoveCursor:rotateMouse()
    end

    --- Ignores the rotate key.
    function RemoveCursor:rotateKey()
    end

    --- Returns the parts of the piece the click would remove.
    function RemoveCursor:partsAt(square)
        local obj = Place.removable(square)
        if not obj then
            return {}
        end
        return Place.objectParts(obj)
    end

    --- Returns true when there is furniture on the square.
    function RemoveCursor:isValid(square)
        return square ~= nil and Place.removable(square) ~= nil
    end

    --- Tints the piece red.
    function RemoveCursor:render(x, y, z, square)
        if square then
            Cursors.drawParts(self:partsAt(square), false)
        end
    end

    --- Removes the whole piece.
    function RemoveCursor:create(x, y, z)
        local square = getCell():getGridSquare(x, y, z)
        local parts = square and self:partsAt(square) or {}
        local removed = {}
        for _, part in ipairs(parts) do
            if Place.removePart(part) then
                removed[#removed + 1] = part
            end
        end
        self.controller.removed(removed)
    end

    --- Tells the controller the mode ended.
    function RemoveCursor:deactivate()
        self.controller.cursorEnded(self)
    end

    Cursors.Place = PlaceCursor
    Cursors.Floor = FloorCursor
    Cursors.Remove = RemoveCursor
end

--- Returns a new cursor for an entry: floor painting for floors, placing
--- for everything else.
function Cursors.forEntry(entry, player, controller)
    Cursors.ensure()
    if entry.floor then
        return Cursors.Floor:new(entry, player, controller)
    end
    return Cursors.Place:new(entry, player, controller)
end

--- Returns a new Remove cursor.
function Cursors.remover(player, controller)
    Cursors.ensure()
    return Cursors.Remove:new(player, controller)
end

return Cursors
