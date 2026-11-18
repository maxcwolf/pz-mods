--- Reads what the Crew tab needs to know about an item from the game's item
--- scripts: its full type, display name, whether it's a weapon (and a gun,
--- one- or two-handed) or clothing, and where clothing is worn. Builds the
--- searchable list of every item once per session.
ALifeRepEditor = ALifeRepEditor or {}

local Info = { cache = nil }
ALifeRepEditor.ItemInfo = Info

--- Calls object:name() safely and returns its first result, or nil.
local function ask(object, name)
    if object == nil then return nil end
    local method = object[name]
    if type(method) ~= "function" then return nil end
    local ok, value = pcall(method, object)
    if not ok then return nil end
    return value
end

--- Returns the item kind from a script's type name: "weapon", "clothing" or "item".
function Info.kindOf(typeName)
    local lowered = string.lower(tostring(typeName or ""))
    if string.find(lowered, "weapon", 1, true) ~= nil then return "weapon" end
    if string.find(lowered, "clothing", 1, true) ~= nil then return "clothing" end
    return "item"
end

--- Returns an item script's details, or nil for a missing or retired item.
function Info.fromScript(script)
    if script == nil then return nil end
    local fullType = ask(script, "getFullName")
    if type(fullType) ~= "string" or fullType == "" then return nil end
    if ask(script, "getObsolete") == true or ask(script, "isHidden") == true then return nil end
    local itemType = ask(script, "getItemType")
    local typeName = itemType ~= nil and (ask(itemType, "toString") or tostring(itemType)) or ask(script, "getTypeString")
    local kind = Info.kindOf(typeName)
    local name = ask(script, "getDisplayName")
    local info = { type = fullType, name = type(name) == "string" and name ~= "" and name or fullType, kind = kind }
    if kind == "weapon" then
        local maxAmmo = tonumber((ask(script, "getMaxAmmo"))) or 0
        info.firearm = ask(script, "isRanged") == true or maxAmmo > 0 or ask(script, "getAmmoType") ~= nil
        info.twoHanded = ask(script, "isTwoHandWeapon") == true
    elseif kind == "clothing" then
        local location = ask(script, "getBodyLocation")
        info.location = location ~= nil and tostring(location) ~= "" and tostring(location) or nil
    end
    return info
end

--- Returns the game's script manager, or nil.
local function manager()
    if type(getScriptManager) ~= "function" then return nil end
    local ok, found = pcall(getScriptManager)
    return ok and found or nil
end

--- Returns one item type's details, or nil when the game has no such item.
function Info.find(fullType)
    local scripts = manager()
    if scripts == nil or type(fullType) ~= "string" or fullType == "" then return nil end
    local ok, script = pcall(scripts.FindItem, scripts, fullType)
    if not ok then return nil end
    return Info.fromScript(script)
end

--- Returns every item in the game as { type, name, kind }, built once.
function Info.catalog()
    if Info.cache ~= nil then return Info.cache end
    local result = {}
    local scripts = manager()
    local list = scripts ~= nil and ask(scripts, "getAllItems") or nil
    local count = tonumber((ask(list, "size"))) or 0
    for index = 0, count - 1 do
        local ok, script = pcall(list.get, list, index)
        local info = ok and Info.fromScript(script) or nil
        if info ~= nil then result[#result + 1] = info end
    end
    if #result > 0 then Info.cache = result end
    return result
end

return Info
