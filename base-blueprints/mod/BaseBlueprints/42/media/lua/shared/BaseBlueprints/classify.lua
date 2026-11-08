--- Decides what kind of map object something is and whether a blueprint
--- cares about it. Works on class names and sprite names only, so it runs
--- outside the game too.
local Classify = {}

--- Object classes checked with instanceof when tostring gives no class name.
--- Most specific first; IsoObject is the fallback.
Classify.KNOWN = {
    "IsoWorldInventoryObject", "IsoDeadBody", "IsoTree", "IsoFire", "IsoBrokenGlass",
    "IsoBarricade", "IsoGenerator", "IsoDoor", "IsoWindow", "IsoWindowFrame", "IsoCurtain",
    "IsoLightSwitch", "IsoStove", "IsoBarbecue", "IsoFireplace", "IsoRadio", "IsoTelevision",
    "IsoJukebox", "IsoClothingWasher", "IsoClothingDryer", "IsoCombinationWasherDryer",
    "IsoCompost", "IsoMannequin", "IsoThumpable",
}

--- Classes a blueprint never records, keeps or removes: loose items, bodies,
--- trees, fire, broken glass, barricades and generators.
Classify.EXCLUDED = {
    IsoWorldInventoryObject = true,
    IsoDeadBody = true,
    IsoTree = true,
    IsoFire = true,
    IsoBrokenGlass = true,
    IsoBarricade = true,
    IsoGenerator = true,
    IsoZombie = true,
    IsoPlayer = true,
    IsoAnimal = true,
    BaseVehicle = true,
}

--- Classes whose sprite changes with their state (open door, smashed or open
--- window, drawn curtain, lamp or stove turned on). They are compared by
--- sprite sheet so using them never counts as a change.
Classify.STATEFUL = {
    IsoDoor = true,
    IsoWindow = true,
    IsoCurtain = true,
    IsoLightSwitch = true,
    IsoStove = true,
    IsoBarbecue = true,
    IsoFireplace = true,
    IsoRadio = true,
    IsoTelevision = true,
    IsoJukebox = true,
}

--- Sprite name prefixes the erosion system adds and changes over time
--- (grass, bushes, vines, leaves, wall cracks). Ignored everywhere.
Classify.NATURE_PREFIXES = {
    "e_", "f_", "d_", "vegetation_", "blends_grassoverlays", "lighting_outdoor_01_grass",
}

--- Pulls the simple class name out of a Java toString ("...IsoDoor@1f2e").
function Classify.fromToString(text)
    if type(text) ~= "string" then
        return nil
    end
    local found = nil
    for name in string.gmatch(text, "zombie%.[%w_%.]-%.([%w_]+)@%x+") do
        found = name
    end
    return found
end

--- Returns true for classes a blueprint ignores.
function Classify.isExcluded(cls)
    return Classify.EXCLUDED[cls] == true
end

--- Returns true for sprites the erosion system owns.
function Classify.isNature(spriteName)
    if type(spriteName) ~= "string" then
        return false
    end
    for _, prefix in ipairs(Classify.NATURE_PREFIXES) do
        if string.sub(spriteName, 1, #prefix) == prefix then
            return true
        end
    end
    return false
end

--- Returns the sprite sheet of a sprite name ("fixtures_doors_01_12" ->
--- "fixtures_doors_01"), or the name itself when it has no number.
function Classify.sheet(spriteName)
    if type(spriteName) ~= "string" then
        return ""
    end
    return string.match(spriteName, "^(.*)_%d+$") or spriteName
end

return Classify
