--- Sends window commands to the editor and hands the reply back. In single
--- player the server code runs in the same Lua state, so it is called
--- directly; in multiplayer it goes through client and server commands.
ALifeRepEditor = ALifeRepEditor or {}

local Transport = { MODULE = "ALifeRepEditor", listeners = {}, last = nil }
ALifeRepEditor.Transport = Transport

--- Returns true when this game is a multiplayer client.
function Transport.multiplayer()
    return type(isClient) == "function" and isClient() == true
end

--- Registers a function to call with every fresh state from the server.
function Transport.listen(listener)
    Transport.listeners[#Transport.listeners + 1] = listener
end

--- Delivers a state to every listener.
function Transport.receive(state)
    Transport.last = state
    for _, listener in ipairs(Transport.listeners) do listener(state) end
end

--- Sends one command for the local player.
function Transport.send(command, args)
    local player = getPlayer()
    if player == nil then return false end
    if Transport.multiplayer() then
        sendClientCommand(player, Transport.MODULE, command, args or {})
        return true
    end
    local hooks = ALifeRepEditor.Hooks
    if hooks == nil then
        Transport.receive({ ok = false, failed = true, message = "The editor's server part did not load; see console.txt." })
        return false
    end
    Transport.receive(hooks.handle(player, command, args or {}))
    return true
end

--- Picks up replies from a multiplayer server.
function Transport.onServerCommand(module, command, args)
    if module ~= Transport.MODULE or command ~= "state" then return end
    Transport.receive(args)
end

if type(Events) == "table" and Events.OnServerCommand ~= nil then
    Events.OnServerCommand.Add(Transport.onServerCommand)
end

return Transport
