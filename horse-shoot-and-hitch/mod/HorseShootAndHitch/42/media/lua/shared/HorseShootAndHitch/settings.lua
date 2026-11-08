--- Reads this mod's sandbox options with safe defaults. `fromSandbox` is pure so
--- it can be tested; `current` reads the live SandboxVars table in game.
local MountedAim = require("HorseShootAndHitch/mounted-aim")
local Tether = require("HorseShootAndHitch/tether")

local Settings = {}

--- Returns a number option or its default when missing or not a number.
local function number(options, key, default)
    local value = options and options[key]
    if type(value) ~= "number" then return default end
    return value
end

--- Builds the settings table from a sandbox options page (or nil for all defaults).
function Settings.fromSandbox(options)
    local shooting = true
    if options and options.MountedShooting == false then shooting = false end
    return {
        shooting = shooting,
        penalties = {
            stand = 0,
            walk = number(options, "WalkPenalty", MountedAim.DEFAULT_PENALTIES.walk),
            trot = number(options, "TrotPenalty", MountedAim.DEFAULT_PENALTIES.trot),
            gallop = number(options, "GallopPenalty", MountedAim.DEFAULT_PENALTIES.gallop),
        },
        arc = number(options, "AimArc", MountedAim.DEFAULT_ARC),
        radius = number(options, "TieRadius", Tether.DEFAULT_RADIUS),
    }
end

--- Returns the settings for the running game.
function Settings.current()
    local vars = SandboxVars and SandboxVars.HorseShootAndHitch
    return Settings.fromSandbox(vars)
end

return Settings
