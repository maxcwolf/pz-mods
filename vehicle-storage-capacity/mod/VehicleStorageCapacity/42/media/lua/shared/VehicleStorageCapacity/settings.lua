--- Reads this mod's sandbox options with safe defaults. `fromSandbox` is pure so
--- it can be tested; `current` reads the live SandboxVars table in game.
local Settings = {}

Settings.MIN_PERCENT = 1
Settings.MAX_PERCENT = 1000

Settings.DEFAULTS = {
    trunk = 100,
    seat = 100,
    glovebox = 100,
    trailer = 100,
}

--- Returns a percent option rounded and clamped to the allowed range, or its default.
local function percent(options, key, default)
    local value = options and options[key]
    if type(value) ~= "number" then
        return default
    end
    value = math.floor(value + 0.5)
    return math.max(Settings.MIN_PERCENT, math.min(Settings.MAX_PERCENT, value))
end

--- Builds the settings table from the sandbox options page (or nil for all defaults).
function Settings.fromSandbox(options)
    local d = Settings.DEFAULTS
    return {
        trunk = percent(options, "TrunkPercent", d.trunk),
        seat = percent(options, "SeatPercent", d.seat),
        glovebox = percent(options, "GloveBoxPercent", d.glovebox),
        trailer = percent(options, "TrailerPercent", d.trailer),
    }
end

--- Returns the settings for the running game.
function Settings.current()
    local vars = SandboxVars and SandboxVars.VehicleStorageCapacity
    return Settings.fromSandbox(vars)
end

--- Returns true when every category is at 100, so the mod changes nothing.
function Settings.isVanilla(settings)
    for _, value in pairs(settings) do
        if value ~= 100 then
            return false
        end
    end
    return true
end

--- Formats the settings for the console log.
function Settings.describe(settings)
    return "trunks " .. tostring(settings.trunk) .. ", seats " .. tostring(settings.seat)
        .. ", glove boxes " .. tostring(settings.glovebox) .. ", trailers " .. tostring(settings.trailer)
        .. " (percent)"
end

return Settings
