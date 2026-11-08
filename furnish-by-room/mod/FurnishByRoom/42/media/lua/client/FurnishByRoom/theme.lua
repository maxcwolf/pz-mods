--- Colors and the drawing shared by the catalog window and the strip:
--- item cards (tile picture plus name), selected and plain button looks,
--- and fitting text to a width.
local Theme = {}

Theme.ACCENT = { r = 0.88, g = 0.64, b = 0.23, a = 1 }
Theme.SELECTED_BG = { r = 0.23, g = 0.18, b = 0.11, a = 1 }
Theme.PLAIN_BG = { r = 0.12, g = 0.12, b = 0.11, a = 0.9 }
Theme.BORDER = { r = 0.23, g = 0.23, b = 0.2, a = 1 }
Theme.CARD_BG = { r = 0.11, g = 0.11, b = 0.1, a = 0.95 }
Theme.TEXT = { r = 0.9, g = 0.89, b = 0.85, a = 1 }
Theme.MUTED = { r = 0.62, g = 0.6, b = 0.55, a = 1 }
Theme.GOOD = { r = 0.72, g = 0.85, b = 0.6, a = 1 }

--- Paints a button as selected (accent border) or plain.
function Theme.styleButton(button, selected)
    local bg = selected and Theme.SELECTED_BG or Theme.PLAIN_BG
    local border = selected and Theme.ACCENT or Theme.BORDER
    button.backgroundColor = { r = bg.r, g = bg.g, b = bg.b, a = bg.a }
    button.borderColor = { r = border.r, g = border.g, b = border.b, a = border.a }
    button.textColor = { r = Theme.TEXT.r, g = Theme.TEXT.g, b = Theme.TEXT.b, a = 1 }
end

--- Returns text cut with "..." so it fits the width in the font.
function Theme.fit(text, width, font)
    local tm = getTextManager()
    if tm:MeasureStringX(font, text) <= width then
        return text
    end
    local cut = text
    while #cut > 1 and tm:MeasureStringX(font, cut .. "...") > width do
        cut = string.sub(cut, 1, #cut - 1)
    end
    return cut .. "..."
end

--- Draws one item card: the tile picture scaled to fit and its name.
function Theme.drawCard(panel, entry, x, y, w, h, selected, hover)
    local bg = selected and Theme.SELECTED_BG or Theme.CARD_BG
    panel:drawRect(x, y, w, h, bg.a, bg.r, bg.g, bg.b)
    local border = (selected or hover) and Theme.ACCENT or Theme.BORDER
    panel:drawRectBorder(x, y, w, h, border.a, border.r, border.g, border.b)
    local textH = getTextManager():getFontHeight(UIFont.Small)
    local pad = 4
    local texture = entry.sprite and getTexture(entry.sprite)
    if texture then
        local boxW, boxH = w - pad * 2, h - textH - pad * 3
        panel:drawTextureScaledAspect(texture, x + pad, y + pad, boxW, boxH, 1, 1, 1, 1)
    end
    local label = Theme.fit(entry.label, w - pad * 2, UIFont.Small)
    local c = Theme.TEXT
    panel:drawTextCentre(label, x + w / 2, y + h - textH - pad, c.r, c.g, c.b, c.a, UIFont.Small)
end

return Theme
