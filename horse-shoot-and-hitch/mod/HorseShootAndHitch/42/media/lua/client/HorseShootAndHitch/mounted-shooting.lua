--- Lets a rider aim and fire a firearm from the saddle. The Horse mod bans
--- attacking, ignores aim input and pins the rider's facing to the horse from Lua
--- every tick; this file intercepts those three calls on IsoPlayer for a local
--- rider holding a firearm, points the shot at the mouse and applies a hit
--- chance penalty that grows with the horse's gait.
local MountedAim = require("HorseShootAndHitch/mounted-aim")
local Settings = require("HorseShootAndHitch/settings")
local Mounts = require("HorseMod/Mounts")
local AnimationVariable = require("HorseMod/definitions/AnimationVariable")
local RidingAPI = require("HorseMod/api/RidingAPI")

local MountedShooting = {}

--- Seconds after which a lowered hit chance is put back even if the attack never finished.
MountedShooting.RESTORE_AFTER_SECONDS = 3

--- Weapons whose hit chance is lowered for the current shot: player -> { weapon, base, elapsed }.
local pending = {}

RidingAPI.addValidTimedAction("ISEquipWeaponAction")

--- Tells whether the item is a firearm that aims like a gun.
local function isFirearm(item)
    return item ~= nil and instanceof(item, "HandWeapon") and item:isAimedFirearm()
end

--- Tells whether this rider's aiming and attacking locks should be lifted right now.
function MountedShooting.isUnlocked(player)
    if not player:isLocalPlayer() then return false end
    return MountedAim.shouldUnlock({
        enabled = Settings.current().shooting,
        mounted = Mounts.hasMount(player),
        firearm = isFirearm(player:getPrimaryHandItem()),
        jumping = player:getVariableBoolean(AnimationVariable.JUMP),
        mounting = player:getVariableBoolean(AnimationVariable.MOUNTING_HORSE),
        dismounting = player:getVariableBoolean(AnimationVariable.DISMOUNT_STARTED),
    })
end

--- Returns the horse's gait for the penalty table.
function MountedShooting.gait(player)
    return MountedAim.gaitFrom({
        gallop = player:getVariableBoolean(AnimationVariable.GALLOP),
        trot = player:getVariableBoolean(AnimationVariable.TROT),
        moving = player:getVariableBoolean(AnimationVariable.MOUNTED_MOVING),
    })
end

--- Returns the world point under the mouse for a mouse player, or nil for a controller.
local function mouseWorldPoint(player)
    if player:getJoypadBind() ~= -1 then return nil end
    local playerNum = player:getPlayerNum()
    local z = player:getZ()
    return screenToIsoX(playerNum, getMouseX(), getMouseY(), z), screenToIsoY(playerNum, getMouseX(), getMouseY(), z)
end

--- Points the rider's shot (forward direction) at the mouse, inside the allowed arc,
--- and asks the animation to twist the upper body that way while the legs stay on the horse.
function MountedShooting.applyAim(player, headingX, headingY)
    local mx, my = mouseWorldPoint(player)
    if not mx then return end
    local heading = math.atan2(headingY, headingX)
    local aim = MountedAim.angleTo(player:getX(), player:getY(), mx, my)
    aim = MountedAim.clampToArc(heading, aim, Settings.current().arc)
    local ax, ay = MountedAim.direction(aim)
    player:setForwardDirection(ax, ay)
    if player:hasAnimationPlayer() then
        player:getAnimationPlayer():setTargetDirection(ax, ay)
    end
end

--- Returns the horse's heading as a unit vector.
local function horseHeading(player)
    local horse = Mounts.getMount(player)
    if not horse then return nil end
    return horse:getForwardDirectionX(), horse:getForwardDirectionY()
end

--- Replaces one method in a Java class's Lua method table, logging instead of failing if it is missing.
local function wrapMethod(index, name, makeWrapper)
    local original = index[name]
    if not original then
        print("[HorseShootAndHitch] cannot find IsoPlayer." .. name .. "; mounted shooting may not work")
        return
    end
    index[name] = makeWrapper(original)
end

--- Wraps three IsoPlayer methods the Horse mod calls on riders every tick.
local function patchPlayerMethods()
    local index = __classmetatables[IsoPlayer.class].__index
    if index.HorseShootAndHitchPatched then return end
    index.HorseShootAndHitchPatched = true

    wrapMethod(index, "setBannedAttacking", function(original)
        return function(self, banned)
            if banned and self:isAiming() and MountedShooting.isUnlocked(self) then banned = false end
            return original(self, banned)
        end
    end)

    wrapMethod(index, "setIgnoreAimingInput", function(original)
        return function(self, ignore)
            if ignore and MountedShooting.isUnlocked(self) then ignore = false end
            return original(self, ignore)
        end
    end)

    wrapMethod(index, "setTargetAndCurrentDirection", function(original)
        return function(self, x, y, ...)
            local result = original(self, x, y, ...)
            if type(x) == "number" and type(y) == "number" and self:isAiming() and MountedShooting.isUnlocked(self) then
                MountedShooting.applyAim(self, x, y)
            end
            return result
        end
    end)
end

--- Puts a weapon's hit chance back after a mounted shot.
local function restore(player)
    local entry = pending[player]
    if not entry then return end
    entry.weapon:setHitChance(entry.base)
    pending[player] = nil
end

--- Lowers the hit chance for this shot by the gait penalty and keeps the aim on the mouse.
function MountedShooting.onWeaponSwing(character, weapon)
    if not instanceof(character, "IsoPlayer") or not isFirearm(weapon) then return end
    if not MountedShooting.isUnlocked(character) then return end
    local hx, hy = horseHeading(character)
    if hx then MountedShooting.applyAim(character, hx, hy) end
    restore(character)
    local penalty = MountedAim.penaltyFor(MountedShooting.gait(character), Settings.current().penalties)
    if penalty <= 0 then return end
    local base = weapon:getHitChance()
    pending[character] = { weapon = weapon, base = base, elapsed = 0 }
    weapon:setHitChance(MountedAim.reducedHitChance(base, penalty))
end

--- Restores the hit chance once the attack is over.
function MountedShooting.onPlayerAttackFinished(player, _weapon)
    restore(player)
end

--- Keeps the aim on the mouse each player update and restores stale hit chances.
function MountedShooting.onPlayerUpdate(player)
    local entry = pending[player]
    if entry then
        entry.elapsed = entry.elapsed + GameTime.getInstance():getTimeDelta()
        if entry.elapsed > MountedShooting.RESTORE_AFTER_SECONDS then restore(player) end
    end
    if player:isAiming() and MountedShooting.isUnlocked(player) then
        player:setBannedAttacking(false)
        local hx, hy = horseHeading(player)
        if hx then MountedShooting.applyAim(player, hx, hy) end
    end
end

--- Puts every lowered hit chance back before the game saves.
function MountedShooting.onSave()
    for player in pairs(pending) do restore(player) end
end

patchPlayerMethods()
Events.OnWeaponSwing.Add(MountedShooting.onWeaponSwing)
Events.OnPlayerAttackFinished.Add(MountedShooting.onPlayerAttackFinished)
Events.OnPlayerUpdate.Add(MountedShooting.onPlayerUpdate)
Events.OnSave.Add(MountedShooting.onSave)

return MountedShooting
