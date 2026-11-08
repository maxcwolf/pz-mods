--- Right-click menu for tying horses: "Dismount and tie to ..." while riding next
--- to a fence, pole or tree, and "Tie <horse> to ..." for a loose horse nearby.
--- Untying uses vanilla's "Detach animal from ..." on the horse, which this mod patches.
local TetherWorld = require("HorseShootAndHitch/tether-world")
local TieHorseAction = require("HorseShootAndHitch/tie-horse-action")
local HorseManager = require("HorseMod/HorseManager")
local HorseUtils = require("HorseMod/Utils")
local Mounts = require("HorseMod/Mounts")
local Mounting = require("HorseMod/Mounting")
local MountingUtility = require("HorseMod/mounting/MountingUtility")
local RidingAPI = require("HorseMod/api/RidingAPI")

local TieMenu = {}

--- How close the horse must be to the post, in tiles, to dismount and tie in one go.
TieMenu.MOUNTED_REACH = 2.5

RidingAPI.addValidTimedAction("HorseShootAndHitch_TieHorseAction")

--- Distance between a moving object and the centre of a square.
local function distanceTo(object, square)
    local dx = object:getX() - (square:getX() + 0.5)
    local dy = object:getY() - (square:getY() + 0.5)
    return math.sqrt(dx * dx + dy * dy)
end

--- Returns the first fence, pole or tree among the clicked objects.
function TieMenu.findPost(worldobjects)
    for _, object in ipairs(worldobjects) do
        if TetherWorld.isTiePoint(object) then return object end
        local square = object:getSquare()
        local post = square and TetherWorld.findTiePoint(square, nil)
        if post then return post end
    end
    return nil
end

--- Returns a readable name for a post, for menu labels.
function TieMenu.postName(post)
    if instanceof(post, "IsoTree") then return getText("IGUI_HorseShootAndHitch_Tree") end
    if post:getName() then return post:getName() end
    if post:isHoppable() or post:isTallHoppable() then return getText("IGUI_HorseShootAndHitch_Fence") end
    return getText("IGUI_HorseShootAndHitch_Post")
end

--- Returns a readable name for a horse the way vanilla's animal menus do.
function TieMenu.horseName(horse)
    if horse:getCustomName() then return horse:getCustomName() end
    local text = getText("IGUI_AnimalType_" .. horse:getAnimalType())
    local breed = horse:getData():getBreed()
    if breed then text = getText("IGUI_Breed_" .. breed:getName()) .. " " .. text end
    return text
end

--- Marks a menu option unavailable with a tooltip explaining why.
local function disable(option, reasonKey)
    option.notAvailable = true
    local tooltip = ISWorldObjectContextMenu.addToolTip()
    tooltip:setName(getText(reasonKey))
    option.toolTip = tooltip
end

--- Queues dismounting, walking to the post and tying the horse.
function TieMenu.onDismountAndTie(player, horse, post)
    local mountPosition = MountingUtility.getNearestMountPosition(player, horse)
    if not mountPosition then return end
    Mounting.dismountHorse(player, horse, mountPosition)
    luautils.walkAdj(player, post:getSquare(), true)
    ISTimedActionQueue.add(TieHorseAction:new(player, horse, post))
end

--- Queues walking to the post and tying a loose horse.
function TieMenu.onTie(player, horse, post)
    if luautils.walkAdj(player, post:getSquare(), false) then
        ISTimedActionQueue.add(TieHorseAction:new(player, horse, post))
    end
end

--- Lists loose horses near the post that could be tied to it.
function TieMenu.looseHorsesNear(post)
    local found = {}
    local square = post:getSquare()
    for i = 1, #HorseManager.horses do
        local horse = HorseManager.horses[i]
        if horse and not horse:isDead() and not Mounts.hasRider(horse)
            and not TetherWorld.get(horse) and not horse:getData():getAttachedTree()
            and HorseUtils.isAdult(horse)
            and distanceTo(horse, square) <= TieHorseAction.MAX_HORSE_DISTANCE then
            found[#found + 1] = horse
        end
    end
    return found
end

--- Adds the tie option, greyed out with a reason when there is nothing to tie with.
local function addTieOption(context, label, player, horse, post, onSelect)
    local option = context:addOption(label, player, onSelect, horse, post)
    option.iconTexture = getTexture("Item_Rope2")
    if not TetherWorld.costFor(player, horse) and not player:isAnimalCheat() then
        disable(option, "Tooltip_HorseShootAndHitch_NeedReinsOrRope")
    end
    return option
end

--- Fills the world context menu with tie options.
function TieMenu.onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    if test then return end
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    local post = TieMenu.findPost(worldobjects)
    if not post then return end
    local postName = TieMenu.postName(post)

    local mount = Mounts.getMount(player)
    if mount then
        if distanceTo(mount, post:getSquare()) <= TieMenu.MOUNTED_REACH then
            addTieOption(context, getText("ContextMenu_HorseShootAndHitch_DismountAndTie", postName),
                player, mount, post, TieMenu.onDismountAndTie)
        end
        return
    end

    for _, horse in ipairs(TieMenu.looseHorsesNear(post)) do
        addTieOption(context, getText("ContextMenu_HorseShootAndHitch_TieTo", TieMenu.horseName(horse), postName),
            player, horse, post, TieMenu.onTie)
    end
end

Events.OnFillWorldObjectContextMenu.Add(TieMenu.onFillWorldObjectContextMenu)

return TieMenu
