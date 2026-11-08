--- Works out which of a part's 3D models the preview should draw for the item
--- chosen for it. KI5 keeps the real item-to-model table in server Lua that
--- isn't loaded at the main menu, but its scripts list one model per item in
--- the same order as the items (true for 97% of installed KI5 parts), sometimes
--- after a stock model that shows when no add-on is fitted. Pure.
local PartModels = {}

--- Returns the position of an item type in a part's item list, or nil.
function PartModels.itemIndex(part, itemType)
    for i, name in ipairs(part.itemTypes or {}) do
        if name == itemType then
            return i
        end
    end
    return nil
end

--- Returns the item a choice stands for: the chosen item, nothing for "none",
--- and the first listed item for the game's choice (KI5's usual default).
function PartModels.effectiveItem(part, choice)
    if choice == "none" then
        return nil
    end
    if choice and PartModels.itemIndex(part, choice) then
        return choice
    end
    return (part.itemTypes or {})[1]
end

--- Returns the models to draw for a part holding `itemType` (nil = empty).
function PartModels.forItem(part, itemType)
    local models = part.models or {}
    local items = part.itemTypes or {}
    if #models == 0 then
        return {}
    end
    if #items == 0 then
        return models
    end
    if not itemType then
        if #models == #items + 1 then
            return { models[1] }
        end
        return {}
    end
    local index = PartModels.itemIndex(part, itemType)
    if #items == 1 or not index then
        return models
    end
    local offset = #models - #items
    if offset == 0 or offset == 1 then
        return { models[index + offset] }
    end
    return { models[math.min(index, #models)] }
end

--- Returns the models to draw for a part given the build's choice for it.
function PartModels.forChoice(part, choice)
    return PartModels.forItem(part, PartModels.effectiveItem(part, choice))
end

return PartModels
