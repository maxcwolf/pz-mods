local Stubs = HSH_Stubs
local MountedShooting = require("HorseShootAndHitch/mounted-shooting")

--- Builds a local rider on a horse holding the given weapon.
local function rider(weapon)
    local horse = Stubs.horse({})
    local player = Stubs.player({ primary = weapon })
    Stubs.mounts.riders[player] = horse
    Stubs.mounts.horses[horse] = player
    return player, horse
end

test("the three IsoPlayer methods are wrapped once", function()
    eq(IsoPlayerIndex.HorseShootAndHitchPatched, true)
    eq(Stubs.validActions["ISEquipWeaponAction"], true, "equipping allowed in the saddle")
end)

test("a rider with a gun keeps aim input; with a melee weapon the Horse mod lock holds", function()
    local gunner = rider(Stubs.weapon(true))
    gunner:setIgnoreAimingInput(true)
    eq(gunner.ignoreAim, false)
    local swordsman = rider(Stubs.weapon(false))
    swordsman:setIgnoreAimingInput(true)
    eq(swordsman.ignoreAim, true)
end)

test("attacking is unbanned only while the gunner is aiming", function()
    local player = rider(Stubs.weapon(true))
    player:setBannedAttacking(true)
    eq(player.banned, true, "not aiming: a click would shove, so stay banned")
    player.aiming = true
    player:setBannedAttacking(true)
    eq(player.banned, false)
end)

test("a player on foot is untouched", function()
    local player = Stubs.player({ primary = Stubs.weapon(true) })
    player:setIgnoreAimingInput(true)
    eq(player.ignoreAim, true)
end)

test("remote players are untouched", function()
    local player = rider(Stubs.weapon(true))
    player.local_ = false
    player:setIgnoreAimingInput(true)
    eq(player.ignoreAim, true)
end)

test("locks stay on mid-jump", function()
    local player = rider(Stubs.weapon(true))
    player.vars.HorseJump = true
    player:setIgnoreAimingInput(true)
    eq(player.ignoreAim, true)
end)

test("the sandbox switch turns shooting off", function()
    SandboxVars.HorseShootAndHitch = { MountedShooting = false }
    local player = rider(Stubs.weapon(true))
    player:setIgnoreAimingInput(true)
    SandboxVars.HorseShootAndHitch = nil
    eq(player.ignoreAim, true)
end)

test("while aiming, the Horse mod's facing pin is followed by the mouse aim", function()
    local player = rider(Stubs.weapon(true))
    player.aiming = true
    Stubs.mouseWorld = { 0, 10 }
    player:setTargetAndCurrentDirection(1, 0)
    Stubs.mouseWorld = nil
    eq(player.pinned[1], 1, "pin still applied")
    near(player.forward[1], 0, "forward x")
    near(player.forward[2], 1, "forward y points at the mouse")
end)

test("the aim respects a narrower sandbox arc", function()
    SandboxVars.HorseShootAndHitch = { AimArc = 90 }
    local player = rider(Stubs.weapon(true))
    player.aiming = true
    Stubs.mouseWorld = { -10, 0.0001 }
    player:setTargetAndCurrentDirection(1, 0)
    Stubs.mouseWorld = nil
    SandboxVars.HorseShootAndHitch = nil
    near(player.forward[1], 0, "clamped to the side")
end)

test("not aiming leaves the pin alone", function()
    local player = rider(Stubs.weapon(true))
    Stubs.mouseWorld = { 0, 10 }
    player:setTargetAndCurrentDirection(1, 0)
    Stubs.mouseWorld = nil
    eq(player.forward[1], 1)
    eq(player.forward[2], 0)
end)

test("a shot at a gallop loses 20 points and gets them back when the attack ends", function()
    local gun = Stubs.weapon(true, 60)
    local player = rider(gun)
    player.vars.HorseGallop = true
    MountedShooting.onWeaponSwing(player, gun)
    eq(gun.hit, 40)
    MountedShooting.onPlayerAttackFinished(player, gun)
    eq(gun.hit, 60)
end)

test("a shot at a walk loses only 2 points; standing still loses none", function()
    local gun = Stubs.weapon(true, 60)
    local player = rider(gun)
    player.vars.HorseMountedMoving = true
    MountedShooting.onWeaponSwing(player, gun)
    eq(gun.hit, 58)
    MountedShooting.onPlayerAttackFinished(player, gun)
    player.vars.HorseMountedMoving = false
    MountedShooting.onWeaponSwing(player, gun)
    eq(gun.hit, 60)
end)

test("two quick shots never stack the penalty", function()
    local gun = Stubs.weapon(true, 60)
    local player = rider(gun)
    player.vars.HorseTrot = true
    MountedShooting.onWeaponSwing(player, gun)
    MountedShooting.onWeaponSwing(player, gun)
    eq(gun.hit, 55)
    MountedShooting.onPlayerAttackFinished(player, gun)
    eq(gun.hit, 60)
end)

test("a lowered hit chance is put back after a few seconds if the attack never finished", function()
    local gun = Stubs.weapon(true, 60)
    local player = rider(gun)
    player.vars.HorseGallop = true
    MountedShooting.onWeaponSwing(player, gun)
    Stubs.timeDelta = 4
    MountedShooting.onPlayerUpdate(player)
    Stubs.timeDelta = nil
    eq(gun.hit, 60)
end)

test("saving puts every lowered hit chance back", function()
    local gun = Stubs.weapon(true, 60)
    local player = rider(gun)
    player.vars.HorseGallop = true
    MountedShooting.onWeaponSwing(player, gun)
    MountedShooting.onSave()
    eq(gun.hit, 60)
end)

test("melee swings and shots on foot are not penalized", function()
    local bat = Stubs.weapon(false, 60)
    local player = rider(bat)
    player.vars.HorseGallop = true
    MountedShooting.onWeaponSwing(player, bat)
    eq(bat.hit, 60)
    local gun = Stubs.weapon(true, 60)
    local walker = Stubs.player({ primary = gun })
    MountedShooting.onWeaponSwing(walker, gun)
    eq(gun.hit, 60)
end)
