--- Pure check for who may use the editor: anyone in single player, staff in
--- multiplayer, or everyone when the server's sandbox option allows it.
ALifeRepEditor = ALifeRepEditor or {}

local Permissions = {}
ALifeRepEditor.Permissions = Permissions

Permissions.NOT_STAFF = { [""] = true, none = true, player = true, user = true }

--- Returns true when an access level or role name belongs to server staff.
function Permissions.isStaff(accessLevel)
    if type(accessLevel) ~= "string" then return false end
    return Permissions.NOT_STAFF[string.lower(accessLevel)] ~= true
end

--- Returns true when this player may change reputation.
function Permissions.allowed(context)
    if type(context) ~= "table" then return false end
    if context.multiplayer ~= true then return true end
    if context.allowEveryone == true then return true end
    return Permissions.isStaff(context.accessLevel)
end

return Permissions
