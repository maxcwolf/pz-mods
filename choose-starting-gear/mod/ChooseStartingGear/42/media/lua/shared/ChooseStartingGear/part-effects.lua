--- Pure helpers that turn a weapon part's stat modifiers into readable text,
--- so the panel can show what each attachment does before it is chosen.
local PartEffects = {}

--- Stat fields in display order: the effect key and the raw stat it reads.
--- Signed effects show "+" or "-"; sight and light are shown as plain values.
PartEffects.ORDER = {
    { key = "HitChance", stat = "hitChance" },
    { key = "Range", stat = "maxRange" },
    { key = "Sight" },
    { key = "LowLight", stat = "lowLight" },
    { key = "AimingTime", stat = "aimingTime" },
    { key = "RecoilDelay", stat = "recoilDelay" },
    { key = "ReloadTime", stat = "reloadTime" },
    { key = "Spread", stat = "spread" },
    { key = "Damage", stat = "damage" },
    { key = "ClipSize", stat = "clipSize" },
    { key = "Light", stat = "light", unsigned = true },
    { key = "Weight", stat = "weightModifier" },
}

--- Formats a number with at most two decimals and no trailing zeros.
local function number(value)
    local text = string.format("%.2f", value)
    text = string.gsub(text, "0+$", "")
    text = string.gsub(text, "%.$", "")
    if text == "-0" then
        text = "0"
    end
    return text
end

--- Formats a number with a leading "+" when it is positive.
local function signed(value)
    local text = number(value)
    if value > 0 then
        text = "+" .. text
    end
    return text
end

--- Returns the effects a part has as an ordered list of { key, text },
--- skipping every stat the part leaves at zero.
function PartEffects.effects(stats)
    stats = stats or {}
    local list = {}
    for _, field in ipairs(PartEffects.ORDER) do
        if field.key == "Sight" then
            local low, high = stats.minSight or 0, stats.maxSight or 0
            if high > 0 then
                table.insert(list, { key = "Sight", text = number(low) .. "-" .. number(high) })
            end
        else
            local value = stats[field.stat] or 0
            if value ~= 0 then
                table.insert(list, { key = field.key, text = field.unsigned and number(value) or signed(value) })
            end
        end
    end
    return list
end

--- Returns the effects as "Label +n" strings, using `label(key)` for names.
local function lines(stats, label)
    local out = {}
    for _, effect in ipairs(PartEffects.effects(stats)) do
        table.insert(out, label(effect.key) .. " " .. effect.text)
    end
    return out
end

--- Returns a one-line summary such as "Accuracy +5, Weight +0.6".
function PartEffects.summary(stats, label)
    return table.concat(lines(stats, label), ", ")
end

--- Returns tooltip rich text: the part type description, a blank line, then
--- one effect per line.
function PartEffects.tooltip(stats, label, description)
    local body = table.concat(lines(stats, label), " <LINE> ")
    if description and description ~= "" then
        if body == "" then
            return description
        end
        return description .. " <LINE> <LINE> " .. body
    end
    return body
end

CSG_PartEffects = PartEffects
return PartEffects
