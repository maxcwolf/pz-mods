local MountedAim = require("HorseShootAndHitch/mounted-aim")

test("gait is a gallop when the gallop flag is set, even if trot is too", function()
    eq(MountedAim.gaitFrom({ gallop = true, trot = true, moving = true }), "gallop")
end)

test("gait is a trot, a walk or standing from the flags", function()
    eq(MountedAim.gaitFrom({ trot = true, moving = true }), "trot")
    eq(MountedAim.gaitFrom({ moving = true }), "walk")
    eq(MountedAim.gaitFrom({}), "stand")
end)

test("default penalties are very forgiving at a walk and trot", function()
    eq(MountedAim.penaltyFor("stand"), 0)
    eq(MountedAim.penaltyFor("walk"), 2)
    eq(MountedAim.penaltyFor("trot"), 5)
    eq(MountedAim.penaltyFor("gallop"), 20)
end)

test("configured penalties override the defaults, including zero", function()
    eq(MountedAim.penaltyFor("gallop", { gallop = 35 }), 35)
    eq(MountedAim.penaltyFor("walk", { walk = 0 }), 0)
    eq(MountedAim.penaltyFor("trot", { walk = 9 }), 5, "missing key falls back")
end)

test("reduced hit chance never drops below zero", function()
    eq(MountedAim.reducedHitChance(60, 20), 40)
    eq(MountedAim.reducedHitChance(10, 20), 0)
    eq(MountedAim.reducedHitChance(nil, 5), 0)
end)

test("locks lift only for an enabled, mounted rider holding a firearm", function()
    local ready = { enabled = true, mounted = true, firearm = true }
    eq(MountedAim.shouldUnlock(ready), true)
    eq(MountedAim.shouldUnlock({ enabled = false, mounted = true, firearm = true }), false)
    eq(MountedAim.shouldUnlock({ enabled = true, mounted = false, firearm = true }), false)
    eq(MountedAim.shouldUnlock({ enabled = true, mounted = true, firearm = false }), false)
end)

test("locks stay on while jumping, mounting or dismounting", function()
    eq(MountedAim.shouldUnlock({ enabled = true, mounted = true, firearm = true, jumping = true }), false)
    eq(MountedAim.shouldUnlock({ enabled = true, mounted = true, firearm = true, mounting = true }), false)
    eq(MountedAim.shouldUnlock({ enabled = true, mounted = true, firearm = true, dismounting = true }), false)
end)

test("wrap keeps angles within minus pi to pi", function()
    near(MountedAim.wrap(3 * math.pi), math.pi)
    near(MountedAim.wrap(-math.pi / 2), -math.pi / 2)
    near(MountedAim.wrap(2 * math.pi + 0.25), 0.25)
end)

test("angleTo points from the rider to the target", function()
    near(MountedAim.angleTo(0, 0, 1, 0), 0)
    near(MountedAim.angleTo(0, 0, 0, 1), math.pi / 2)
end)

test("an aim inside the arc is unchanged", function()
    near(MountedAim.clampToArc(0, math.rad(60), 90), math.rad(60))
end)

test("an aim outside the arc is pulled to its edge on the same side", function()
    near(MountedAim.clampToArc(0, math.rad(150), 90), math.rad(90))
    near(MountedAim.clampToArc(0, math.rad(-150), 90), math.rad(-90))
end)

test("the arc works across the minus pi to pi seam", function()
    near(MountedAim.clampToArc(math.rad(170), math.rad(-170), 30), math.rad(-170))
end)

test("the default arc of 180 allows shooting straight behind", function()
    near(math.abs(MountedAim.clampToArc(0, math.pi, nil)), math.pi)
end)

test("direction is a unit vector along the angle", function()
    local x, y = MountedAim.direction(math.pi / 2)
    near(x, 0, "x")
    near(y, 1, "y")
end)
