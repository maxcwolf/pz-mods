--- A small stand-in for the game: tile sprites with properties and
--- multi-tile grids, a cell of squares with rooms and floors, the player,
--- the build cursor base class, the game's furniture placement code, mod
--- options and events. Enough to run the mod's code paths end to end.
local Fake = {}

--- Makes a 0-based list like a Java ArrayList.
function Fake.list(items)
    local l = { items = items or {} }
    --- Returns the size.
    function l:size() return #self.items end
    --- Returns the item at a 0-based index.
    function l:get(i) return self.items[i + 1] end
    --- Appends an item.
    function l:add(v) self.items[#self.items + 1] = v end
    return l
end

--- Makes a property container from a table of key -> value (true for flags).
local function properties(values)
    local p = { values = values }
    --- Returns true when the key or flag is set.
    function p:has(key) return self.values[key] ~= nil end
    --- Returns the value.
    function p:get(key) local v = self.values[key]; if v == true then return "" end; return v end
    --- Returns the value.
    function p:Val(key) return self:get(key) end
    return p
end

--- Installs the game's globals for a new world and returns it.
function Fake.newWorld()
    local w = {
        sprites = {}, sheets = {}, squares = {}, notes = {}, drags = {}, ghosts = {},
        events = {}, ctrl = false, options = {},
    }

    _G.IsoFlagType = {
        solidfloor = "flag:solidfloor", water = "flag:water", WallN = "flag:WallN", WallW = "flag:WallW",
        WallNW = "flag:WallNW", WallSE = "flag:WallSE", doorN = "flag:doorN", doorW = "flag:doorW",
    }
    _G.Keyboard = { KEY_ESCAPE = 1, KEY_Z = 44, KEY_F7 = 65, KEY_R = 19 }
    _G.KeybindId = { ROTATE_BUILDING = "rotate" }
    _G.UIFont = { Small = "Small", Medium = "Medium" }

    --- Adds a sprite: props is a table of property name -> value; grid is
    --- { name = gridName, x = ., y = . } for multi-tile pieces.
    function w.sprite(sheet, index, props, grid)
        local name = sheet .. "_" .. index
        local s = { name = name, props = properties(props or {}) }
        --- Returns the name.
        function s:getName() return self.name end
        --- Returns the properties.
        function s:getProperties() return self.props end
        --- Returns the grid, or nil.
        function s:getSpriteGrid() return self.grid end
        w.sprites[name] = s
        w.sheets[sheet] = true
        if grid then
            local g = w.grids and w.grids[grid.name]
            if not g then
                w.grids = w.grids or {}
                g = { cells = {}, width = 1, height = 1 }
                --- Returns the anchor (grid position 0,0).
                function g:getAnchorSprite() return self.cells["0,0"] end
                --- Returns a sprite's grid x.
                function g:getSpriteGridPosX(sp) return sp.gx end
                --- Returns a sprite's grid y.
                function g:getSpriteGridPosY(sp) return sp.gy end
                --- Returns the width.
                function g:getWidth() return self.width end
                --- Returns the height.
                function g:getHeight() return self.height end
                --- Returns the sprite in a cell.
                function g:getSprite(x, y) return self.cells[x .. "," .. y] end
                w.grids[grid.name] = g
            end
            s.gx, s.gy, s.grid = grid.x, grid.y, g
            g.cells[grid.x .. "," .. grid.y] = s
            g.width = math.max(g.width, grid.x + 1)
            g.height = math.max(g.height, grid.y + 1)
        end
        return s
    end

    _G.getSprite = function(name) return w.sprites[name] end
    _G.getTexture = function(name) return w.sprites[name] and { name = name } or nil end
    _G.getWorld = function()
        return {
            getTileImageNames = function()
                local names = {}
                for sheet in pairs(w.sheets) do names[#names + 1] = sheet .. ".png" end
                table.sort(names)
                return Fake.list(names)
            end,
        }
    end

    --- Makes a map object drawn with the sprite.
    function w.object(spriteName, square)
        local o = { sprite = w.sprites[spriteName], square = square, containers = {} }
        assert(o.sprite, "unknown sprite " .. tostring(spriteName))
        --- Returns the sprite.
        function o:getSprite() return self.sprite end
        --- Changes the sprite.
        function o:setSprite(sp) self.sprite = sp end
        --- Forgets overlays.
        function o:clearAttachedAnimSprite() self.cleared = true end
        --- Returns the sprite's properties.
        function o:getProperties() return self.sprite and self.sprite:getProperties() end
        --- Returns the square.
        function o:getSquare() return self.square end
        --- Returns how many containers it has.
        function o:getContainerCount() return #self.containers end
        --- Returns a container.
        function o:getContainerByIndex(i) return self.containers[i + 1] end
        if o.sprite.props:has("container") then
            local c = { explored = false }
            --- Marks it searched.
            function c:setExplored(v) self.explored = v end
            o.containers[1] = c
        end
        return o
    end

    --- Returns (making) the square at x, y, z.
    function w.square(x, y, z)
        local key = x .. "," .. y .. "," .. (z or 0)
        local sq = w.squares[key]
        if sq then
            return sq
        end
        sq = { x = x, y = y, z = z or 0, objects = {}, flags = {} }
        --- Returns x.
        function sq:getX() return self.x end
        --- Returns y.
        function sq:getY() return self.y end
        --- Returns z.
        function sq:getZ() return self.z end
        --- Returns the objects as a list.
        function sq:getObjects() return Fake.list(self.objects) end
        --- Returns the floor object.
        function sq:getFloor()
            for _, o in ipairs(self.objects) do
                if o.isFloor then return o end
            end
            return nil
        end
        --- Adds a floor.
        function sq:addFloor(name)
            local f = w.object(name, self)
            f.isFloor = true
            table.insert(self.objects, 1, f)
            return f
        end
        --- Removes an object.
        function sq:RemoveTileObject(obj)
            for i, o in ipairs(self.objects) do
                if o == obj then
                    table.remove(self.objects, i)
                    return i
                end
            end
            return -1
        end
        --- Returns the room, or nil.
        function sq:getRoom() return self.room end
        --- Returns true when a car overlaps.
        function sq:isVehicleIntersecting() return self.car == true end
        --- Returns true when the square has a flag.
        function sq:has(flag) return self.flags[flag] == true end
        w.squares[key] = sq
        return sq
    end

    --- Makes a room of squares with a floor sprite on each.
    function w.room(name, x1, y1, x2, y2, floorSprite)
        local room = { name = name, squares = {} }
        --- Returns the game room name.
        function room:getName() return self.name end
        --- Returns the squares.
        function room:getSquares() return Fake.list(self.squares) end
        for x = x1, x2 do
            for y = y1, y2 do
                local sq = w.square(x, y, 0)
                sq.room = room
                sq:addFloor(floorSprite)
                room.squares[#room.squares + 1] = sq
            end
        end
        return room
    end

    --- Returns the names of the sprites on a square, floor first.
    function w.spritesAt(x, y, z)
        local out = {}
        for _, o in ipairs(w.square(x, y, z).objects) do
            out[#out + 1] = o.sprite:getName()
        end
        return table.concat(out, ",")
    end

    local cell = {}
    --- Returns a square that exists, or nil.
    function cell:getGridSquare(x, y, z) return w.squares[x .. "," .. y .. "," .. (z or 0)] end
    --- Sets the build cursor; the old one is told it ended.
    function cell:setDrag(cursor, playerNum)
        local old = w.drag
        w.drag = cursor
        w.drags[#w.drags + 1] = cursor or false
        if old and old ~= cursor and old.deactivate then
            old:deactivate()
        end
    end
    --- Returns the build cursor.
    function cell:getDrag() return w.drag end
    _G.getCell = function() return cell end

    w.player = { num = 0 }
    --- Returns the player number.
    function w.player:getPlayerNum() return 0 end
    --- Returns the square the player stands on.
    function w.player:getCurrentSquare() return w.standing end
    --- Records a halo note.
    function w.player:setHaloNote(text) w.notes[#w.notes + 1] = text end
    --- Returns false: the player has not turned on the admin movables cheat.
    function w.player:isMovablesCheat() return false end
    _G.ISMoveableDefinitions = { cheat = false }
    _G.getSpecificPlayer = function() return w.player end
    _G.getPlayer = function() return w.player end
    _G.instanceItem = function(name) return { type = name } end
    _G.instanceof = function(obj, cls) return obj ~= nil and obj.class == cls end
    _G.isClient = function() return false end
    _G.isCtrlKeyDown = function() return w.ctrl end
    _G.getTimestampMs = function() return 0 end
    _G.getText = function(key, ...)
        local args = { ... }
        if #args == 0 then return key end
        local parts = {}
        for i, a in ipairs(args) do parts[i] = tostring(a) end
        return key .. "(" .. table.concat(parts, "|") .. ")"
    end
    _G.getCore = function()
        return {
            getScreenWidth = function() return 1920 end,
            getScreenHeight = function() return 1080 end,
            isKey = function(_, id, key) return id == "rotate" and key == Keyboard.KEY_R end,
        }
    end
    _G.getTextManager = function()
        return { getFontHeight = function() return 16 end, MeasureStringX = function(_, _, s) return #s * 7 end }
    end
    _G.print = function() end

    _G.IsoSprite = {}
    --- Makes a see-through drawing sprite that records what it draws.
    function IsoSprite.new()
        local s = {}
        --- Loads a tile picture.
        function s:LoadSingleTexture(name) self.name = name end
        --- Records a green draw.
        function s:RenderGhostTile(x, y, z) w.ghosts[#w.ghosts + 1] = { self.name, x, y, z, "ok" } end
        --- Records a red draw.
        function s:RenderGhostTileRed(x, y, z) w.ghosts[#w.ghosts + 1] = { self.name, x, y, z, "red" } end
        return s
    end

    -- The game's furniture code: places any tile as an object; refuses a
    -- square that already has furniture marked BlocksPlacement.
    _G.ISMoveableSpriteProps = {}
    --- Makes props for a sprite or sprite name.
    function ISMoveableSpriteProps.new(sprite)
        if type(sprite) == "string" then sprite = w.sprites[sprite] end
        local p = { sprite = sprite, isMoveable = true }
        --- Returns true when nothing blocking is on the square and, like the
        --- game, the player has the piece's place tool unless the movables
        --- cheat is on.
        function p:canPlaceMoveableInternal(player, square)
            for _, o in ipairs(square.objects) do
                if not o.isFloor and o:getProperties():has("BlocksPlacement") then
                    return false
                end
            end
            if player and self.sprite:getProperties():has("PlaceTool")
                and not ISMoveableDefinitions.cheat and not player:isMovablesCheat() then
                w.toolChecks = (w.toolChecks or 0) + 1
                return false
            end
            return true
        end
        --- Adds an object with the tile.
        function p:placeMoveableInternal(_, square, _, name)
            local o = w.object(name, square)
            square.objects[#square.objects + 1] = o
            w.placedCalls = (w.placedCalls or 0) + 1
            return o
        end
        --- Never finds a wall in the way.
        function p:isWallBetweenParts() return false end
        return p
    end

    -- The build cursor base class.
    _G.ISBuildingObject = {}
    ISBuildingObject.__index = ISBuildingObject
    --- Makes a subclass.
    function ISBuildingObject:derive(name)
        local cls = setmetatable({ Type = name }, { __index = self })
        cls.__index = cls
        return cls
    end
    --- Resets cursor fields.
    function ISBuildingObject:init() self.north = false end
    --- Sets the sprite.
    function ISBuildingObject:setSprite(s) self.sprite = s end
    --- Sets the north sprite.
    function ISBuildingObject:setNorthSprite(s) self.northSprite = s end
    package.preload["BuildingObjects/ISBuildingObject"] = function() return true end

    _G.Events = setmetatable({}, { __index = function(t, name)
        local e = { fns = {} }
        --- Adds a handler.
        function e.Add(fn) e.fns[#e.fns + 1] = fn end
        rawset(t, name, e)
        return e
    end })

    --- Calls every handler of an event.
    function w.fire(name, ...)
        for _, fn in ipairs(Events[name].fns) do
            fn(...)
        end
    end

    -- Options > Mods.
    _G.PZAPI = { ModOptions = { saves = 0 } }
    --- Creates an options page.
    function PZAPI.ModOptions:create(id)
        local page = { dict = {} }
        --- Returns an option.
        function page:getOption(oid) return self.dict[oid] end
        --- Adds a simple value option.
        local function add(oid, value)
            local o = { value = value }
            --- Returns the value.
            function o:getValue() return self.value end
            --- Sets the value.
            function o:setValue(v) self.value = v end
            page.dict[oid] = o
            return o
        end
        --- Adds a key binding.
        function page:addKeyBind(oid, _, key) return add(oid, key) end
        --- Adds a tick box.
        function page:addTickBox(oid, _, value) return add(oid, value) end
        --- Adds a combo box.
        function page:addComboBox(oid)
            local o = add(oid, 1)
            o.items = {}
            --- Adds an item.
            function o:addItem(name, selected)
                self.items[#self.items + 1] = name
                if selected then self.value = #self.items end
            end
            return o
        end
        w.options[id] = page
        return page
    end
    --- Counts saves.
    function PZAPI.ModOptions:save() self.saves = self.saves + 1 end

    return w
end

--- Adds the small furniture set the end-to-end tests use.
function Fake.furniture(w)
    w.sprite("floor_base", 0, { [IsoFlagType.solidfloor] = true })
    for i, face in ipairs({ "N", "W", "S", "E" }) do
        w.sprite("appliances_refrigeration_01", i - 1, { IsMoveAble = true, GroupName = "White",
            CustomName = "Fridge", Facing = face, container = "fridge", BlocksPlacement = true })
    end
    -- A two-tile bed: south-facing runs down y, east-facing runs along x.
    w.sprite("furniture_bedding_01", 0, { IsMoveAble = true, GroupName = "Blue", CustomName = "Bed", Facing = "S", BlocksPlacement = true }, { name = "bedS", x = 0, y = 0 })
    w.sprite("furniture_bedding_01", 1, { IsMoveAble = true, GroupName = "Blue", CustomName = "Bed", Facing = "S", BlocksPlacement = true }, { name = "bedS", x = 0, y = 1 })
    w.sprite("furniture_bedding_01", 2, { IsMoveAble = true, GroupName = "Blue", CustomName = "Bed", Facing = "E", BlocksPlacement = true }, { name = "bedE", x = 0, y = 0 })
    w.sprite("furniture_bedding_01", 3, { IsMoveAble = true, GroupName = "Blue", CustomName = "Bed", Facing = "E", BlocksPlacement = true }, { name = "bedE", x = 1, y = 0 })
    w.sprite("furniture_seating_indoor_01", 0, { IsMoveAble = true, GroupName = "Red Comfy", CustomName = "Couch", Facing = "S", BlocksPlacement = true })
    w.sprite("location_restaurant_bar_01", 0, { IsMoveAble = true, CustomName = "Bar Stool", BlocksPlacement = true })
    w.sprite("furniture_shelving_01", 0, { IsMoveAble = true, GroupName = "Large Metal", CustomName = "Shelves", Facing = "S", container = "shelves", BlocksPlacement = true })
    w.sprite("floors_interior_tilesandwood_01", 11, { [IsoFlagType.solidfloor] = true, IsMoveAble = true, CustomName = "White Tiles" })
    w.sprite("floors_interior_tilesandwood_01", 30, { [IsoFlagType.solidfloor] = true, IsMoveAble = true, CustomName = "Oakwood Floor" })
    w.sprite("misc_junk_01", 0, { IsMoveAble = true, CustomName = "Junk" })
    -- Storage the game only lets you place with a hammer and carpentry.
    w.sprite("fixtures_counters_01", 0, { IsMoveAble = true, GroupName = "Oak", CustomName = "Counter",
        Facing = "S", container = "counter", BlocksPlacement = true, PlaceTool = "Hammer" })
    w.kitchen = w.room("kitchen", 0, 0, 3, 3, "floor_base_0")
    w.bedroom = w.room("bedroom", 10, 0, 13, 3, "floor_base_0")
    w.standing = w.square(1, 1, 0)
end

return Fake
