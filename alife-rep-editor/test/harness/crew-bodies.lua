--- Fake NPC bodies with a working inventory, fake items from a small
--- catalog, and a fake game item list, for the Crew tab's tests.
local Bodies = {}

Bodies.ITEMS = {
    ["Base.Axe"] = { type = "Base.Axe", name = "Axe", kind = "weapon", firearm = false },
    ["Base.Shotgun"] = { type = "Base.Shotgun", name = "Shotgun", kind = "weapon", firearm = true, twoHanded = true },
    ["Base.Pistol"] = { type = "Base.Pistol", name = "M9 Pistol", kind = "weapon", firearm = true },
    ["Base.Bandage"] = { type = "Base.Bandage", name = "Bandage", kind = "item" },
    ["Base.Cap"] = { type = "Base.Cap", name = "Cap", kind = "clothing", location = "Hat" },
    ["Base.Beret"] = { type = "Base.Beret", name = "Beret", kind = "clothing", location = "Hat" },
    ["Base.Tee"] = { type = "Base.Tee", name = "T-shirt", kind = "clothing", location = "Tshirt" },
}

local ITEMS = Bodies.ITEMS
local nextId = 0

--- Makes a fake inventory item of a type from the test catalog.
function Bodies.makeItem(itemType)
    local info = ITEMS[itemType]
    nextId = nextId + 1
    local item = { id = nextId, fullType = itemType, data = {}, info = info, loaded = 0 }
    function item:getID() return self.id end
    function item:getFullType() return self.fullType end
    function item:getDisplayName() return self.info.name end
    function item:getModData() return self.data end
    function item:IsWeapon() return self.info.kind == "weapon" end
    function item:getMaxAmmo() return self.info.firearm and 6 or 0 end
    function item:getCurrentAmmoCount() return self.loaded end
    function item:isAimedFirearm() return self.info.firearm == true end
    return item
end

--- Stands the player at a spot.
function Bodies.stand(player, x, y)
    function player:getX() return x end
    function player:getY() return y end
    function player:getZ() return 0 end
end

--- Loads an NPC's body with a working inventory beside the player, and returns it.
function Bodies.body(uid, x, y)
    local list = {}
    local items = { list = list }
    function items:size() return #self.list end
    function items:get(index) return self.list[index + 1] end
    local inventory = { items = items }
    function inventory:getItems() return self.items end
    function inventory:AddItem(itemType)
        if ITEMS[itemType] == nil then return nil end
        local item = Bodies.makeItem(itemType)
        self.items.list[#self.items.list + 1] = item
        return item
    end
    function inventory:Remove(item)
        for index, held in ipairs(self.items.list) do
            if held == item then table.remove(self.items.list, index) return end
        end
    end
    local shell = { x = x, y = y, data = { ProjectALifeUID = uid }, inventory = inventory, variables = {} }
    function shell:getX() return self.x end
    function shell:getY() return self.y end
    function shell:getZ() return 0 end
    function shell:isDead() return false end
    function shell:getModData() return self.data end
    function shell:getInventory() return self.inventory end
    function shell:SetVariable(name, value) self.variables[name] = value end
    ProjectALife.Watchdog = ProjectALife.Watchdog or { bindings = {} }
    ProjectALife.Watchdog.bindings[uid] = { shell = shell }
    return shell
end

--- Returns a fake script manager listing the test catalog, as the client's item search reads it.
function Bodies.scriptManager()
    local scripts, byType = {}, {}
    for _, info in pairs(ITEMS) do
        local script = {}
        function script:getFullName() return info.type end
        function script:getDisplayName() return info.name end
        function script:getTypeString() return info.kind == "weapon" and "Weapon" or info.kind == "clothing" and "Clothing" or "Normal" end
        function script:getMaxAmmo() return info.firearm and 6 or 0 end
        function script:isTwoHandWeapon() return info.twoHanded == true end
        function script:getBodyLocation() return info.location or "" end
        scripts[#scripts + 1] = script
        byType[info.type] = script
    end
    local list = {}
    function list:size() return #scripts end
    function list:get(index) return scripts[index + 1] end
    return { getAllItems = function() return list end, FindItem = function(_, fullType) return byType[fullType] end }
end

return Bodies
