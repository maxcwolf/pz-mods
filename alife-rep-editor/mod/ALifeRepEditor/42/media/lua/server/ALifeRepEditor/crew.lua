--- Server-side editing of the player's crew: A-Life's nine companion skills,
--- the strength and aiming that decide how they fight, and their gear. Skills
--- live in A-Life's companion state; fighting stats, firearm permission and
--- outfits are saved in the editor's world data and laid over A-Life's plan
--- each time the body loads (see hooks.lua and ADR 0007).
require "ALifeRepEditor/editor"
require "ALifeRepEditor/people"
require "ALifeRepEditor/crew-rows"
require "ALifeRepEditor/item-info"

ALifeRepEditor = ALifeRepEditor or {}

local Editor = ALifeRepEditor.Editor
local People = ALifeRepEditor.People
local Rows = ALifeRepEditor.CrewRows
local Info = ALifeRepEditor.ItemInfo

local Crew = { adapters = {}, carryCap = 60, giveCap = 20, ammoCap = 600, ratingFallback = 5 }
ALifeRepEditor.Crew = Crew

Crew.STAMP = { strength = "ALifeStrength", aiming = "ALifeAiming" }

--- Returns A-Life's weapon, shell-state and profile-hydrator modules (any may be nil).
function Crew.alife()
    local P = ProjectALife or {}
    return { weapons = P.Weapons, shellState = P.ShellState, hydrator = P.ProfileHydrator }
end

--- Returns an item type's details, through the test adapter when one is set.
function Crew.itemInfo(itemType)
    if type(Crew.adapters.itemInfo) == "function" then return Crew.adapters.itemInfo(itemType) end
    return Info.find(itemType)
end

--- Returns the body location an item type is worn on, or nil.
function Crew.locationOf(itemType)
    local info = Crew.itemInfo(itemType)
    if info ~= nil and info.location ~= nil then return info.location end
    local hydrator = Crew.alife().hydrator
    if hydrator ~= nil and type(hydrator.scriptLocation) == "function" then
        local ok, where = pcall(hydrator.scriptLocation, itemType)
        if ok and where ~= nil then return tostring(where) end
    end
    return nil
end

--- Returns the saved overrides for one NPC, creating them when asked.
function Crew.saved(uid, create)
    local store = Editor.store()
    if store == nil or uid == nil then return nil end
    if type(store.crew) ~= "table" then
        if not create then return nil end
        store.crew = {}
    end
    local entry = store.crew[tostring(uid)]
    if entry == nil and create then
        entry = {}
        store.crew[tostring(uid)] = entry
    end
    return entry
end

--- Deletes one NPC's saved fighting stats, firearm permission and outfit.
function Crew.forget(uid)
    local store = Editor.store()
    if store ~= nil and type(store.crew) == "table" then store.crew[tostring(uid)] = nil end
end

--- Lays an NPC's saved overrides over the plan A-Life built for their body.
function Crew.overlay(plan, actor)
    if type(plan) ~= "table" or type(actor) ~= "table" then return plan end
    return Rows.applyOverrides(plan, Crew.saved(actor.uid, false))
end

--- Returns true when an NPC has a saved outfit, so A-Life's seasonal wardrobe leaves it alone.
function Crew.outfitPinned(actor)
    local saved = type(actor) == "table" and Crew.saved(actor.uid, false) or nil
    return type(saved) == "table" and type(saved.outfit) == "table" and #saved.outfit > 0
end

--- Returns a crew member's record, name and loaded body, or nil and a refusal message.
function Crew.member(player, uid)
    local companions = People.crew()
    if companions == nil then return nil, Rows.refusal("disabled") end
    local record = People.record(uid)
    if record == nil then return nil, Rows.refusal("gone") end
    local name = Editor.nameOf(record)
    if People.crewOf(record, People.crewKey(player)) ~= "yours" then return nil, Rows.refusal("not_yours", name) end
    local shell = type(companions.shellOf) == "function" and companions.shellOf(record.uid) or nil
    return { record = record, name = name, shell = shell, companions = companions }
end

--- Returns a body's mod data table, or nil.
local function dataOf(object)
    if object == nil or type(object.getModData) ~= "function" then return nil end
    local ok, data = pcall(object.getModData, object)
    return ok and type(data) == "table" and data or nil
end

--- Sets one of A-Life's body stats the way its hydrator does: an animation variable plus mod data.
function Crew.stamp(shell, name, value)
    if shell == nil then return end
    pcall(function() shell:SetVariable(name, tostring(value)) end)
    local data = dataOf(shell)
    if data ~= nil then data["Project" .. name] = value end
end

--- Returns a crew member's nine skill levels from A-Life's companion state.
function Crew.skillsOf(record)
    local entry = type(record.memory) == "table" and record.memory.companion or nil
    local skills = type(entry) == "table" and type(entry.state) == "table" and entry.state.skills or nil
    local result = {}
    for _, id in ipairs(Rows.SKILLS) do
        result[id] = Rows.clamp(type(skills) == "table" and skills[id] or 0, Rows.SKILL_MAX)
    end
    return result
end

--- Changes skill levels in A-Life's companion state; change(skills) edits them in place.
function Crew.writeSkills(member, change)
    local companions, done = member.companions, false
    if type(companions.write) ~= "function" or type(companions.rules) ~= "function" then return false end
    local rules = companions.rules()
    companions.write(member.record.uid, function(record)
        local entry = type(record.memory) == "table" and record.memory.companion or nil
        if type(entry) ~= "table" then return end
        local state = type(entry.state) == "table" and rules.sanitize(entry.state) or nil
        if state == nil then state = rules.fresh(rules.defaultsFor(record.profileId)) end
        entry.state = state
        change(state.skills)
        for _, id in ipairs(Rows.SKILLS) do state.skills[id] = Rows.clamp(state.skills[id], Rows.SKILL_MAX) end
        done = true
    end)
    return done
end

--- Returns a crew member's strength and aiming: saved, then on the body, then from A-Life's plan.
function Crew.ratingsOf(member)
    local saved = Crew.saved(member.record.uid, false) or {}
    local data = dataOf(member.shell) or {}
    local plan
    local result = {}
    for _, id in ipairs(Rows.RATINGS) do
        local value = tonumber(saved[id]) or tonumber(data["Project" .. Crew.STAMP[id]])
        if value == nil then
            if plan == nil then
                local hydrator = Crew.alife().hydrator
                local ok, built = false, nil
                if hydrator ~= nil and type(hydrator.plan) == "function" then ok, built = pcall(hydrator.plan, member.record) end
                plan = ok and type(built) == "table" and built or false
            end
            value = plan and tonumber(plan[id]) or Crew.ratingFallback
        end
        result[id] = Rows.clamp(value, Rows.RATING_MAX)
    end
    return result
end

--- Saves a fighting stat for a crew member and puts it on their body now.
function Crew.writeRating(member, id, value)
    local saved = Crew.saved(member.record.uid, true)
    if saved == nil then return false end
    saved[id] = Rows.clamp(value, Rows.RATING_MAX)
    Crew.stamp(member.shell, Crew.STAMP[id], saved[id])
    return true
end

--- Moves one of A-Life's companion skills up or down.
function Crew.changeSkill(player, uid, skill, delta)
    local member, refusal = Crew.member(player, uid)
    if member == nil then return false, refusal end
    if not Rows.isSkill(skill) then return false, Rows.refusal("unknown_skill") end
    local before = Crew.skillsOf(member.record)[skill]
    local after = Rows.clamp(before + math.floor(tonumber(delta) or 0), Rows.SKILL_MAX)
    if not Crew.writeSkills(member, function(skills) skills[skill] = after end) then
        return false, Rows.refusal("not_saved")
    end
    return true, member.name .. ": " .. Rows.SKILL_LABELS[skill] .. " " .. before .. " -> " .. after .. "."
end

--- Moves strength or aiming up or down.
function Crew.changeRating(player, uid, rating, delta)
    local member, refusal = Crew.member(player, uid)
    if member == nil then return false, refusal end
    if not Rows.isRating(rating) then return false, Rows.refusal("unknown_skill") end
    local before = Crew.ratingsOf(member)[rating]
    local after = Rows.clamp(before + math.floor(tonumber(delta) or 0), Rows.RATING_MAX)
    if not Crew.writeRating(member, rating, after) then return false, Rows.refusal("not_saved") end
    return true, member.name .. ": " .. Rows.RATING_LABELS[rating] .. " " .. before .. " -> " .. after .. "."
end

--- Sets every skill and both fighting stats to the top.
function Crew.maxAll(player, uid)
    local member, refusal = Crew.member(player, uid)
    if member == nil then return false, refusal end
    local wrote = Crew.writeSkills(member, function(skills)
        for _, id in ipairs(Rows.SKILLS) do skills[id] = Rows.SKILL_MAX end
    end)
    for _, id in ipairs(Rows.RATINGS) do wrote = Crew.writeRating(member, id, Rows.RATING_MAX) and wrote end
    if not wrote then return false, Rows.refusal("not_saved") end
    return true, member.name .. " now has every skill and fighting stat at " .. Rows.SKILL_MAX .. "."
end

--- Returns a body's inventory container and its items as a Lua list.
function Crew.carried(shell)
    local ok, inventory = pcall(function() return shell:getInventory() end)
    if not ok or inventory == nil then return nil, {} end
    local list = {}
    local itemsOk, items = pcall(function() return inventory:getItems() end)
    if itemsOk and items ~= nil then
        local count = tonumber((items:size())) or 0
        for index = 0, count - 1 do list[#list + 1] = items:get(index) end
    end
    return inventory, list
end

--- Returns an item's id, or nil.
local function idOf(item)
    local ok, id = pcall(function() return item:getID() end)
    return ok and id ~= nil and tostring(id) or nil
end

--- Returns an item's full type, or nil.
local function typeOf(item)
    local ok, value = pcall(function() return item:getFullType() end)
    return ok and type(value) == "string" and value or nil
end

--- Returns an item's display name.
local function nameOf(item)
    local ok, value = pcall(function() return item:getDisplayName() end)
    if ok and type(value) == "string" and value ~= "" then return value end
    return typeOf(item) or "?"
end

--- Returns true when an item is a weapon.
local function isWeapon(item)
    local ok, value = pcall(function() return item:IsWeapon() end)
    return ok and value == true
end

--- Returns true when an item is a gun.
function Crew.isGun(item)
    if not isWeapon(item) then return false end
    local ok, maximum = pcall(function() return item:getMaxAmmo() end)
    if ok and (tonumber(maximum) or 0) > 0 then return true end
    local aimed = false
    pcall(function() aimed = item:isAimedFirearm() == true end)
    return aimed
end

--- Returns the weapon a body is holding, or nil.
function Crew.current(shell)
    local weapons = Crew.alife().weapons
    if shell == nil or weapons == nil or type(weapons.current) ~= "function" then return nil end
    local ok, item = pcall(weapons.current, shell)
    return ok and item or nil
end

--- Returns what the Crew tab lists about each carried item.
function Crew.describeItems(shell)
    local _, items = Crew.carried(shell)
    local current = Crew.current(shell)
    local result = {}
    for _, item in ipairs(items) do
        local data = dataOf(item) or {}
        local itemType = typeOf(item)
        if itemType ~= nil and itemType ~= "Base.BareHands" then
            result[#result + 1] = { id = idOf(item), type = itemType, name = nameOf(item), weapon = isWeapon(item),
                worn = data.ProjectALifeAuthoredClothing == true, equipped = item == current }
        end
        if #result >= Crew.carryCap then break end
    end
    return Rows.carryRows(result)
end

--- Returns the reserve field A-Life keeps a gun slot's spare rounds in.
local function reserveField(slot)
    return slot == "secondary" and "ProjectALifeSecondaryAmmoUnits" or "ProjectALifePrimaryAmmoUnits"
end

--- Returns the held weapon's name and, for a gun, its loaded and spare rounds.
function Crew.weaponLine(shell)
    local current = Crew.current(shell)
    if current == nil then return nil end
    local line = { name = nameOf(current), gun = Crew.isGun(current) }
    if line.gun then
        local weapons = Crew.alife().weapons
        local slot = weapons ~= nil and type(weapons.slot) == "function" and weapons.slot(current) or "primary"
        local loaded = 0
        pcall(function() loaded = tonumber((current:getCurrentAmmoCount())) or 0 end)
        local data = dataOf(shell) or {}
        line.loaded, line.spare = loaded, math.floor(tonumber(data[reserveField(slot)]) or 0)
    end
    return line
end

--- Finds a carried item by id.
function Crew.findItem(shell, id)
    local _, items = Crew.carried(shell)
    for _, item in ipairs(items) do
        if idOf(item) == tostring(id) then return item end
    end
    return nil
end

--- Returns a body's loaded member, or nil and the "get closer" refusal.
local function loadedMember(player, uid)
    local member, refusal = Crew.member(player, uid)
    if member == nil then return nil, refusal end
    if member.shell == nil then return nil, Rows.refusal("unloaded", member.name) end
    return member
end

--- Lets a crew member use guns from now on, even if A-Life's profile gave them none.
function Crew.allowFirearms(member)
    local saved = Crew.saved(member.record.uid, true)
    if saved ~= nil then saved.firearms = true end
    Crew.stamp(member.shell, "ALifeFirearmsAuthored", true)
end

--- Makes a carried weapon the one a crew member holds; returns true when A-Life took it.
function Crew.hold(member, item, info)
    local weapons = Crew.alife().weapons
    if weapons == nil or type(weapons.select) ~= "function" then return false end
    local data = dataOf(item)
    local slot = data ~= nil and data.ProjectALifeWeaponSlot or nil
    if slot == nil then
        slot = Rows.slotFor(info or { firearm = Crew.isGun(item) })
        if data ~= nil then data.ProjectALifeWeaponSlot = slot end
    end
    if slot ~= "melee" then Crew.allowFirearms(member) end
    local ok, held = pcall(weapons.select, member.shell, item, slot)
    return ok and held == true
end

--- Spawns an item into a crew member's inventory: weapons are held, clothing is worn, the rest carried.
function Crew.give(player, uid, itemType, count)
    local member, refusal = loadedMember(player, uid)
    if member == nil then return false, refusal end
    local info = Crew.itemInfo(itemType)
    if info == nil then return false, Rows.refusal("unknown_item", member.name, itemType) end
    local action = Rows.giveAction(info.kind)
    if action == "wear" then return Crew.wear(player, uid, itemType) end
    local inventory = Crew.carried(member.shell)
    if inventory == nil then return false, Rows.refusal("unloaded", member.name) end
    if action == "equip" then
        local made, item = pcall(function() return inventory:AddItem(info.type) end)
        if not made or item == nil then return false, Rows.refusal("unknown_item", member.name, info.name) end
        local data = dataOf(item)
        if data ~= nil then data.ProjectALifeWeaponSlot = Rows.slotFor(info) end
        if not Crew.hold(member, item, info) then
            return true, "Gave " .. member.name .. " the " .. info.name .. ", but A-Life won't let them hold it."
        end
        if info.firearm then
            local weapons = Crew.alife().weapons
            pcall(weapons.addReserve, member.shell, Rows.slotFor(info), Rows.GUN_ROUNDS)
            return true, member.name .. " is holding the " .. info.name .. ", with " .. Rows.GUN_ROUNDS .. " rounds."
        end
        return true, member.name .. " is holding the " .. info.name .. "."
    end
    local wanted = math.max(1, math.min(Crew.giveCap, math.floor(tonumber(count) or 1)))
    local shellState, given = Crew.alife().shellState, 0
    for _ = 1, wanted do
        local made, item = pcall(function() return inventory:AddItem(info.type) end)
        if made and item ~= nil then
            given = given + 1
            if shellState ~= nil and type(shellState.markScavenged) == "function" then shellState.markScavenged(item) end
        end
    end
    if given == 0 then return false, Rows.refusal("unknown_item", member.name, info.name) end
    return true, "Gave " .. member.name .. " " .. (given > 1 and (given .. " x ") or "") .. info.name .. "."
end

--- Makes a carried weapon the one a crew member holds.
function Crew.equip(player, uid, id)
    local member, refusal = loadedMember(player, uid)
    if member == nil then return false, refusal end
    local item = Crew.findItem(member.shell, id)
    if item == nil or not isWeapon(item) then return false, Rows.refusal("no_item", member.name) end
    if not Crew.hold(member, item, nil) then return false, "A-Life won't let " .. member.name .. " hold that." end
    return true, member.name .. " is holding the " .. nameOf(item) .. "."
end

--- Returns what a crew member is wearing now: their saved outfit, what's on the body, or A-Life's plan.
function Crew.outfitOf(member)
    local saved = Crew.saved(member.record.uid, false)
    if type(saved) == "table" and type(saved.outfit) == "table" and #saved.outfit > 0 then return saved.outfit end
    local data = dataOf(member.shell)
    if data ~= nil and type(data.ProjectALifeClothingTypes) == "table" then
        local outfit = {}
        for index, itemType in ipairs(data.ProjectALifeClothingTypes) do
            local tints = type(data.ProjectALifeClothingTints) == "table" and data.ProjectALifeClothingTints or {}
            outfit[#outfit + 1] = { itemType = itemType, tint = tints[index] or "" }
        end
        return outfit
    end
    local hydrator = Crew.alife().hydrator
    if hydrator ~= nil and type(hydrator.plan) == "function" then
        local ok, plan = pcall(hydrator.plan, member.record)
        if ok and type(plan) == "table" and type(plan.clothing) == "table" then return plan.clothing end
    end
    return {}
end

--- Saves a crew member's new outfit and dresses the body in it with A-Life's own redress.
function Crew.dress(member, outfit)
    local saved = Crew.saved(member.record.uid, true)
    if saved == nil then return false end
    saved.outfit = outfit
    local hydrator = Crew.alife().hydrator
    if hydrator == nil or type(hydrator.redress) ~= "function" then return false end
    local ok, done = pcall(hydrator.redress, member.shell, outfit)
    return ok and done == true
end

--- Puts a piece of clothing on a crew member, replacing what they wear in that spot.
function Crew.wear(player, uid, itemType)
    local member, refusal = loadedMember(player, uid)
    if member == nil then return false, refusal end
    local info = Crew.itemInfo(itemType)
    if info == nil then return false, Rows.refusal("unknown_item", member.name, itemType) end
    if info.kind ~= "clothing" then return false, Rows.refusal("not_clothing", member.name, info.name) end
    local outfit = Rows.wearInto(Crew.outfitOf(member), info.type, info.location, Crew.locationOf)
    if not Crew.dress(member, outfit) then
        return true, member.name .. " will wear the " .. info.name .. " the next time they load in."
    end
    return true, member.name .. " is wearing the " .. info.name .. "."
end

--- Takes an item away from a crew member: worn clothing comes off, a held weapon is put away first.
function Crew.remove(player, uid, id)
    local member, refusal = loadedMember(player, uid)
    if member == nil then return false, refusal end
    local item = Crew.findItem(member.shell, id)
    if item == nil then return false, Rows.refusal("no_item", member.name) end
    local itemType, name = typeOf(item), nameOf(item)
    local data = dataOf(item) or {}
    if data.ProjectALifeAuthoredClothing == true then
        local outfit, found = Rows.takeOff(Crew.outfitOf(member), itemType)
        if found and #outfit == 0 then return false, Rows.refusal("last_piece", member.name) end
        if found and not Crew.dress(member, outfit) then
            return true, member.name .. " will take off the " .. name .. " the next time they load in."
        end
        return true, member.name .. " took off the " .. name .. "."
    end
    local inventory, items = Crew.carried(member.shell)
    if isWeapon(item) then
        if item == Crew.current(member.shell) then
            local weapons = Crew.alife().weapons
            pcall(weapons.select, member.shell, nil)
        end
        pcall(function() inventory:Remove(item) end)
        return true, "Took the " .. name .. " from " .. member.name .. "."
    end
    local removed = 0
    for _, other in ipairs(items) do
        local otherData = dataOf(other) or {}
        if typeOf(other) == itemType and not isWeapon(other) and otherData.ProjectALifeAuthoredClothing ~= true then
            if pcall(function() inventory:Remove(other) end) then removed = removed + 1 end
        end
    end
    return true, "Took " .. (removed > 1 and (removed .. " x ") or "the ") .. name .. " from " .. member.name .. "."
end

--- Adds spare rounds for the gun a crew member is holding.
function Crew.addAmmo(player, uid, rounds)
    local member, refusal = loadedMember(player, uid)
    if member == nil then return false, refusal end
    local current = Crew.current(member.shell)
    if current == nil or not Crew.isGun(current) then return false, Rows.refusal("no_gun", member.name) end
    local weapons = Crew.alife().weapons
    local slot = type(weapons.slot) == "function" and weapons.slot(current) or nil
    slot = slot == "secondary" and "secondary" or "primary"
    local wanted = math.max(1, math.min(Crew.ammoCap, math.floor(tonumber(rounds) or 0)))
    local ok, total = pcall(weapons.addReserve, member.shell, slot, wanted)
    if not ok then return false, Rows.refusal("not_saved") end
    return true, "Gave " .. member.name .. " " .. wanted .. " rounds; " .. tostring(total) .. " spare now."
end

--- Builds what the Crew tab shows about one crew member.
function Crew.describe(member)
    local saved = Crew.saved(member.record.uid, false) or {}
    local loaded = member.shell ~= nil
    return {
        uid = tostring(member.record.uid), name = member.name, loaded = loaded,
        skills = Crew.skillsOf(member.record), ratings = Crew.ratingsOf(member),
        weapon = loaded and Crew.weaponLine(member.shell) or nil,
        items = loaded and Crew.describeItems(member.shell) or {},
        outfitSaved = type(saved.outfit) == "table" and #saved.outfit > 0,
    }
end

--- Adds the Crew tab's data: everyone in the player's crew and the picked member's details.
function Crew.addTo(state, player, pickUid)
    state.crewMembers = {}
    local companions, key = People.crew(), People.crewKey(player)
    if companions == nil or key == nil or type(companions.roster) ~= "function" then return state end
    for _, uid in ipairs(companions.roster(key)) do
        local record = People.record(uid)
        if record ~= nil then state.crewMembers[#state.crewMembers + 1] = { uid = tostring(uid), name = Editor.nameOf(record) } end
    end
    table.sort(state.crewMembers, function(left, right) return string.lower(left.name) < string.lower(right.name) end)
    local pick = pickUid ~= nil and tostring(pickUid) or nil
    local found = false
    for _, entry in ipairs(state.crewMembers) do
        if entry.uid == pick then found = true end
    end
    if not found then pick = state.crewMembers[1] ~= nil and state.crewMembers[1].uid or nil end
    state.crewPick = pick
    if pick ~= nil then
        local member = Crew.member(player, pick)
        if member ~= nil then state.crewMember = Crew.describe(member) end
    end
    return state
end

return Crew
