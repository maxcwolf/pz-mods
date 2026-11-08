--- End-to-end tests of the Starting Vehicle window on stub widgets: pick a
--- vehicle, choose parts from the lists, paint it, pack cargo, add a trailer,
--- save and load, and check what the 3D preview was told to draw.
package.path = TEST_ROOT .. "/test/harness/?.lua;" .. package.path
local FakeGame = require("fake-game")
local UiStubs = require("ui-stubs")

--- Installs fake files under ~/Zomboid/Lua.
local function installFiles()
    local files = {}
    getFileReader = function(name)
        local lines = files[name]
        if not lines then return nil end
        local i = 0
        return { readLine = function() i = i + 1 return lines[i] end, close = function() end }
    end
    getFileWriter = function(name)
        local lines = {}
        files[name] = lines
        return {
            write = function(_, text)
                for line in string.gmatch(text, "([^\n]*)\n") do lines[#lines + 1] = line end
            end,
            close = function() end,
        }
    end
    return files
end

--- Opens a fresh window against the fakes; returns it and a change counter.
local function openWindow()
    FakeGame.install()
    UiStubs.install()
    installFiles()
    for name in pairs(package.loaded) do
        if string.find(name, "^ChooseStartingVehicle/") then
            package.loaded[name] = nil
        end
    end
    CSV_Runtime, CSV_State, CSV_VehicleWindow, CSV_CargoDialog = nil, nil, nil, nil
    CSV_PartList, CSV_VehiclePreview, CSV_MechanicsDiagram = nil, nil, nil
    require("ChooseStartingVehicle/VehicleWindow")
    local counter = { n = 0 }
    local window = CSV_VehicleWindow.open(function() counter.n = counter.n + 1 end)
    return window, counter
end

--- Returns the row number of a part in a list, or nil.
local function rowOf(list, partId)
    for i, row in ipairs(list.items) do
        if row.item.part and row.item.part.id == partId then
            return i
        end
    end
    return nil
end

--- Clicks a part in whichever list holds it.
local function clickPart(window, partId)
    for _, list in ipairs({ window.leftList, window.rightList }) do
        local row = rowOf(list, partId)
        if row then
            list:onMouseDown(0, row)
            return
        end
    end
    error("no row for " .. partId)
end

--- Returns the data values of a combo's options.
local function optionData(combo)
    local out = {}
    for i, o in ipairs(combo.options) do out[i] = tostring(o.data) end
    return out
end

--- Draws a few frames of the 3D view, as the game does every frame.
local function frames(window, n)
    for _ = 1, n or 15 do
        UiStubs.frame(window.preview)
    end
end

--- Returns the last visibility the scene was given for the vehicle object.
local function vehicleShown()
    local last
    for _, call in ipairs(UiStubs.calls("setObjectVisible")) do
        if call.args[1] == "vehicle" then last = call.args[2] end
    end
    return last
end

--- True when the scene got a command whose first argument is `id`.
local function sceneHas(command, id)
    for _, call in ipairs(UiStubs.calls(command)) do
        if call.args[1] == id then return true end
    end
    return false
end

test("window: opens with no vehicle and offers the installed ones", function()
    local window = openWindow()
    ok(window.vehicleCombo.visible, "vehicle chooser")
    listEq(optionData(window.vehicleCombo), { "__default__", "Base.TestTruck" }, "trailers are not vehicles")
    eq(#window.leftList.items + #window.rightList.items, 0, "no parts yet")
end)

test("window: picking a vehicle lists its parts like the mechanics window", function()
    local window, counter = openWindow()
    window.vehicleCombo:pick("Base.TestTruck")
    eq(CSV_State.build.vehicle, "Base.TestTruck", "build vehicle")
    eq(counter.n, 1, "owner told")
    ok(rowOf(window.leftList, "TireFrontLeft"), "tires on the left")
    ok(rowOf(window.rightList, "DAMNBumperFront"), "bodywork on the right")
    ok(rowOf(window.rightList, "DoorFrontLeft"), "doors on the right")
    eq(window.leftList.items[1].item.cat, true, "category heading first")
    eq(window.selectedPartId, "TireFrontLeft", "first choosable part selected")
    eq(window.tintCombo.visible, false, "KI5 paint has no tint")
end)

test("window: tires change together unless 'same for all' is off", function()
    local window = openWindow()
    window.vehicleCombo:pick("Base.TestTruck")
    ok(window.sameTick.visible, "same-for-all shown for tires")
    listEq(optionData(window.installCombo), { "__default__", "Base.OldTire2", "Base.NormalTire2" }, "tires can't be removed")
    window.installCombo:pick("Base.NormalTire2")
    eq(CSV_State.build.parts.TireFrontRight, "Base.NormalTire2", "both tires")
    window.sameTick:toggle(1)
    clickPart(window, "TireFrontRight")
    window.installCombo:pick("Base.OldTire2")
    eq(CSV_State.build.parts.TireFrontRight, "Base.OldTire2", "right tire")
    eq(CSV_State.build.parts.TireFrontLeft, "Base.NormalTire2", "left tire kept")
end)

--- Returns the text of the slot's last override load, or "".
local function lastSlotText()
    local loads = FakeGame.slot.loads
    return loads[#loads] and loads[#loads].text or ""
end

--- True when the slot's last override hides a part model.
local function slotHides(partId, modelId)
    return string.find(lastSlotText(), "part " .. partId .. "\n\t{\n\t\tmodel " .. modelId .. "\n", 1, true) ~= nil
end

--- Returns the last script the scene was told to draw.
local function shownScript()
    local last
    for _, call in ipairs(UiStubs.calls("setVehicleScript")) do last = call.args[2] end
    return last
end

test("window: removing an add-on updates the row and the 3D preview", function()
    local window = openWindow()
    window.vehicleCombo:pick("Base.TestTruck")
    frames(window)
    eq(shownScript(), "Base.CSV_PreviewVehicle", "the scene draws the preview slot")
    eq(vehicleShown(), true, "visible")
    ok(slotHides("DAMNBumperFront", "Bullbar"), "game's choice shows the first bumper only")
    eq(slotHides("DAMNBumperFront", "Bumper"), false, "first bumper shown")
    eq(slotHides("DoorFrontLeft", "Door"), false, "door shown")
    clickPart(window, "DAMNBumperFront")
    eq(window.installCombo.options[2].data, "none", "add-ons can be removed")
    window.installCombo:pick("none")
    eq(CSV_State.build.parts.DAMNBumperFront, "none", "stored")
    ok(slotHides("DAMNBumperFront", "Bumper"), "bumper hidden in the preview")
    ok(slotHides("DAMNBumperFront", "Bullbar"), "bull bar too")
    local text = window:choiceText(window:findPart("DAMNBumperFront"))
    eq(text, "UI_CSV_NoneShort", "row says None")
    window.installCombo:pick("Base.TTBullbarFront")
    eq(slotHides("DAMNBumperFront", "Bullbar"), false, "bull bar shown")
    ok(slotHides("DAMNBumperFront", "Bumper"), "stock bumper hidden")
    ok(string.find(lastSlotText(), "model Bumper\n\t\t{\n\t\t\tfile = TTBullbar1,", 1, true),
        "the hidden stock bumper redraws the bull bar's own file, at its scale")
end)

test("window: the preview slot copies the vehicle and paints the body with the chosen skin", function()
    local window = openWindow()
    window.vehicleCombo:pick("Base.TestTruck")
    frames(window)
    eq(FakeGame.slot.wheelsFrom, "Base.TestTruck", "wheels copied")
    local copy = FakeGame.addedModelScripts["Base.CSV_PreviewBody_Base_TestTruck_0"]
    ok(copy, "body copy registered")
    eq(copy.module, "BaseModule", "same module as the original body")
    ok(string.find(copy.text, "shader = vehicle,", 1, true), "keeps the vehicle shader")
    ok(string.find(copy.text, "texture = Vehicles/Vehicles_TestTruck_Shell_red,", 1, true), "first paint")
    local text = lastSlotText()
    ok(string.find(text, "file = Base.CSV_PreviewBody_Base_TestTruck_0,", 1, true), "slot body is the copy")
    ok(string.find(text, "scale = 0.9,", 1, true), "vehicle model scale")
    ok(string.find(text, "textureMask = Vehicles/Vehicles_TestTruck_Mask,", 1, true), "paint mask")
    local shown = #UiStubs.calls("setVehicleScript")
    frames(window)
    window:refreshAll()
    eq(#UiStubs.calls("setVehicleScript"), shown, "nothing changed, so the scene isn't reset")
    window.paintCombo:pick(1)
    ok(FakeGame.addedModelScripts["Base.CSV_PreviewBody_Base_TestTruck_1"], "blue copy")
    ok(string.find(lastSlotText(), "CSV_PreviewBody_Base_TestTruck_1", 1, true), "slot repainted")
    ok(#UiStubs.calls("setVehicleScript") > shown, "scene reset to show it")
    window.paintCombo:pick(0)
    eq(FakeGame.addCount, 2, "each copy is made once")
end)

test("window: trunk and glove box parts open the cargo editor", function()
    local window = openWindow()
    window.vehicleCombo:pick("Base.TestTruck")
    clickPart(window, "TruckBed")
    ok(window.cargoButton.visible, "truck bed holds the trunk cargo")
    clickPart(window, "GloveBox")
    ok(window.cargoButton.visible, "glove box")
    clickPart(window, "SeatFrontLeft")
    eq(window.cargoButton.visible, false, "seats hold nothing")
    eq(window.installCombo.visible, false, "nothing to choose for a seat")
end)

test("window: the trailer tab picks a trailer and its cargo part", function()
    local window = openWindow()
    window.vehicleCombo:pick("Base.TestTruck")
    window.trailerTab:click()
    ok(window.trailerCombo.visible, "trailer chooser")
    eq(window.vehicleCombo.visible, false, "vehicle chooser hidden")
    window.trailerCombo:pick("Base.TrailerTest")
    eq(CSV_State.build.trailer.vehicle, "Base.TrailerTest", "trailer stored")
    clickPart(window, "TrailerTrunk")
    ok(window.cargoButton.visible, "trailer cargo")
    window.trailerCombo:pick("__default__")
    eq(CSV_State.build.trailer, nil, "trailer removed")
    window.vehicleTab:click()
    eq(window:entry().name, "Base.TestTruck", "back to the vehicle")
end)

test("window: switching to the diagram and back works without overlay art", function()
    local window = openWindow()
    window.vehicleCombo:pick("Base.TestTruck")
    window.diagramButton:click()
    ok(window.diagram.visible, "diagram shown")
    eq(window.preview.visible, false, "3D hidden")
    window.diagram:render()
    window.view3dButton:click()
    ok(window.preview.visible, "3D back")
    window:render()
end)

test("window: every part model view shows the plain vehicle", function()
    local window = openWindow()
    window.vehicleCombo:pick("Base.TestTruck")
    frames(window)
    window.allModelsTick:toggle(1)
    frames(window)
    eq(vehicleShown(), true, "plain vehicle visible")
    eq(shownScript(), "Base.TestTruck", "the real vehicle, every model")
    eq(window.preview:isFallback(), false, "on purpose, not a fallback")
    window.allModelsTick:toggle(1)
    eq(shownScript(), "Base.CSV_PreviewVehicle", "back to the build view")
end)

test("window: save, clear and load a build", function()
    local window = openWindow()
    window.vehicleCombo:pick("Base.TestTruck")
    clickPart(window, "DAMNBumperFront")
    window.installCombo:pick("Base.TTBullbarFront")
    window.nameEntry:setText("Hunter")
    window.saveButton:click()
    eq(#CSV_State.builds, 1, "saved")
    window.clearButton:click()
    eq(CSV_State.build.vehicle, nil, "cleared")
    window.savedCombo:selectData("Hunter")
    window.loadButton:click()
    eq(CSV_State.build.vehicle, "Base.TestTruck", "loaded")
    eq(CSV_State.build.parts.DAMNBumperFront, "Base.TTBullbarFront", "choice kept")
end)

test("window: re-picking the same vehicle or trailer keeps the choices", function()
    local window = openWindow()
    window.vehicleCombo:pick("Base.TestTruck")
    clickPart(window, "DAMNBumperFront")
    window.installCombo:pick("none")
    window.paintCombo:pick(1)
    window.vehicleCombo:pick("Base.TestTruck")
    eq(CSV_State.build.parts.DAMNBumperFront, "none", "part choice kept")
    eq(CSV_State.build.skin, 1, "paint kept")
    window.trailerTab:click()
    window.trailerCombo:pick("Base.TrailerTest")
    window.paintCombo:pick(0)
    window.trailerCombo:pick("Base.TrailerTest")
    eq(CSV_State.build.trailer.skin, 0, "trailer paint kept")
end)

test("window: part models without a model script stay hidden", function()
    local window = openWindow()
    window.vehicleCombo:pick("Base.TestTruck")
    frames(window)
    ok(slotHides("DoorFrontLeft", "Ghost"), "missing model script")
    ok(slotHides("DoorFrontLeft", "Blank"), "empty file")
end)

test("window: the preview slot never shows up as a vehicle to pick", function()
    local window = openWindow()
    window.vehicleCombo:pick("Base.TestTruck")
    frames(window)
    ok(FakeGame.slot:getPartCount() > 0, "the slot holds parts now")
    CSV_Runtime.reset()
    for _, entry in ipairs(CSV_Runtime.list()) do
        ok(entry.name ~= "Base.CSV_PreviewVehicle", "slot not listed")
    end
end)

--- Draws frames where the scene throws, like a model still loading.
local function brokenFrames(window, n)
    window.preview.scene.brokenRender = true
    for _ = 1, n do
        pcall(UiStubs.frame, window.preview)
    end
    window.preview.scene.brokenRender = false
end

test("window: a few failed frames while models load don't drop the build view", function()
    local window = openWindow()
    window.vehicleCombo:pick("Base.TestTruck")
    brokenFrames(window, 30)
    frames(window, 3)
    eq(window.preview:isFallback(), false, "kept the build view")
    eq(shownScript(), "Base.CSV_PreviewVehicle", "still the slot")
end)

test("window: a scene that keeps failing falls back to the plain vehicle", function()
    local window = openWindow()
    window.vehicleCombo:pick("Base.TestTruck")
    frames(window)
    brokenFrames(window, 95)
    frames(window, 2)
    eq(shownScript(), "Base.TestTruck", "plain vehicle back")
    ok(window.preview:isFallback(), "marked as fallback")
end)

test("window: a vehicle without a paint mask in its text shows the plain vehicle", function()
    local window = openWindow()
    window.vehicleCombo:pick("Base.TestTruck")
    window.preview.slotSignature = nil
    local entry = window:entry()
    local saved = entry.name
    entry.name = "Base.TrailerTest"
    window.preview.scriptName = nil
    window.preview:show(entry, window:section())
    eq(shownScript(), "Base.TrailerTest", "plain view")
    ok(window.preview:isFallback(), "noted")
    entry.name = saved
end)
