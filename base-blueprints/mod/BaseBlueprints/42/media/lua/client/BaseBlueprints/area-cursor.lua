--- The drag tool for marking out a base: press the mouse on one corner, drag
--- to the other and let go. Works like the game's own rectangle tools
--- (ISBuildingRoomsEditor_ToolAddRect): while the button is held the game
--- keeps passing the corner you pressed on, and the mouse gives the other
--- one. Right-click or Esc cancels, as with any build cursor.
---
--- ISBuildingObject lives in the game's server Lua, which loads after client
--- Lua, so the cursor class is made the first time it is needed.
local Area = require("BaseBlueprints/area")
local Runtime = require("BaseBlueprints/runtime")
local Overlay = require("BaseBlueprints/overlay")

local AreaCursor = {}

AreaCursor.COLOR = { 0.35, 0.85, 0.45, 0.4 }
AreaCursor.TOO_BIG = { 1.0, 0.25, 0.2, 0.4 }

local BBP_AreaCursor = nil
local define

--- Starts dragging for the player. `onFinish(ok, message)` runs after a
--- drag or a cancel (message nil on cancel). Returns the cursor.
function AreaCursor.start(onFinish)
    local player = getPlayer()
    if not player then
        return nil
    end
    local cursor = define():new(player, onFinish)
    getCell():setDrag(cursor, player:getPlayerNum())
    player:setHaloNote(getText("UI_BBP_DragHint"), 220, 220, 120, 400)
    return cursor
end

--- Makes the cursor class once, now that ISBuildingObject exists.
define = function()
    if BBP_AreaCursor then
        return BBP_AreaCursor
    end
    BBP_AreaCursor = ISBuildingObject:derive("BBP_AreaCursor")

    --- Creates the cursor.
    function BBP_AreaCursor:new(player, onFinish)
        local o = ISBuildingObject.new(self)
        o:init()
        o.player = player:getPlayerNum()
        o.character = player
        o.skipBuildAction = true
        o.noNeedHammer = true
        o.skipWalk2 = true
        o.canBeAlwaysPlaced = true
        o.onFinish = onFinish
        o.finished = false
        return o
    end

    --- Returns the level being marked: the one the player stands on.
    function BBP_AreaCursor:level()
        return math.floor(self.character:getZ())
    end

    --- Returns the map square under the mouse on the marked level.
    function BBP_AreaCursor:mouseSquare()
        local z = self:level()
        local mx, my = getMouseX(), getMouseY()
        return math.floor(screenToIsoX(self.player, mx, my, z)), math.floor(screenToIsoY(self.player, mx, my, z))
    end

    --- Returns the dragged rectangle between the pressed corner and the mouse.
    function BBP_AreaCursor:rectangle(x, y)
        local mx, my = self:mouseSquare()
        return Area.normalize(x, y, mx, my)
    end

    --- Any square can be a corner.
    function BBP_AreaCursor:isValid(square)
        return true
    end

    --- Highlights the rectangle being dragged, or the square under the mouse
    --- before the button goes down. Red means too big to claim.
    function BBP_AreaCursor:render(x, y, z, square)
        local level = self:level()
        local x1, y1, x2, y2 = x, y, x, y
        if self.isLeftDown then
            x1, y1, x2, y2 = self:rectangle(x, y)
        end
        local c = Area.footprintOk(x1, y1, x2, y2) and AreaCursor.COLOR or AreaCursor.TOO_BIG
        addAreaHighlightForPlayer(self.player, x1, y1, x2 + 1, y2 + 1, level, c[1], c[2], c[3], c[4])
    end

    --- Claims the rectangle when the button is let go.
    function BBP_AreaCursor:create(x, y, z)
        local x1, y1, x2, y2 = self:rectangle(x, y)
        self.finished = true
        getCell():setDrag(nil, self.player)
        local okay, message = Runtime.claimRect(x1, y1, x2, y2, self:level())
        self.character:setHaloNote(message, 220, 220, 120, 300)
        if okay then
            Overlay.setEnabled(true)
        end
        if self.onFinish then
            self.onFinish(okay, message)
        end
    end

    --- Called by the game when the cursor is put away; reports a cancel.
    function BBP_AreaCursor:deactivate()
        if not self.finished then
            self.finished = true
            if self.onFinish then
                self.onFinish(false, nil)
            end
        end
    end

    return BBP_AreaCursor
end

return AreaCursor
