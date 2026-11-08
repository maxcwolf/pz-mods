--- Game glue for tied horses: stores the tie in the horse's mod data, hooks it
--- into vanilla's tree tie (rope drawing, wander anchor, Detach option), puts it
--- back after a reload and keeps the horse within the tether radius.
require "TimedActions/Animals/ISAttachAnimalToTree"
require "TimedActions/Animals/ISAttachAnimalToPlayer"
local Tether = require("HorseShootAndHitch/tether")
local Settings = require("HorseShootAndHitch/settings")
local HorseManager = require("HorseMod/HorseManager")
local Attachments = require("HorseMod/attachments/Attachments")
local Mounts = require("HorseMod/Mounts")

local TetherWorld = {}

TetherWorld.MOD_DATA_KEY = "HorseShootAndHitch"

--- How many ticks pass between radius checks.
TetherWorld.CHECK_EVERY_TICKS = 20

local ROPE = "Base.Rope"
local ROPE_TYPE = "Rope"

--- Writes a line to the console with this mod's tag.
local function log(text)
    print("[HorseShootAndHitch] " .. text)
end

--- Returns the stored tie for a horse, or nil when it is not tied by this mod.
function TetherWorld.get(horse)
    local record = horse:getModData()[TetherWorld.MOD_DATA_KEY]
    if Tether.isValidRecord(record) then return record end
    return nil
end

--- Describes a world object as plain facts for Tether.isTiePoint.
function TetherWorld.describe(object)
    local props = object:getProperties()
    return {
        tree = instanceof(object, "IsoTree"),
        hoppable = object:isHoppable(),
        tallHoppable = object:isTallHoppable(),
        canAttachAnimal = props ~= nil and props:has("CanAttachAnimal"),
        spriteName = object:getSpriteName(),
    }
end

--- Tells whether a world object can hold a tied horse.
function TetherWorld.isTiePoint(object)
    return object ~= nil and Tether.isTiePoint(TetherWorld.describe(object))
end

--- Finds a tie point on a square, preferring one with the given sprite name.
function TetherWorld.findTiePoint(square, spriteName)
    if not square then return nil end
    local objects = square:getObjects()
    local fallback = nil
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        if TetherWorld.isTiePoint(object) then
            if spriteName == nil or object:getSpriteName() == spriteName then return object end
            fallback = fallback or object
        end
    end
    return fallback
end

--- Tells whether the horse wears reins.
function TetherWorld.hasReins(horse)
    return Attachments.getReins(horse) ~= nil
end

--- Tells what tying this horse would use for this character: "reins", "rope" or nil.
function TetherWorld.costFor(character, horse)
    local hasRope = character:getInventory():getFirstTypeRecurse(ROPE_TYPE) ~= nil
    return Tether.tieCost(TetherWorld.hasReins(horse), hasRope)
end

--- Gives a post with no name a readable one so vanilla's Detach option reads well.
local function nameUnnamedPost(post)
    if post:getName() then return end
    if instanceof(post, "IsoTree") then return end
    if post:isHoppable() or post:isTallHoppable() then
        post:setName(getText("IGUI_HorseShootAndHitch_Fence"))
    else
        post:setName(getText("IGUI_HorseShootAndHitch_Post"))
    end
end

--- Takes one rope from the character, telling the server-side inventory too.
local function takeRope(character)
    local rope = character:getInventory():getFirstTypeRecurse(ROPE_TYPE)
    if not rope then return false end
    local container = rope:getContainer()
    container:Remove(rope)
    if sendRemoveItemFromContainer then sendRemoveItemFromContainer(container, rope) end
    return true
end

--- Gives a rope back to the character, or drops it at the post when nobody is there.
local function giveRope(character, square)
    if character then
        local item = character:getInventory():AddItem(ROPE)
        if item and sendAddItemToContainer then sendAddItemToContainer(character:getInventory(), item) end
    elseif square then
        square:AddWorldInventoryItem(ROPE, 0.5, 0.5, 0)
    end
end

--- Ties a horse to a post for a character. Returns false when the tie cannot be paid for.
function TetherWorld.tie(character, horse, post)
    local cost = TetherWorld.costFor(character, horse)
    if not cost then return false end
    if cost == Tether.ROPE and not character:isAnimalCheat() and not takeRope(character) then return false end
    local square = post:getSquare()
    horse:getModData()[TetherWorld.MOD_DATA_KEY] =
        Tether.record(square:getX(), square:getY(), square:getZ(), post:getSpriteName(), cost)
    if character:getAttachedAnimals():contains(horse) then character:removeAttachedAnimal(horse) end
    horse:getData():setAttachedPlayer(nil)
    nameUnnamedPost(post)
    horse:getData():setAttachedTree(post)
    horse:stopAllMovementNow()
    log("tied horse " .. tostring(horse:getAnimalID()) .. " with " .. cost .. " at " .. square:getX() .. "," .. square:getY())
    return true
end

--- Unties a horse. The rope, if one was used, goes to `character` or onto the post's square.
function TetherWorld.untie(horse, character)
    local record = TetherWorld.get(horse)
    if not record then return false end
    horse:getModData()[TetherWorld.MOD_DATA_KEY] = nil
    horse:getData():setAttachedTree(nil)
    if record.cost == Tether.ROPE and not (character and character:isAnimalCheat()) then
        giveRope(character, getCell():getGridSquare(record.x, record.y, record.z))
    end
    log("untied horse " .. tostring(horse:getAnimalID()))
    return true
end

--- Re-links a tied horse to its post after a reload; frees it if the post is gone.
function TetherWorld.restore(horse)
    local record = TetherWorld.get(horse)
    if not record or horse:getData():getAttachedTree() then return end
    local square = getCell():getGridSquare(record.x, record.y, record.z)
    if not square then return end
    local post = TetherWorld.findTiePoint(square, record.sprite)
    if post then
        horse:getData():setAttachedTree(post)
    else
        log("post for horse " .. tostring(horse:getAnimalID()) .. " is gone; freeing it")
        TetherWorld.untie(horse, nil)
    end
end

--- Walks a straying tied horse back inside the radius, or puts it back if it got lost.
function TetherWorld.enforce(horse, radius)
    local record = TetherWorld.get(horse)
    if not record or Mounts.hasRider(horse) then return end
    local x, y = horse:getX(), horse:getY()
    if not Tether.isOutOfReach(x, y, record, radius) then return end
    local tx, ty = Tether.returnTile(x, y, record, radius)
    horse:stopAllMovementNow()
    if Tether.isLost(x, y, record, radius) then
        horse:setX(tx + 0.5)
        horse:setY(ty + 0.5)
        horse:setZ(record.z)
    else
        horse:pathToLocation(tx, ty, record.z)
    end
end

--- Horse manager system that restores ties and enforces the radius every few ticks.
local System = { ticks = 0 }

--- Runs once per tick from HorseManager.update with every loaded horse.
function System:update(horses, _delta)
    self.ticks = self.ticks + 1
    if self.ticks < TetherWorld.CHECK_EVERY_TICKS then return end
    self.ticks = 0
    local radius = Settings.current().radius
    for i = 1, #horses do
        local horse = horses[i]
        if horse and not horse:isDead() and TetherWorld.get(horse) then
            TetherWorld.restore(horse)
            TetherWorld.enforce(horse, radius)
        end
    end
end

--- Unties a horse when someone climbs on, so riding off never drags the post along.
local function untieOnMount(player, horse)
    if horse and TetherWorld.get(horse) then TetherWorld.untie(horse, player) end
end

--- Wraps a vanilla tree action so it clears this mod's tie first and only hands
--- back a rope when one was used. `clears` says whether this action unties.
local function patchTreeAction(action, clears)
    if not action or action.HorseShootAndHitchPatched then return end
    action.HorseShootAndHitchPatched = true
    local originalComplete = action.complete
    local originalTakeRope = action.takeRope
    action.complete = function(self)
        local record = clears(self) and self.animal and TetherWorld.get(self.animal)
        if record then
            self.animal:getModData()[TetherWorld.MOD_DATA_KEY] = nil
            self.skipRope = record.cost ~= Tether.ROPE
        end
        return originalComplete(self)
    end
    action.takeRope = function(self)
        if self.skipRope then return end
        return originalTakeRope(self)
    end
end

--- Patches vanilla "Detach animal from ..." and "Attach animal" (leash) for horses this mod tied.
local function patchVanillaTreeActions()
    patchTreeAction(ISAttachAnimalToTree, function(self) return self.remove end)
    patchTreeAction(ISAttachAnimalToPlayer, function(self) return not self.remove end)
end

if not isClient() then
    HorseManager.systems[#HorseManager.systems + 1] = System
    Mounts.onMount:add(untieOnMount)
end
patchVanillaTreeActions()

return TetherWorld
