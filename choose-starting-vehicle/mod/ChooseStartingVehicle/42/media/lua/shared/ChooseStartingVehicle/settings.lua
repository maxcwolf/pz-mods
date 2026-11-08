--- Reads this mod's sandbox options with safe defaults. `fromSandbox` is pure so
--- it can be tested; `current` reads the live SandboxVars table in game.
local Settings = {}

Settings.DEFAULTS = {
    enabled = true,
    partCondition = 100,
    fuelPercent = 100,
    batteryPercent = 100,
    keyInPocket = true,
    searchRadius = 30,
    allowTrailer = true,
    allowCargo = true,
}

--- Returns a number option clamped to a range, or its default.
local function number(options, key, default, low, high)
    local value = options and options[key]
    if type(value) ~= "number" then
        return default
    end
    return math.max(low, math.min(high, value))
end

--- Returns a boolean option, or its default.
local function bool(options, key, default)
    local value = options and options[key]
    if type(value) ~= "boolean" then
        return default
    end
    return value
end

--- Builds the settings table from a sandbox options page (or nil for all defaults).
function Settings.fromSandbox(options)
    local d = Settings.DEFAULTS
    return {
        enabled = bool(options, "Enabled", d.enabled),
        partCondition = number(options, "PartCondition", d.partCondition, 1, 100),
        fuelPercent = number(options, "FuelPercent", d.fuelPercent, 0, 100),
        batteryPercent = number(options, "BatteryPercent", d.batteryPercent, 0, 100),
        keyInPocket = bool(options, "KeyInPocket", d.keyInPocket),
        searchRadius = number(options, "SearchRadius", d.searchRadius, 5, 80),
        allowTrailer = bool(options, "AllowTrailer", d.allowTrailer),
        allowCargo = bool(options, "AllowCargo", d.allowCargo),
    }
end

--- Returns the settings for the running game.
function Settings.current()
    return Settings.fromSandbox(SandboxVars and SandboxVars.ChooseStartingVehicle)
end

return Settings
