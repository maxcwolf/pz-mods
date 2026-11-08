--- The rotating 3D view of the vehicle being built. The game's 3D scene draws
--- a vehicle script with every model of every part at once (all three bumpers
--- on top of each other) in its first paint. So the build view draws the
--- preview slot instead (preview-slot.lua): a never-spawned vehicle script this
--- mod ships, rebuilt from the chosen vehicle with only the chosen part models
--- and the chosen paint (body-model.lua). The scene draws it like any vehicle,
--- with the game's shaders and bone-rigged doors. ADR 0009.
---
--- A Java error while the scene draws aborts every UI element drawn after it,
--- so a marker element drawn right after the scene tells preview-watch.lua
--- whether each frame got through; a long run of failed frames, or a slot that
--- can't be built, drops to the game's plain vehicle. "Show every part model"
--- picks the plain view on purpose. Drag to turn, wheel to zoom. ADR 0008.
require "ISUI/ISPanel"
require "ISUI/ISUIElement"
require "Vehicles/ISUI/ISUI3DScene"
require "ChooseStartingVehicle/runtime"
local BodyModel = require("ChooseStartingVehicle/body-model")
local PreviewPlan = require("ChooseStartingVehicle/preview-plan")
local PreviewSlot = require("ChooseStartingVehicle/preview-slot")
local PreviewWatch = require("ChooseStartingVehicle/preview-watch")

local VEHICLE = "vehicle"
local LOG = "[ChooseStartingVehicle] 3D preview: "

CSV_VehiclePreview = ISPanel:derive("CSV_VehiclePreview")
CSV_VehiclePreview.MAX_ZOOM = 20

CSV_PreviewMarker = ISUIElement:derive("CSV_PreviewMarker")

--- Records that the frame got past the scene.
function CSV_PreviewMarker:render()
    self.owner.markerFrame = self.owner.frame
end

--- Creates the preview panel.
function CSV_VehiclePreview:new(x, y, width, height)
    local o = ISPanel.new(self, x, y, width, height)
    o.backgroundColor = { r = 0.12, g = 0.12, b = 0.12, a = 1 }
    o.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    o.showAll = false
    o.frame = 0
    o.watch = PreviewWatch.new()
    o.zoom = 7
    return o
end

--- Runs one scene command, logging (once per command) instead of throwing.
function CSV_VehiclePreview:call(method, ...)
    local scene = self.scene and self.scene.javaObject
    if not scene then
        return nil, false
    end
    local args = { ... }
    local count = select("#", ...)
    local ok, result = pcall(function()
        return scene[method](scene, unpack(args, 1, count))
    end)
    if not ok then
        self.errors = self.errors or {}
        local key = tostring(args[1])
        if not self.errors[key] then
            self.errors[key] = true
            print(LOG .. key .. " failed: " .. tostring(result))
        end
        return nil, false
    end
    return result, true
end

--- Builds the 3D scene with the view the game's attachment editor uses, and
--- the watchdog marker after it.
function CSV_VehiclePreview:createChildren()
    ISPanel.createChildren(self)
    self.scene = ISUI3DScene:new(1, 1, self.width - 2, self.height - 2)
    self.scene.backgroundColor = { r = 0.12, g = 0.12, b = 0.12, a = 1 }
    self:addChild(self.scene)
    self.marker = CSV_PreviewMarker:new(0, 0, 1, 1)
    self.marker.owner = self
    self:addChild(self.marker)
    self.scene:setView("UserDefined")
    self:call("fromLua1", "setMaxZoom", CSV_VehiclePreview.MAX_ZOOM)
    self:resetView()
    self:call("fromLua1", "setDrawGrid", false)
    self:call("fromLua1", "setDrawGridAxes", false)
    self:call("fromLua1", "setDrawGridPlane", false)
    self:call("fromLua1", "createVehicle", VEHICLE)
    self:call("fromLua2", "setObjectVisible", VEHICLE, false)
end

--- Turns the camera back to a front three-quarter view at the fitted zoom.
function CSV_VehiclePreview:resetView()
    self:call("fromLua3", "setViewRotation", 25.0, 45.0 + 90.0, 0.0)
    self:call("fromLua1", "setZoom", self.zoom)
end

--- Fits the zoom to a vehicle script's size.
function CSV_VehiclePreview:fitTo(script)
    local length, width = 0, 0
    pcall(function()
        local extents = script:getExtents()
        length, width = extents:z(), extents:x()
    end)
    self.zoom = PreviewWatch.fitZoom(length, width, self.width, self.height, CSV_VehiclePreview.MAX_ZOOM)
    self:resetView()
end

--- True when the game has a model script by this name.
local function modelExists(file)
    local ok, script = pcall(function() return getScriptManager():getModelScript(file) end)
    return ok and script ~= nil
end

--- Returns a vector's x, y and z as a list.
local function xyz(v)
    return { v:x(), v:y(), v:z() }
end

--- Lists a vehicle script's parts as {id, models = {{id, file, offset,
--- rotate, scale, parent, self}...}}, id "" for a model with no id.
local function readParts(script)
    local parts = {}
    for i = 0, script:getPartCount() - 1 do
        local part = script:getPart(i)
        local models = {}
        for j = 0, part:getModelCount() - 1 do
            local m = part:getModel(j)
            models[#models + 1] = {
                id = m:getId() or "",
                file = m:getFile(),
                offset = xyz(m:getOffset()),
                rotate = xyz(m:getRotate()),
                scale = m:getScale(),
                parent = m:getAttachmentNameParent(),
                self = m:getAttachmentNameSelf(),
            }
        end
        parts[#parts + 1] = { id = part:getId(), models = models }
    end
    return parts
end

--- Returns the kept text bodies of a script object as a list of strings.
local function bodiesOf(script)
    local list = {}
    for _, pair in ipairs(CSV_Runtime.scriptBodies(script)) do
        list[#list + 1] = pair.body
    end
    return list
end

--- Returns the full name of the vehicle's body copy in one paint, registering
--- it with the script manager the first time.
local function bodyCopy(script, skinIndex, texture)
    local manager = getScriptManager()
    local file = script:getModel():getFile()
    local original = manager:getModelScript(file)
    if not original then
        error("no model script " .. tostring(file))
    end
    local name = BodyModel.scriptName(script:getFullName(), skinIndex)
    local full = BodyModel.moduleOf(original:getFullType()) .. "." .. name
    if manager:getModelScript(full) then
        return full
    end
    local bodies = bodiesOf(original)
    local text = BodyModel.copyText(bodies[#bodies], name, texture)
    if not text then
        error("the game kept no text for model script " .. tostring(file))
    end
    local copy = ModelScript.new()
    copy:setModule(original:getModule())
    copy:InitLoadPP(name)
    copy:Load(name, text)
    manager:addModelScript(copy)
    return full
end

--- Rebuilds the preview slot for a vehicle entry and build section, and
--- returns its signature; throws when the vehicle can't be shown this way.
function CSV_VehiclePreview:buildSlot(entry, section)
    local manager = getScriptManager()
    local slot = manager:getVehicle(PreviewSlot.FULL_NAME)
    if not slot then
        error("the preview slot vehicle script is missing")
    end
    local original = manager:getVehicle(entry.name)
    local skinIndex = (section and section.skin) or 0
    local texture = PreviewPlan.bodyTexture(entry.skinTextures, skinIndex)
    if not texture then
        error("no paint texture in the script text")
    end
    local textures = PreviewSlot.textures(bodiesOf(original))
    if not PreviewSlot.hasMask(textures) then
        error("no textureMask in the script text")
    end
    local wanted = PreviewSlot.wantedSet(PreviewPlan.models(entry.parts, section and section.parts, modelExists))
    local signature = PreviewSlot.signature(entry.name, skinIndex, wanted)
    if signature == self.slotSignature then
        return signature
    end
    local bodyName = bodyCopy(original, skinIndex, texture)
    slot:copyPartsFrom(original, "*")
    slot:copyWheelsFrom(original, "*")
    local originalIds, managedIds = {}, {}
    for _, part in ipairs(readParts(original)) do
        originalIds[#originalIds + 1] = part.id
    end
    for _, part in ipairs(entry.parts or {}) do
        managedIds[#managedIds + 1] = part.id
    end
    local hidden = PreviewSlot.hidden(readParts(slot), originalIds, managedIds, wanted)
    local model = original:getModel()
    local body = {
        file = bodyName,
        scale = original:getModelScale(),
        offset = xyz(model:getOffset()),
        rotate = xyz(model:getRotate()),
    }
    slot:Load(PreviewSlot.NAME, PreviewSlot.overrideText(body, textures, hidden))
    return signature
end

--- Shows a script by name in the scene and restarts the model data it caches.
function CSV_VehiclePreview:setScript(name)
    self:call("fromLua2", "setVehicleScript", VEHICLE, name)
    self:call("fromLua2", "setObjectVisible", VEHICLE, true)
end

--- Shows the game's plain vehicle (every part model, first paint).
function CSV_VehiclePreview:showPlain()
    PreviewWatch.idle(self.watch)
    self.slotSignature = nil
    if self.mode ~= "plain" or self.shownName ~= self.scriptName then
        self.mode, self.shownName = "plain", self.scriptName
        self:setScript(self.scriptName)
    end
end

--- Draws the build through the preview slot, or the plain vehicle when the
--- build can't be drawn that way.
function CSV_VehiclePreview:applyBuild()
    local entry, section = self.entry, self.section
    if not entry or not self.scene then
        return
    end
    if self.showAll or self.failed then
        self:showPlain()
        return
    end
    local built, result = pcall(function() return self:buildSlot(entry, section) end)
    if not built then
        print(LOG .. "showing every part model for " .. tostring(entry.name) .. ": " .. tostring(result))
        self.failed = true
        self:showPlain()
        return
    end
    if self.mode ~= "slot" or result ~= self.slotSignature then
        self.mode, self.slotSignature = "slot", result
        self:setScript(PreviewSlot.FULL_NAME)
        PreviewWatch.composed(self.watch)
    end
end

--- Shows a vehicle entry with a build section's paint and part choices, or
--- nothing when `entry` is nil.
function CSV_VehiclePreview:show(entry, section)
    self.entry, self.section = entry, section
    if not self.scene then
        return
    end
    if not entry then
        PreviewWatch.idle(self.watch)
        self.scriptName, self.mode, self.slotSignature = nil, nil, nil
        self:call("fromLua2", "setObjectVisible", VEHICLE, false)
        return
    end
    if self.scriptName ~= entry.name then
        self.scriptName = entry.name
        self.failed = false
        self:fitTo(getScriptManager():getVehicle(entry.name))
    end
    self:applyBuild()
end

--- Reports whether the last frame got past the scene, and drops the build
--- view for the plain vehicle after too many failed frames in a row.
function CSV_VehiclePreview:prerender()
    ISPanel.prerender(self)
    local reached = self.markerFrame == self.frame
    self.frame = self.frame + 1
    if PreviewWatch.frame(self.watch, reached) == "fail" then
        print(LOG .. "the scene kept failing to draw the build of " .. tostring(self.scriptName)
            .. "; showing every part model")
        self.failed = true
        self:showPlain()
    end
end

--- Switches between the build view and every part model.
function CSV_VehiclePreview:setShowAll(showAll, entry, section)
    self.showAll = showAll
    self.slotSignature = nil
    self:show(entry, section)
end

--- True when the preview had to fall back to the plain vehicle view.
function CSV_VehiclePreview:isFallback()
    return self.failed == true
end
