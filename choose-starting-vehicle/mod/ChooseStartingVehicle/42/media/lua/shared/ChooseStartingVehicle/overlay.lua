--- Reads the game's mechanics overlay tables (ISCarMechanicsOverlay.CarList and
--- PartList, which vanilla and every KI5 vehicle fill in) into what the
--- diagram draws: the base image, one tinted image per part, and the click
--- box of each part, in the overlay's own pixel space. Pure: the tables are
--- passed in.
local Overlay = {}

Overlay.FOLDER = "media/ui/vehicles/mechanic overlay/"

--- Returns the CarList entry for a vehicle's overlay name, or nil.
function Overlay.carProps(carList, overlayName)
    local props = carList and carList[overlayName]
    if not props or not props.imgPrefix then
        return nil
    end
    return props
end

--- Returns the path of the diagram's base image.
function Overlay.baseImage(props)
    return Overlay.FOLDER .. props.imgPrefix .. "base.png"
end

--- Merges a part's global entry with the vehicle's own overrides: KI5 stores
--- per-vehicle images and boxes under `vehicles[imgPrefix]`, vanilla can
--- override images through the car's own PartList.
function Overlay.partProps(partList, props, partId)
    local global = partList and partList[partId]
    if not global then
        return nil
    end
    local merged = { img = global.img, multipleImg = global.multipleImg, x = global.x, y = global.y, x2 = global.x2, y2 = global.y2 }
    local carOverride = props.PartList and props.PartList[partId]
    if carOverride then
        for key, value in pairs(carOverride) do
            merged[key] = value
        end
    end
    local perVehicle = global.vehicles and global.vehicles[props.imgPrefix]
    if perVehicle then
        for key, value in pairs(perVehicle) do
            merged[key] = value
        end
    end
    return merged
end

--- Returns the image paths a part draws (one, or several for multipleImg).
function Overlay.partImages(props, partProps)
    local images = {}
    if not partProps or not partProps.img then
        return images
    end
    if partProps.multipleImg and type(partProps.img) == "table" then
        for _, name in ipairs(partProps.img) do
            images[#images + 1] = Overlay.FOLDER .. props.imgPrefix .. name .. ".png"
        end
    elseif type(partProps.img) == "string" then
        images[1] = Overlay.FOLDER .. props.imgPrefix .. partProps.img .. ".png"
    end
    return images
end

--- True when a point falls in a part's click box (vanilla's rule).
function Overlay.contains(partProps, x, y)
    if not (partProps and partProps.x and partProps.y and partProps.x2 and partProps.y2) then
        return false
    end
    return x >= partProps.x and x <= partProps.x2 and y > partProps.y and y <= partProps.y2
end

--- Builds the whole diagram for a list of part ids: { base, x, y, parts =
--- {{id, images, box}} }, or nil when the vehicle has no overlay.
function Overlay.diagram(carList, partList, overlayName, partIds)
    local props = Overlay.carProps(carList, overlayName)
    if not props then
        return nil
    end
    local diagram = { base = Overlay.baseImage(props), x = props.x or 0, y = props.y or 0, parts = {} }
    for _, id in ipairs(partIds) do
        local partProps = Overlay.partProps(partList, props, id)
        if partProps then
            diagram.parts[#diagram.parts + 1] = { id = id, images = Overlay.partImages(props, partProps), box = partProps }
        end
    end
    return diagram
end

--- Returns the id of the part under a point, or nil.
function Overlay.hit(diagram, x, y)
    for _, part in ipairs(diagram and diagram.parts or {}) do
        if Overlay.contains(part.box, x, y) then
            return part.id
        end
    end
    return nil
end

--- Returns how "healthy" a part should look for its state, 0..100, for the
--- same good-to-bad color ramp the mechanics window uses: fitted parts green,
--- the game's choice amber, removed parts red.
function Overlay.stateLevel(state)
    if state == "none" then
        return 0
    end
    if state == "default" then
        return 55
    end
    return 100
end

--- Blends from the bad color to the good one by a 0..100 level, like the
--- mechanics window's condition colors. Colors are {r, g, b}.
function Overlay.mix(bad, good, level)
    local t = math.max(0, math.min(100, level or 0)) / 100
    return {
        r = bad.r + (good.r - bad.r) * t,
        g = bad.g + (good.g - bad.g) * t,
        b = bad.b + (good.b - bad.b) * t,
    }
end

return Overlay
