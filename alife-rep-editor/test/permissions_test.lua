require "ALifeRepEditor/permissions"
local Permissions = ALifeRepEditor.Permissions

test("single player is always allowed", function()
    ok(Permissions.allowed({ multiplayer = false }))
end)

test("multiplayer allows staff only unless everyone is allowed", function()
    ok(Permissions.allowed({ multiplayer = true, accessLevel = "admin" }))
    ok(Permissions.allowed({ multiplayer = true, accessLevel = "Moderator" }))
    ok(not Permissions.allowed({ multiplayer = true, accessLevel = "None" }))
    ok(not Permissions.allowed({ multiplayer = true }))
    ok(Permissions.allowed({ multiplayer = true, accessLevel = "None", allowEveryone = true }))
    ok(not Permissions.allowed(nil))
end)
