--- A small fake of the game as the vehicle window and CSV_Runtime see it at
--- the main menu: a script manager whose vehicle scripts keep their text but
--- whose templates keep none (as in the real game), items, translations, and
--- BaseVehicle.new building parts from each script's final part list.
local FakeGame = {}

--- A Java-style ArrayList over a Lua list.
function FakeGame.arrayList(list)
    return {
        size = function() return #list end,
        get = function(_, i) return list[i + 1] end,
        isEmpty = function() return #list == 0 end,
    }
end

--- A fake script part with model ids and files.
local function scriptPart(id, models)
    models = models or {}
    return {
        getId = function() return id end,
        getModelCount = function() return #models end,
        getModel = function(_, i)
            local m = models[i + 1]
            local zero = { x = function() return 0 end, y = function() return 0 end, z = function() return 0 end }
            return {
                getId = function() return m.id end,
                getFile = function() return m.file end,
                getOffset = function() return zero end,
                getRotate = function() return zero end,
                getScale = function() return 1 end,
                getAttachmentNameParent = function() return nil end,
                getAttachmentNameSelf = function() return nil end,
            }
        end,
    }
end

--- A fake engine part, as BaseVehicle builds it after setScript().
function FakeGame.enginePart(def)
    return {
        getId = function() return def.id end,
        getItemType = function() return def.itemTypes and FakeGame.arrayList(def.itemTypes) or nil end,
        getCategory = function() return def.category end,
        getWheelIndex = function() return def.wheel or -1 end,
        getDoor = function() return def.door and {} or nil end,
        getWindow = function() return def.window and {} or nil end,
        isContainer = function() return def.container == true end,
        getContainerCapacity = function() return def.capacity or 0 end,
        isSpecificItem = function() return def.specificItem == true end,
        getScriptPart = function() return scriptPart(def.id, def.models) end,
    }
end

FakeGame.TRUCK_BODY = [[
vehicle TestTruck
{
    mechanicType = 2,
    textureMask = Vehicles/Vehicles_TestTruck_Mask,
    textureRust = Vehicles/Vehicles_TestTruck_Rust,
    template = DAMNglobal,
    template = TTBumpers,
    template = Tire,
    skin { texture = Vehicles/Vehicles_TestTruck_Shell_red, }
    skin { texture = Vehicles/Vehicles_TestTruck_Shell_blue, }
}
]]

FakeGame.TRUCK_PARTS = {
    { id = "DAMNBumperFront", category = "bodywork",
      itemTypes = { "Base.TTBumperFront", "Base.TTBullbarFront" },
      models = { { id = "Bumper", file = "TTBumper0" }, { id = "Bullbar", file = "TTBullbar1" } } },
    { id = "TireFrontLeft", category = "tire", wheel = 0, itemTypes = { "Base.OldTire2", "Base.NormalTire2" } },
    { id = "TireFrontRight", category = "tire", wheel = 1, itemTypes = { "Base.OldTire2", "Base.NormalTire2" } },
    { id = "SeatFrontLeft", category = "seat", container = true, capacity = 20 },
    { id = "TruckBed", category = "Other", container = true, capacity = 80 },
    { id = "GloveBox", category = "Other", container = true, capacity = 5 },
    { id = "DoorFrontLeft", category = "door", door = true,
      models = { { id = "Door", file = "TTDoor" }, { id = "Ghost", file = "GhostModel" }, { id = "Blank", file = "" } } },
}

FakeGame.TRAILER_PARTS = {
    { id = "TrailerTrunk", category = "Other", container = true, capacity = 200 },
    { id = "TireRearLeft", category = "tire", wheel = 0, itemTypes = { "Base.OldTire2" } },
}

FakeGame.ITEMS = {
    ["Base.TTBumperFront"] = "Bumper", ["Base.TTBullbarFront"] = "Bullbar",
    ["Base.OldTire2"] = "Old Tire", ["Base.NormalTire2"] = "Tire",
}

--- Returns a fake vehicle script.
local function vehicleScript(fullName, shortName, body, parts, skins)
    local partCount = #parts
    return {
        getPart = function(_, i) return scriptPart(parts[i + 1].id, parts[i + 1].models) end,
        getName = function() return shortName end,
        getFullName = function() return fullName end,
        isDebugOnly = function() return false end,
        getPartCount = function() return partCount end,
        getSkinCount = function() return skins end,
        getMechanicType = function() return 2 end,
        getCarMechanicsOverlay = function() return nil end,
        getLoadedScriptBodies = function() return FakeGame.arrayList({ "TestMod", body }) end,
        getModel = function()
            return {
                getFile = function() return shortName .. "Body" end,
                getOffset = function() return { x = function() return 0 end, y = function() return 0.5 end, z = function() return 0 end } end,
                getRotate = function() return { x = function() return 0 end, y = function() return 0 end, z = function() return 0 end } end,
            }
        end,
        getModelOffset = function() return { x = function() return 0 end, y = function() return 0.5 end, z = function() return 0 end } end,
        getModelScale = function() return 0.9 end,
    }
end

--- A fake model script as the game keeps it: name, mesh and its text.
function FakeGame.modelScript(name)
    local short = string.match(name, "([^%.]+)$")
    local body = "model " .. short .. " { mesh = vehicles/" .. short .. "|body, shader = vehicle, scale = 0.1, }"
    return {
        name = name,
        getFullType = function() return "Base." .. short end,
        getModule = function() return "BaseModule" end,
        getMeshName = function() return "vehicles/" .. short .. "|body" end,
        isStatic = function() return false end,
        getLoadedScriptBodies = function() return FakeGame.arrayList({ "TestMod", body }) end,
    }
end

--- A fake of the shipped preview slot: copies parts by id and records loads.
function FakeGame.previewSlot()
    local slot = { parts = {}, loads = {}, copies = 0 }
    FakeGame.slot = slot
    --- Replaces or adds each of another script's parts, like copyPartsFrom.
    function slot:copyPartsFrom(other)
        self.copies = self.copies + 1
        for i = 0, other:getPartCount() - 1 do
            local part = other:getPart(i)
            local found = false
            for j, mine in ipairs(self.parts) do
                if mine:getId() == part:getId() then self.parts[j] = part found = true end
            end
            if not found then self.parts[#self.parts + 1] = part end
        end
    end
    function slot:copyWheelsFrom(other) self.wheelsFrom = other:getFullName() end
    function slot:Load(name, text) self.loads[#self.loads + 1] = { name = name, text = text } end
    function slot:getPartCount() return #self.parts end
    function slot:getPart(i) return self.parts[i + 1] end
    function slot:getFullName() return "Base.CSV_PreviewVehicle" end
    function slot:getName() return "CSV_PreviewVehicle" end
    function slot:isDebugOnly() return false end
    function slot:getSkinCount() return 0 end
    function slot:getLoadedScriptBodies() return FakeGame.arrayList({}) end
    return slot
end

--- Installs the fake script manager, translator and BaseVehicle globals.
function FakeGame.install()
    FakeGame.addedModelScripts = {}
    FakeGame.addCount = 0
    ModelScript = {
        new = function()
            local m = {}
            function m:setModule(module) self.module = module end
            function m:InitLoadPP(name) self.name = name end
            function m:Load(name, text) self.loadedName, self.text = name, text end
            function m:getFullType() return "Base." .. self.name end
            return m
        end,
    }
    local scripts = {
        ["Base.TestTruck"] = vehicleScript("Base.TestTruck", "TestTruck", FakeGame.TRUCK_BODY, FakeGame.TRUCK_PARTS, 2),
        ["Base.TrailerTest"] = vehicleScript("Base.TrailerTest", "TrailerTest", "vehicle TrailerTest { }", FakeGame.TRAILER_PARTS, 1),
        ["Base.CSV_PreviewVehicle"] = FakeGame.previewSlot(),
    }
    local partsOf = { ["Base.TestTruck"] = FakeGame.TRUCK_PARTS, ["Base.TrailerTest"] = FakeGame.TRAILER_PARTS }
    local template = { getLoadedScriptBodies = function() return FakeGame.arrayList({}) end }
    getScriptManager = function()
        return {
            getAllVehicleScripts = function()
                return FakeGame.arrayList({ scripts["Base.TestTruck"], scripts["Base.TrailerTest"], scripts["Base.CSV_PreviewVehicle"] })
            end,
            getVehicle = function(_, name) return scripts[name] end,
            getVehicleTemplate = function() return template end,
            getModelScript = function(_, name)
                if name == nil or name == "" or string.find(name, "Ghost", 1, true) then return nil end
                if string.find(name, "CSV_PreviewBody_", 1, true) then
                    return FakeGame.addedModelScripts[name]
                end
                return FakeGame.modelScript(name)
            end,
            addModelScript = function(_, script)
                FakeGame.addedModelScripts[script:getFullType()] = script
                FakeGame.addCount = FakeGame.addCount + 1
            end,
            FindItem = function(_, t)
                local label = FakeGame.ITEMS[t]
                return label and { getDisplayName = function() return label end } or nil
            end,
        }
    end
    getText = function(key, a, b)
        local text = key
        if a then text = text .. " " .. tostring(a) end
        if b then text = text .. " " .. tostring(b) end
        return text
    end
    getTextOrNull = function() return nil end
    BaseVehicle = {
        new = function()
            local v = { parts = {} }
            function v:setScriptName(name) self.name = name end
            function v:setScript()
                for _, def in ipairs(partsOf[self.name] or {}) do
                    self.parts[#self.parts + 1] = FakeGame.enginePart(def)
                end
            end
            function v:getPartCount() return #self.parts end
            function v:getPartByIndex(i) return self.parts[i + 1] end
            return v
        end,
    }
end

--- Loads a fresh copy of a client file by its path under client/.
function FakeGame.load(path)
    dofile(TEST_ROOT .. "/mod/ChooseStartingVehicle/42/media/lua/client/" .. path)
end

return FakeGame
