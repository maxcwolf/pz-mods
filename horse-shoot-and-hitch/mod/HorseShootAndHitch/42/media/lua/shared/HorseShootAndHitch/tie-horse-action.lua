--- Timed action that ties a horse to a fence, pole or tree. Modeled on vanilla's
--- ISAttachAnimalToTree so complete() runs on the server in multiplayer.
require "TimedActions/ISBaseTimedAction"
local TetherWorld = require("HorseShootAndHitch/tether-world")
local Mounts = require("HorseMod/Mounts")

HorseShootAndHitch_TieHorseAction = ISBaseTimedAction:derive("HorseShootAndHitch_TieHorseAction")
local TieHorseAction = HorseShootAndHitch_TieHorseAction

--- How close the horse must be to the post, in tiles, for the tie to start.
TieHorseAction.MAX_HORSE_DISTANCE = 4

--- Checks the post, the horse and what the tie would cost are all still fine.
function TieHorseAction:isValid()
    if not self.post:getSquare() or self.post:getObjectIndex() == -1 then return false end
    if self.horse:isDead() or Mounts.hasRider(self.horse) or TetherWorld.get(self.horse) then return false end
    if self.character:getSquare():DistTo(self.post:getSquare()) > 2 then return false end
    if self.horse:getCurrentSquare() and self.horse:getCurrentSquare():DistTo(self.post:getSquare()) > TieHorseAction.MAX_HORSE_DISTANCE then
        return false
    end
    return TetherWorld.costFor(self.character, self.horse) ~= nil or self.character:isAnimalCheat()
end

--- Turns the character to face the post before starting.
function TieHorseAction:waitToStart()
    self.character:faceThisObject(self.post)
    return self.character:shouldBeTurning()
end

--- Keeps the character facing the post.
function TieHorseAction:update()
    self.character:faceThisObject(self.post)
end

--- Plays the same animation and sound as tying an animal to a tree.
function TieHorseAction:start()
    self:setActionAnim("Loot")
    self.character:reportEvent("EventLootItem")
    self.horse:stopAllMovementNow()
    self.sound = self.character:playSound("AttachRopeTree")
end

--- Stops the sound when the action is cancelled.
function TieHorseAction:stop()
    self.character:stopOrTriggerSound(self.sound)
    ISBaseTimedAction.stop(self)
end

--- Finishes the action on the client.
function TieHorseAction:perform()
    self.character:stopOrTriggerSound(self.sound)
    ISBaseTimedAction.perform(self)
end

--- Applies the tie; runs on the server in multiplayer and locally in single player.
function TieHorseAction:complete()
    TetherWorld.tie(self.character, self.horse, self.post)
    return true
end

--- Returns how long tying takes.
function TieHorseAction:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return 40
end

--- Creates a tie action for a character, a horse and the post to tie it to.
function TieHorseAction:new(character, horse, post)
    local o = ISBaseTimedAction.new(self, character)
    o.horse = horse
    o.post = post
    o.maxTime = o:getDuration()
    return o
end

return TieHorseAction
