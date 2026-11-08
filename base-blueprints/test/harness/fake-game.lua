--- A small stand-in for the game's map, objects, files and events. It copies
--- the engine behavior this mod depends on, read from the 42.21 jar and the
--- game's Lua:
--- - IsoObject.toString ends with Java's "zombie.iso....Class@hash";
--- - IsoDoor's string constructor takes a closed or open sprite name;
--- - square objects are an ordered list, the floor first, AddSpecialObject
---   inserts at an index, RemoveTileObject takes the object out;
--- - getChunkForGridSquare is nil where the map is not loaded, getGridSquare
---   is nil where the map has no square, createNewGridSquare makes one;
--- - getFileReader returns nil for a missing file; files outlive saves;
--- - ModData.getOrCreate is per save.
local Fake = {}

local nextHash = 4096

--- Wraps a Lua list in the Java ArrayList methods the mod calls.
function Fake.list(values)
    local list = { values = values or {} }
    --- Returns the list size.
    function list:size() return #self.values end
    --- Returns the element at a zero-based index.
    function list:get(i) return self.values[i + 1] end
    return list
end

--- Makes sprite properties holding a set of flags.
local function properties(flags)
    local props = { flags = flags or {} }
    --- Returns true when the flag is set.
    function props:has(flag) return self.flags[flag] == true end
    return props
end

--- Makes a sprite fake.
local function sprite(name, flags)
    local s = { name = name, props = properties(flags) }
    --- Returns the sprite name.
    function s:getName() return self.name end
    --- Returns the sprite properties.
    function s:getProperties() return self.props end
    return s
end

--- Makes a container with a type.
function Fake.container(type)
    local c = { type = type, items = {}, explored = false }
    --- Returns the container type.
    function c:getType() return self.type end
    --- Returns the items as a list.
    function c:getItems()
        local wrapped = {}
        for i, item in ipairs(self.items) do
            local fullType = item
            wrapped[i] = { getFullType = function() return fullType end }
        end
        return Fake.list(wrapped)
    end
    --- Adds n items of a type.
    function c:AddItems(t, n)
        for _ = 1, n do
            self.items[#self.items + 1] = t
        end
    end
    --- Marks the container explored.
    function c:setExplored(v) self.explored = v end
    return c
end

local CLASS_PATH = {
    IsoObject = "zombie.iso.IsoObject",
}

--- Makes a map object of a class with a sprite name.
function Fake.object(cls, spriteName, opts)
    opts = opts or {}
    nextHash = nextHash + 1
    local obj = {
        cls = cls,
        sprite = Fake.world and Fake.world.sprite(spriteName) or sprite(spriteName),
        north = opts.north == true,
        attached = {},
        overlay = nil,
        yOffset = 0,
        modData = nil,
        containers = {},
        name = opts.name,
        square = nil,
        hash = string.format("%x", nextHash),
        thump = {},
    }
    local mt = {}
    --- Mimics IsoObject.toString.
    mt.__tostring = function(self)
        local path = CLASS_PATH[self.cls] or ("zombie.iso.objects." .. self.cls)
        return tostring(self.name) .. tostring(self.sprite and self.sprite.name) .. path .. "@" .. self.hash
    end
    setmetatable(obj, mt)

    --- Returns the sprite.
    function obj:getSprite() return self.sprite end
    --- Sets the sprite.
    function obj:setSprite(s) self.sprite = s end
    --- Returns sprite properties.
    function obj:getProperties() return self.sprite and self.sprite.props end
    --- Returns facing.
    function obj:getNorth() return self.north end
    --- Returns the overlay sprite.
    function obj:getOverlaySprite() return self.overlay and sprite(self.overlay) end
    --- Returns the overlay color.
    function obj:getOverlaySpriteColor()
        local c = self.overlayColor or { 1, 1, 1, 1 }
        return { getR = function() return c[1] end, getG = function() return c[2] end,
                 getB = function() return c[3] end, getA = function() return c[4] end }
    end
    --- Sets the overlay sprite.
    function obj:setOverlaySprite(name, r, g, b, a)
        self.overlay = name
        self.overlayColor = r and { r, g, b, a } or nil
    end
    --- Returns attached sprites as instances.
    function obj:getAttachedAnimSprite()
        local list = {}
        for i, name in ipairs(self.attached) do
            list[i] = { getParentSprite = function() return sprite(name) end }
        end
        return Fake.list(list)
    end
    --- Attaches a sprite.
    function obj:AttachExistingAnim(s) self.attached[#self.attached + 1] = s.name end
    --- Clears attached sprites.
    function obj:clearAttachedAnimSprite() self.attached = {} end
    --- Returns the render y offset.
    function obj:getRenderYOffset() return self.yOffset end
    --- Sets the render y offset.
    function obj:setRenderYOffset(v) self.yOffset = v end
    --- Returns true when mod data exists.
    function obj:hasModData() return self.modData ~= nil end
    --- Returns (creating) mod data.
    function obj:getModData() self.modData = self.modData or {}; return self.modData end
    --- Returns the number of containers.
    function obj:getContainerCount() return #self.containers end
    --- Returns a container by zero-based index.
    function obj:getContainerByIndex(i) return self.containers[i + 1] end
    --- Creates containers from the sprite's "container" flag once.
    function obj:createContainersFromSpriteProperties()
        if #self.containers == 0 and self.sprite.props.flags.container then
            self.containers[1] = Fake.container(self.sprite.props.flags.container)
        end
    end
    --- Returns the index in the square's object list.
    function obj:getObjectIndex()
        if not self.square then return -1 end
        for i, o in ipairs(self.square.objects) do
            if o == self then return i - 1 end
        end
        return -1
    end
    --- Returns the custom name.
    function obj:getName() return self.name end
    --- Sets the custom name.
    function obj:setName(v) self.name = v end
    --- Unlocks a window.
    function obj:setIsLocked() end
    --- Adds a light source.
    function obj:addLightSourceFromSprite() self.light = true end
    --- Marks as moved thumpable.
    function obj:setMovedThumpable(v) self.moved = v end
    --- Sets the square.
    function obj:setSquare(sq) self.square = sq end
    --- Returns the square.
    function obj:getSquare() return self.square end
    for _, pair in ipairs({
        { "isDoor", "setIsDoor", "door" }, { "isDoorFrame", "setIsDoorFrame", "doorFrame" },
        { "isCorner", "setCorner", "corner" }, { "isFloor", "setIsFloor", "thumpFloor" },
        { "isStairs", "setIsStairs", "stairs" }, { "isBlockAllTheSquare", "setBlockAllTheSquare", "blockAll" },
        { "isCanPassThrough", "setCanPassThrough", "pass" }, { "isHoppable", "setIsHoppable", "hoppable" },
        { "isThumpable", "setIsThumpable", "thumpable" }, { "getCanBarricade", "setCanBarricade", "barricade" },
        { "isDismantable", "setIsDismantable", "dismantable" }, { "isPaintable", "setPaintable", "paintable" },
    }) do
        local field = pair[3]
        obj[pair[1]] = function(self) return self.thump[field] == true end
        obj[pair[2]] = function(self, v) self.thump[field] = v end
    end
    for _, pair in ipairs({ { "getMaxHealth", "setMaxHealth", "maxHealth", 500 }, { "getHealth", "setHealth", "health", 500 },
        { "getCrossSpeed", "setCrossSpeed", "crossSpeed", 1 } }) do
        local field, default = pair[3], pair[4]
        obj[pair[1]] = function(self) return self.thump[field] or default end
        obj[pair[2]] = function(self, v) self.thump[field] = v end
    end
    return obj
end

--- Makes a square at x, y, z.
local function square(world, x, y, z)
    local sq = { x = x, y = y, z = z, objects = {}, building = nil, recalcs = 0 }
    --- Returns x.
    function sq:getX() return self.x end
    --- Returns y.
    function sq:getY() return self.y end
    --- Returns z.
    function sq:getZ() return self.z end
    --- Returns the objects list.
    function sq:getObjects() return Fake.list(self.objects) end
    --- Returns the floor (the first object flagged as floor).
    function sq:getFloor()
        for _, o in ipairs(self.objects) do
            if o.isFloorTile then return o end
        end
        return nil
    end
    --- Adds a floor at the front.
    function sq:addFloor(name)
        local floor = Fake.object("IsoObject", name)
        floor.isFloorTile = true
        floor.square = self
        table.insert(self.objects, 1, floor)
        return floor
    end
    --- Removes an object.
    function sq:RemoveTileObject(obj)
        for i, o in ipairs(self.objects) do
            if o == obj then
                table.remove(self.objects, i)
                obj.square = nil
                return i - 1
            end
        end
        return -1
    end
    --- Inserts an object at a zero-based index.
    function sq:AddSpecialObject(obj, index)
        index = index or #self.objects
        if index > #self.objects then
            error("AddSpecialObject index " .. index .. " past " .. #self.objects)
        end
        obj.square = self
        table.insert(self.objects, index + 1, obj)
    end
    --- Counts recalculations.
    function sq:RecalcProperties() self.recalcs = self.recalcs + 1 end
    --- Counts recalculations.
    function sq:RecalcAllWithNeighbours() self.recalcs = self.recalcs + 1 end
    --- Returns the building.
    function sq:getBuilding() return self.building end
    --- Returns a room id.
    function sq:getRoomID() return 7 end
    return sq
end

--- Makes a fresh world (one save). Files survive across worlds unless reset.
function Fake.newWorld(opts)
    opts = opts or {}
    local world = { squares = {}, loaded = {}, modData = {}, events = {}, highlights = {}, notes = {}, added = {}, spriteFlags = {} }
    Fake.world = world
    Fake.files = (opts.keepFiles and Fake.files) or {}

    --- Returns a sprite fake (nil for names marked missing).
    function world.sprite(name)
        if name == nil or (world.missing and world.missing[name]) then
            return nil
        end
        return sprite(name, world.spriteFlags[name])
    end
    --- Returns a square key.
    local function key(x, y, z) return x .. "," .. y .. "," .. z end
    --- Marks a column loaded or not.
    function world.setLoaded(x, y, on) world.loaded[x .. "," .. y] = on ~= false end
    --- Returns (creating) a square.
    function world.square(x, y, z)
        local k = key(x, y, z)
        world.squares[k] = world.squares[k] or square(world, x, y, z)
        world.setLoaded(x, y, true)
        return world.squares[k]
    end
    --- Adds an object to a square.
    function world.put(x, y, z, cls, spriteName, opts2)
        local sq = world.square(x, y, z)
        local obj = Fake.object(cls, spriteName, opts2)
        if opts2 and opts2.floor then
            obj.isFloorTile = true
            table.insert(sq.objects, 1, obj)
        else
            sq.objects[#sq.objects + 1] = obj
        end
        obj.square = sq
        obj:createContainersFromSpriteProperties()
        return obj
    end

    local cell = {}
    --- Returns a loaded square or nil.
    function cell:getGridSquare(x, y, z)
        if not world.loaded[x .. "," .. y] then return nil end
        return world.squares[key(x, y, z)]
    end
    --- Returns a chunk where the map is loaded.
    function cell:getChunkForGridSquare(x, y, z)
        return world.loaded[x .. "," .. y] and {} or nil
    end
    --- Creates a square.
    function cell:createNewGridSquare(x, y, z) return world.square(x, y, z) end
    world.cell = cell

    _G.getCell = function() return cell end
    _G.getSprite = function(name) return world.sprite(name) end
    _G.instanceof = function(obj, name) return type(obj) == "table" and obj.cls == name end
    _G.IsoFlagType = { canBeRemoved = "canBeRemoved" }
    _G.GameEntityFactory = { CreateIsoEntityFromCellLoading = function() end }
    _G.triggerEvent = function(name, obj)
        if name == "OnObjectAdded" then world.added[#world.added + 1] = obj end
    end
    _G.getScriptManager = function()
        return { FindItem = function(_, t) return string.sub(t, 1, 7) ~= "Missing" end }
    end
    _G.ModData = { getOrCreate = function(name)
        world.modData[name] = world.modData[name] or {}
        return world.modData[name]
    end }
    _G.getFileReader = function(name)
        local text = Fake.files[name]
        if text == nil then return nil end
        local lines = {}
        for line in string.gmatch(text, "([^\n]*)\n") do lines[#lines + 1] = line end
        local i = 0
        return { readLine = function() i = i + 1; return lines[i] end, close = function() end }
    end
    _G.getFileWriter = function(name)
        local parts = {}
        return { write = function(_, s) parts[#parts + 1] = s end,
                 close = function() Fake.files[name] = table.concat(parts) end }
    end
    local clock = 1730000000
    _G.getTimestamp = function() clock = clock + 1; return clock end
    _G.getTimestampMs = function() return clock * 1000 end
    _G.getText = function(k, ...)
        local args = { ... }
        if #args == 0 then return k end
        return k .. "(" .. table.concat(args, "|") .. ")"
    end
    _G.isClient = function() return false end
    world.player = { z = 0 }
    --- Returns the player's level.
    function world.player:getZ() return self.z end
    --- Returns the player number.
    function world.player:getPlayerNum() return 0 end
    --- Records a halo note.
    function world.player:setHaloNote(text) world.notes[#world.notes + 1] = text end
    _G.getPlayer = function() return world.player end
    _G.addAreaHighlightForPlayer = function(p, x1, y1, x2, y2, z, r, g, b, a)
        world.highlights[#world.highlights + 1] = { x1 = x1, y1 = y1, x2 = x2, y2 = y2, z = z, r = r }
    end
    _G.instanceItem = function(t) return { type = t } end
    _G.Events = setmetatable({}, { __index = function(t, name)
        local ev = { handlers = {} }
        --- Registers a handler.
        function ev.Add(fn) ev.handlers[#ev.handlers + 1] = fn end
        rawset(t, name, ev)
        return ev
    end })

    -- Constructors with the game's argument shapes.
    local function ctor(cls)
        return { new = function(_, sq, s, north)
            local name = type(s) == "table" and s.name or s
            return Fake.object(cls, name, { north = north == true })
        end }
    end
    _G.IsoObject = ctor("IsoObject")
    _G.IsoDoor = ctor("IsoDoor")
    _G.IsoWindow = ctor("IsoWindow")
    _G.IsoWindowFrame = ctor("IsoWindowFrame")
    _G.IsoCurtain = ctor("IsoCurtain")
    _G.IsoThumpable = { new = function(_, sq, s, north) return Fake.object("IsoThumpable", s, { north = north }) end }
    _G.IsoLightSwitch = { new = function(_, sq, s) return Fake.object("IsoLightSwitch", s.name) end }
    _G.IsoMannequin = ctor("IsoMannequin")
    _G.IsoStove = ctor("IsoStove")
    _G.ISMoveableSpriteProps = { new = function(s)
        return { placeMoveableInternal = function(self, player, sq, item, name)
            local obj = Fake.object("IsoMultiMedia", name)
            sq:AddSpecialObject(obj, #sq.objects)
            world.brushed = (world.brushed or 0) + 1
            return obj
        end }
    end }
    return world
end

--- Makes a building def for squares in a box.
function Fake.building(world, x, y, w, h, maxLevel)
    local def = {}
    for _, pair in ipairs({ { "getX", x }, { "getY", y }, { "getW", w }, { "getH", h }, { "getMinLevel", 0 }, { "getMaxLevel", maxLevel or 0 } }) do
        local value = pair[2]
        def[pair[1]] = function() return value end
    end
    local building = { getDef = function() return def end }
    for bx = x, x + w - 1 do
        for by = y, y + h - 1 do
            world.square(bx, by, 0).building = building
        end
    end
    return building
end

return Fake
