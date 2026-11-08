--- Pure helpers for the list of recent NPC kills the editor can undo:
--- keeping it short and newest first, and describing each kill in plain words.
require "ALifeRepEditor/score"

ALifeRepEditor = ALifeRepEditor or {}

local Score = ALifeRepEditor.Score
local Ledger = { max = 6 }
ALifeRepEditor.KillLedger = Ledger

Ledger.CLASS_TEXT = {
    hostile = "was hostile to you",
    crime = "was a crook",
    neutral = "meant you no harm",
    careful = "only wanted to be left alone",
    friendly = "was on your side",
    surrendered = "had given up",
    attackedFirst = "attacked you first",
    unknown = "was a stranger",
}

--- Adds a kill to the front of the list, replacing an older copy and trimming to max.
function Ledger.push(list, entry, max)
    local limit = tonumber(max) or Ledger.max
    for index = #list, 1, -1 do
        if list[index].id == entry.id then table.remove(list, index) end
    end
    table.insert(list, 1, entry)
    while #list > limit do table.remove(list) end
    return list
end

--- Finds a kill by id and returns it with its position.
function Ledger.find(list, id)
    for index, entry in ipairs(list) do
        if entry.id == id then return entry, index end
    end
    return nil, nil
end

--- Describes how long ago a game-hour timestamp was.
function Ledger.ageText(atHours, nowHours)
    local hours = (tonumber(nowHours) or 0) - (tonumber(atHours) or 0)
    if hours < 1 then return "just now" end
    if hours < 48 then return tostring(math.floor(hours)) .. "h ago" end
    return tostring(math.floor(hours / 24)) .. "d ago"
end

--- Returns the plain-words reason A-Life gave for a kill's reputation change.
function Ledger.classText(class)
    return Ledger.CLASS_TEXT[tostring(class or "")] or Ledger.CLASS_TEXT.unknown
end

--- Builds the one-line description shown next to a kill's Undo button.
function Ledger.describe(entry, nowHours)
    local who = tostring(entry.name or "An NPC")
    if entry.factionName ~= nil and entry.factionName ~= "" then
        who = who .. " (" .. tostring(entry.factionName) .. ")"
    end
    local change = Score.signed(entry.applied)
    return who .. " " .. Ledger.classText(entry.class) .. ". Reputation " .. change
        .. ", " .. Ledger.ageText(entry.atHours, nowHours)
end

return Ledger
