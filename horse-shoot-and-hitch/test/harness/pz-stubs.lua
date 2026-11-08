--- Just enough of Project Zomboid and the Horse mod to load this mod's game glue
--- and drive it against fake horses, posts, players and weapons outside the game.
local Stubs = {}

Stubs.printed = {}
Stubs.events = {}
Stubs.squares = {}
Stubs.client = false

--- Wraps a Lua list as a Java-style list with size(), get(i), contains and add/remove.
function Stubs.javaList(items)
    local list = { items = items or {} }
    function list:size() return #self.items end
    function list:get(i) return self.items[i + 1] end
    function list:add(x) self.items[#self.items + 1] = x end
    function list:contains(x)
        for _, v in ipairs(self.items) do if v == x then return true end end
        return false
    end
    function list:remove(x)
        for i, v in ipairs(self.items) do if v == x then table.remove(self.items, i) return true end end
        return false
    end
    function list:isEmpty() return #self.items == 0 end
    return list
end

--- Builds an event table with Add and a trigger helper.
local function event(name)
    Stubs.events[name] = {}
    return { Add = function(fn) table.insert(Stubs.events[name], fn) end }
end

--- Calls every handler registered for an event.
function Stubs.fire(name, ...)
    for _, fn in ipairs(Stubs.events[name] or {}) do fn(...) end
end

Events = {}
for _, name in ipairs({ "OnFillWorldObjectContextMenu", "OnWeaponSwing", "OnPlayerAttackFinished",
    "OnPlayerUpdate", "OnSave", "OnTick", "OnInitGlobalModData" }) do
    Events[name] = event(name)
end

function getText(key, a, b)
    local text = key
    if a then text = text .. "(" .. tostring(a) end
    if b then text = text .. "," .. tostring(b) end
    if a then text = text .. ")" end
    return text
end
function isClient() return Stubs.client end
function isServer() return false end
function getTexture() return nil end
print = function(text) table.insert(Stubs.printed, tostring(text)) end
SandboxVars = {}

--- Tells whether a fake object is of a named Java class.
function instanceof(object, className)
    return type(object) == "table" and object._classes ~= nil and object._classes[className] == true
end

--- Fake cell holding squares by coordinates.
local cell = {}
function cell:getGridSquare(x, y, z) return Stubs.squares[x .. "," .. y .. "," .. z] end
function getCell() return cell end

GameTime = { getInstance = function() return { getTimeDelta = function() return Stubs.timeDelta or 0.016 end } end }

--- Builds a fake square at a position and registers it with the cell.
function Stubs.square(x, y, z)
    local sq = { x = x, y = y, z = z or 0, objects = Stubs.javaList({}), worldItems = {} }
    function sq:getX() return self.x end
    function sq:getY() return self.y end
    function sq:getZ() return self.z end
    function sq:getObjects() return self.objects end
    function sq:AddWorldInventoryItem(fullType) table.insert(self.worldItems, fullType) end
    function sq:DistTo(other)
        local dx, dy = self.x - other.x, self.y - other.y
        return math.sqrt(dx * dx + dy * dy)
    end
    Stubs.squares[x .. "," .. y .. "," .. sq.z] = sq
    return sq
end

--- Builds a fake world object (fence, pole, tree, wall) on a square.
function Stubs.object(square, spriteName, opts)
    opts = opts or {}
    local o = { square = square, sprite = spriteName, name = opts.name, _classes = { IsoObject = true } }
    if opts.tree then o._classes.IsoTree = true end
    local props = { values = opts.props or {} }
    function props:has(key) return self.values[key] == true end
    function o:getProperties() return props end
    function o:isHoppable() return opts.hoppable == true end
    function o:isTallHoppable() return opts.tallHoppable == true end
    function o:getSpriteName() return self.sprite end
    function o:getSquare() return self.square end
    function o:getName() return self.name end
    function o:setName(n) self.name = n end
    function o:getObjectIndex() return self.removed and -1 or 0 end
    if square then square.objects:add(o) end
    return o
end

--- Builds a fake inventory that tracks items by full type.
function Stubs.inventory(items)
    local inv = { items = {} }
    function inv:AddItem(fullType)
        local item = { fullType = fullType, container = self }
        function item:getContainer() return self.container end
        table.insert(self.items, item)
        return item
    end
    function inv:getFirstTypeRecurse(itemType)
        for _, item in ipairs(self.items) do
            if item.fullType == "Base." .. itemType then return item end
        end
        return nil
    end
    function inv:Remove(item)
        for i, it in ipairs(self.items) do if it == item then table.remove(self.items, i) return end end
    end
    function inv:count(fullType)
        local n = 0
        for _, it in ipairs(self.items) do if it.fullType == fullType then n = n + 1 end end
        return n
    end
    for _, fullType in ipairs(items or {}) do inv:AddItem(fullType) end
    return inv
end

--- Builds a fake player with an inventory, variables and the methods the mod calls.
function Stubs.player(opts)
    opts = opts or {}
    local p = {
        x = opts.x or 0, y = opts.y or 0, z = 0, vars = {}, inventory = Stubs.inventory(opts.items),
        attached = Stubs.javaList({}), aiming = false, local_ = opts.isLocal ~= false,
        primary = opts.primary, cheat = false, calls = {}, _classes = { IsoPlayer = true },
    }
    setmetatable(p, { __index = IsoPlayerIndex })
    return p
end

--- Method table standing in for __classmetatables[IsoPlayer.class].__index.
IsoPlayerIndex = {}
function IsoPlayerIndex:getInventory() return self.inventory end
function IsoPlayerIndex:getAttachedAnimals() return self.attached end
function IsoPlayerIndex:removeAttachedAnimal(a) self.attached:remove(a) end
function IsoPlayerIndex:isAnimalCheat() return self.cheat end
function IsoPlayerIndex:isTimedActionInstant() return false end
function IsoPlayerIndex:isLocalPlayer() return self.local_ end
function IsoPlayerIndex:isAiming() return self.aiming end
function IsoPlayerIndex:getPrimaryHandItem() return self.primary end
function IsoPlayerIndex:getVariableBoolean(key) return self.vars[key] == true end
function IsoPlayerIndex:getX() return self.x end
function IsoPlayerIndex:getY() return self.y end
function IsoPlayerIndex:getZ() return self.z end
function IsoPlayerIndex:getJoypadBind() return -1 end
function IsoPlayerIndex:getSquare() return Stubs.squares[math.floor(self.x) .. "," .. math.floor(self.y) .. ",0"] end
function IsoPlayerIndex:getPlayerNum() return 0 end
function IsoPlayerIndex:hasAnimationPlayer() return false end
function IsoPlayerIndex:setForwardDirection(x, y) self.forward = { x, y } end
function IsoPlayerIndex:setBannedAttacking(v) self.banned = v end
function IsoPlayerIndex:setIgnoreAimingInput(v) self.ignoreAim = v end
function IsoPlayerIndex:setTargetAndCurrentDirection(x, y) self.pinned = { x, y }; self.forward = { x, y } end
__classmetatables = {}
IsoPlayer = { class = "IsoPlayer.class" }
__classmetatables[IsoPlayer.class] = { __index = IsoPlayerIndex }

--- Builds a fake horse with animal data, mod data and movement calls recorded.
function Stubs.horse(opts)
    opts = opts or {}
    local data = { tree = nil, player = nil }
    function data:getAttachedTree() return self.tree end
    function data:setAttachedTree(t) self.tree = t end
    function data:getAttachedPlayer() return self.player end
    function data:setAttachedPlayer(p) self.player = p end
    function data:getBreed() return nil end
    local h = {
        id = opts.id or 1, x = opts.x or 0, y = opts.y or 0, z = 0, modData = {}, data = data,
        reins = opts.reins == true, dead = false, stops = 0, paths = {}, _classes = { IsoAnimal = true },
        fx = 1, fy = 0,
    }
    function h:getModData() return self.modData end
    function h:getData() return self.data end
    function h:getAnimalID() return self.id end
    function h:isDead() return self.dead end
    function h:getX() return self.x end
    function h:getY() return self.y end
    function h:setX(v) self.x = v end
    function h:setY(v) self.y = v end
    function h:setZ(v) self.z = v end
    function h:stopAllMovementNow() self.stops = self.stops + 1 end
    function h:pathToLocation(x, y, z) table.insert(self.paths, { x, y, z }) end
    function h:getForwardDirectionX() return self.fx end
    function h:getForwardDirectionY() return self.fy end
    function h:getCustomName() return opts.name end
    function h:getAnimalType() return "mare" end
    function h:getCurrentSquare() return Stubs.squares[math.floor(self.x) .. "," .. math.floor(self.y) .. ",0"] end
    return h
end

--- Builds a fake firearm or melee weapon.
function Stubs.weapon(firearm, hitChance)
    local w = { firearm = firearm, hit = hitChance or 50, _classes = { HandWeapon = true } }
    function w:isAimedFirearm() return self.firearm end
    function w:getHitChance() return self.hit end
    function w:setHitChance(v) self.hit = v end
    return w
end

--- Minimal Horse mod Event like HorseMod/Event.
local function horseEvent()
    local e = { callbacks = {} }
    function e:add(fn) table.insert(self.callbacks, fn) end
    function e:trigger(...) for _, fn in ipairs(self.callbacks) do fn(...) end end
    return e
end

Stubs.mounts = { riders = {}, horses = {} }
Stubs.validActions = {}
Stubs.queue = {}
Stubs.dismounts = {}

package.preload["HorseMod/Mounts"] = function()
    local M = { onMount = horseEvent(), onDismount = horseEvent() }
    function M.hasMount(p) return Stubs.mounts.riders[p] ~= nil end
    function M.getMount(p) return Stubs.mounts.riders[p] end
    function M.hasRider(h) return Stubs.mounts.horses[h] ~= nil end
    return M
end
package.preload["HorseMod/HorseManager"] = function() return { systems = {}, horses = {} } end
package.preload["HorseMod/attachments/Attachments"] = function()
    return { getReins = function(h) if h.reins then return "HorseMod.Reins" end return nil end }
end
package.preload["HorseMod/api/RidingAPI"] = function()
    return { addValidTimedAction = function(name) Stubs.validActions[name] = true end }
end
package.preload["HorseMod/definitions/AnimationVariable"] = function()
    return { JUMP = "HorseJump", MOUNTING_HORSE = "HorseMountingHorse", DISMOUNT_STARTED = "HorseDismountStarted",
        GALLOP = "HorseGallop", TROT = "HorseTrot", MOUNTED_MOVING = "HorseMountedMoving" }
end
package.preload["HorseMod/Utils"] = function() return { isAdult = function() return true end } end
package.preload["HorseMod/Mounting"] = function()
    return { dismountHorse = function(p, h, pos) table.insert(Stubs.dismounts, { p, h, pos }) end }
end
package.preload["HorseMod/mounting/MountingUtility"] = function()
    return { getNearestMountPosition = function() return { x = 0, y = 0 } end }
end

--- Vanilla base timed action, enough for derive/new.
ISBaseTimedAction = {}
ISBaseTimedAction.__index = ISBaseTimedAction
function ISBaseTimedAction:derive(name)
    local cls = setmetatable({ Type = name }, { __index = self })
    cls.__index = cls
    return cls
end
function ISBaseTimedAction.new(cls, character)
    return setmetatable({ character = character }, cls)
end
package.preload["TimedActions/ISBaseTimedAction"] = function() return ISBaseTimedAction end

--- Vanilla tree tie and leash actions, reduced to the parts this mod wraps.
ISAttachAnimalToTree = { ropesGiven = 0 }
function ISAttachAnimalToTree.complete(self)
    if self.remove then
        self.animal:getData():setAttachedTree(nil)
        self:takeRope()
    end
    return true
end
function ISAttachAnimalToTree.takeRope(self) ISAttachAnimalToTree.ropesGiven = ISAttachAnimalToTree.ropesGiven + 1 end
ISAttachAnimalToPlayer = { ropesGiven = 0 }
function ISAttachAnimalToPlayer.complete(self)
    if not self.remove and self.animal:getData():getAttachedTree() then
        self:takeRope()
        self.animal:getData():setAttachedTree(nil)
    end
    return true
end
function ISAttachAnimalToPlayer.takeRope(self) ISAttachAnimalToPlayer.ropesGiven = ISAttachAnimalToPlayer.ropesGiven + 1 end
package.preload["TimedActions/Animals/ISAttachAnimalToTree"] = function() return ISAttachAnimalToTree end
package.preload["TimedActions/Animals/ISAttachAnimalToPlayer"] = function() return ISAttachAnimalToPlayer end

ISTimedActionQueue = { add = function(a) table.insert(Stubs.queue, a) end }
luautils = { walkAdj = function() return true end }
ISWorldObjectContextMenu = { addToolTip = function() return { setName = function(t, n) t.name = n end } end }
function getSpecificPlayer() return Stubs.currentPlayer end
function getMouseX() return 0 end
function getMouseY() return 0 end
function screenToIsoX() return Stubs.mouseWorld and Stubs.mouseWorld[1] or 0 end
function screenToIsoY() return Stubs.mouseWorld and Stubs.mouseWorld[2] or 0 end

--- Builds a fake context menu that records added options.
function Stubs.contextMenu()
    local menu = { options = {} }
    function menu:addOption(label, target, fn, a, b)
        local option = { name = label, target = target, onSelect = fn, param1 = a, param2 = b }
        table.insert(self.options, option)
        return option
    end
    return menu
end

return Stubs
