--- Just enough of the Project Zomboid Lua/Java surface to load patch.lua and
--- run it against fake script items and fake players outside the game.
local Stubs = {}

Stubs.items = {}
Stubs.localPlayers = {}
Stubs.onlinePlayers = {}
Stubs.server = false
Stubs.handlers = { OnInitGlobalModData = {}, EveryOneMinute = {}, OnClothingUpdated = {} }

--- Wraps a Lua list as a Java-style list with size() and get(i).
function Stubs.javaList(items)
    return {
        size = function() return #items end,
        get = function(_, i) return items[i + 1] end,
    }
end

--- Builds a fake script item that parses DoParam the way the game does.
--- `extra` may carry a fabric name and a list of item tags.
function Stubs.scriptItem(fullType, itemType, bodyLocation, defense, extra)
    extra = extra or {}
    local item = { fullType = fullType, itemType = itemType, defense = defense or 0, doParamCalls = 0 }
    function item:getFullName() return self.fullType end
    function item:getName() return (string.match(self.fullType, "%.(.+)$")) end
    function item:getCorpseSicknessDefense() return self.defense end
    function item:getFabricType() return extra.fabric end
    function item:isItemType(wanted) return self.itemType == wanted end
    function item:hasTag(tag)
        for _, own in ipairs(extra.tags or {}) do
            if own == tag then return true end
        end
        return false
    end
    function item:getBodyLocation()
        if not bodyLocation then return nil end
        return { toString = function() return bodyLocation end }
    end
    function item:DoParam(param)
        local key, value = string.match(param, "^%s*(.-)%s*=%s*(.-)%s*$")
        assert(string.lower(key) == "corpsesicknessdefense", "unexpected param " .. tostring(key))
        self.defense = assert(tonumber(value), "defense is not a number: " .. tostring(value))
        self.doParamCalls = self.doParamCalls + 1
    end
    return item
end

--- Builds a fake worn clothing item with a per-item filter state.
function Stubs.wornClothing(fullType, hasFilter)
    return {
        javaClass = "Clothing",
        filter = hasFilter,
        getFullType = function() return fullType end,
        hasFilter = function(self) return self.filter end,
    }
end

--- Builds a fake player wearing the given items.
function Stubs.player(wornItems)
    local worn = {
        size = function() return #wornItems end,
        getItemByIndex = function(_, i) return wornItems[i + 1] end,
    }
    return { getWornItems = function() return worn end }
end

--- Replaces the fake item list the script manager hands out.
function Stubs.setItems(items)
    Stubs.items = items
end

--- Finds a fake script item by full type.
function Stubs.find(fullType)
    for _, item in ipairs(Stubs.items) do
        if item.fullType == fullType then return item end
    end
    return nil
end

--- Makes an event table that records the handlers added to it.
local function event(name)
    return { Add = function(fn) table.insert(Stubs.handlers[name], fn) end }
end

ItemType = { CLOTHING = "clothing", NORMAL = "normal" }
ItemTag = { GAS_MASK = "gasmask", RESPIRATOR = "respirator", IMPROVISED_GAS_MASK = "improvisedgasmask" }
SandboxVars = {}
Events = {
    OnInitGlobalModData = event("OnInitGlobalModData"),
    EveryOneMinute = event("EveryOneMinute"),
    OnClothingUpdated = event("OnClothingUpdated"),
}

local scriptManager = {
    getAllItems = function() return Stubs.javaList(Stubs.items) end,
    getItem = function(_, fullType) return Stubs.find(fullType) end,
}
function getScriptManager() return scriptManager end
function isServer() return Stubs.server end
function getNumActivePlayers() return #Stubs.localPlayers end
function getSpecificPlayer(i) return Stubs.localPlayers[i + 1] end
function getOnlinePlayers() return Stubs.javaList(Stubs.onlinePlayers) end
function instanceof(object, className) return type(object) == "table" and object.javaClass == className end

local realRequire = require
--- Ignores the mod's own requires, which the test runner loads by path.
function require(name)
    if string.find(name, "^FaceCoveringProtection/") then return nil end
    return realRequire(name)
end

local realPrint = print
--- Keeps the mod's log line out of the test output.
function print(...)
    local first = ...
    if type(first) == "string" and string.find(first, "[FaceCoveringProtection]", 1, true) then return end
    realPrint(...)
end

return Stubs
