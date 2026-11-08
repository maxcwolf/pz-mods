--- Rotation: the R key steps through an entry's facings in the game's own
--- order (north, west, south, east), skipping the ones it doesn't have.
local Faces = {}

Faces.ORDER = { "N", "W", "S", "E" }

--- Returns the entry's sprites in rotation order.
function Faces.list(entry)
    local out = {}
    for _, face in ipairs(Faces.ORDER) do
        if entry.faces[face] then
            out[#out + 1] = entry.faces[face]
        end
    end
    if #out == 0 and entry.faces["_"] then
        out[1] = entry.faces["_"]
    end
    return out
end

--- Returns the sprite after current, wrapping around.
function Faces.next(entry, current)
    local list = Faces.list(entry)
    if #list == 0 then
        return current
    end
    for i, sprite in ipairs(list) do
        if sprite == current then
            return list[i % #list + 1]
        end
    end
    return list[1]
end

return Faces
