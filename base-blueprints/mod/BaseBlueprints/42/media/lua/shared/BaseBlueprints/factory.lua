--- Which game constructor rebuilds a recorded object, and which IsoThumpable
--- settings are carried over. The constructors themselves are called from
--- client/BaseBlueprints/build.lua; this only decides.
local Factory = {}

--- Classes made with Class.new(cell, square, sprite), like the game's own
--- furniture placement does for them.
Factory.APPLIANCES = {
    IsoStove = true,
    IsoBarbecue = true,
    IsoFireplace = true,
    IsoRadio = true,
    IsoTelevision = true,
    IsoJukebox = true,
    IsoClothingWasher = true,
    IsoClothingDryer = true,
    IsoCombinationWasherDryer = true,
    IsoCompost = true,
}

local KINDS = {
    IsoDoor = "door",
    IsoWindow = "window",
    IsoWindowFrame = "frame",
    IsoCurtain = "curtain",
    IsoLightSwitch = "light",
    IsoThumpable = "thumpable",
    IsoMannequin = "mannequin",
    IsoObject = "plain",
}

--- Returns how to rebuild a record: "floor", "door", "window", "frame",
--- "curtain", "light", "thumpable", "mannequin", "appliance", "plain", or
--- "brush" (anything else goes through the game's own place-any-tile code).
function Factory.kind(record)
    if record.floor then
        return "floor"
    end
    if Factory.APPLIANCES[record.cls] then
        return "appliance"
    end
    return KINDS[record.cls] or "brush"
end

--- IsoThumpable settings saved and restored: record field, getter, setter.
--- Max health comes before health so the health is not clamped.
Factory.THUMPABLE_FLAGS = {
    { "door", "isDoor", "setIsDoor" },
    { "doorFrame", "isDoorFrame", "setIsDoorFrame" },
    { "corner", "isCorner", "setCorner" },
    { "thumpFloor", "isFloor", "setIsFloor" },
    { "stairs", "isStairs", "setIsStairs" },
    { "blockAll", "isBlockAllTheSquare", "setBlockAllTheSquare" },
    { "pass", "isCanPassThrough", "setCanPassThrough" },
    { "hoppable", "isHoppable", "setIsHoppable" },
    { "thumpable", "isThumpable", "setIsThumpable" },
    { "barricade", "getCanBarricade", "setCanBarricade" },
    { "dismantable", "isDismantable", "setIsDismantable" },
    { "paintable", "isPaintable", "setPaintable" },
}

Factory.THUMPABLE_NUMBERS = {
    { "maxHealth", "getMaxHealth", "setMaxHealth" },
    { "health", "getHealth", "setHealth" },
    { "crossSpeed", "getCrossSpeed", "setCrossSpeed" },
}

return Factory
