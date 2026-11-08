--- The undo list: what each placement, floor paint or removal changed, so
--- Ctrl+Z can put it back. Newest last, capped so it never grows forever.
local History = {}

History.LIMIT = 50

--- Returns an empty history.
function History.new(limit)
    return { actions = {}, limit = limit or History.LIMIT }
end

--- Adds an action ({ kind = "place" | "floor" | "remove", ... }), dropping
--- the oldest past the limit. Empty actions are ignored.
function History.push(history, action)
    local size = action.parts and #action.parts or (action.tiles and #action.tiles or 0)
    if size == 0 then
        return false
    end
    local list = history.actions
    list[#list + 1] = action
    while #list > history.limit do
        table.remove(list, 1)
    end
    return true
end

--- Takes the newest action off the list, or returns nil.
function History.pop(history)
    local list = history.actions
    if #list == 0 then
        return nil
    end
    return table.remove(list)
end

--- Returns how many actions can be undone.
function History.size(history)
    return #history.actions
end

return History
