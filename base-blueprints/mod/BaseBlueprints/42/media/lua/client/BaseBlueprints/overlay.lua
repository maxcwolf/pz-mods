--- Highlights the claimed base on the player's level: changed squares in
--- gold, the claim's edge in faint blue. Changes are rescanned every couple
--- of seconds while the highlight is on.
local Rects = require("BaseBlueprints/rects")
local Keys = require("BaseBlueprints/keys")
local Runtime = require("BaseBlueprints/runtime")

local Overlay = {}

Overlay.enabled = false
Overlay.RESCAN_MS = 2000
Overlay.CHANGED = { 1.0, 0.75, 0.15, 0.45 }
Overlay.EDGE = { 0.35, 0.65, 1.0, 0.22 }
Overlay.byLevel = {}
Overlay.lastScan = 0

--- Groups changed keys into highlight rectangles per level.
function Overlay.levels(keys)
    local cells = {}
    for _, key in ipairs(keys) do
        local x, y, z = Keys.parse(key)
        if x then
            cells[z] = cells[z] or {}
            local list = cells[z]
            list[#list + 1] = { x = x, y = y }
        end
    end
    local out = {}
    for z, list in pairs(cells) do
        out[z] = Rects.merge(list)
    end
    return out
end

--- Recomputes the changed squares now.
function Overlay.rescan()
    local changes = Runtime.findChanges()
    Overlay.byLevel = changes and Overlay.levels(changes.keys) or {}
    Overlay.lastScan = getTimestampMs()
end

--- Turns the highlight on or off.
function Overlay.setEnabled(on)
    Overlay.enabled = on == true
    if Overlay.enabled then
        Overlay.rescan()
    end
end

--- Draws rectangles with one color on one level for a player.
local function draw(playerNum, rects, z, color)
    for _, r in ipairs(rects) do
        addAreaHighlightForPlayer(playerNum, r.x1, r.y1, r.x2 + 1, r.y2 + 1, z, color[1], color[2], color[3], color[4])
    end
end

--- Draws the highlight for this frame.
function Overlay.onRenderTick()
    if not Overlay.enabled then
        return
    end
    local player = getPlayer()
    local claim = Runtime.cache and Runtime.cache.claim
    if not player or not claim then
        return
    end
    if getTimestampMs() - Overlay.lastScan > Overlay.RESCAN_MS then
        Overlay.rescan()
    end
    local z = math.floor(player:getZ())
    local playerNum = player:getPlayerNum()
    if z >= claim.area.z1 and z <= claim.area.z2 then
        draw(playerNum, Rects.border(claim.area), z, Overlay.EDGE)
    end
    draw(playerNum, Overlay.byLevel[z] or {}, z, Overlay.CHANGED)
end

return Overlay
