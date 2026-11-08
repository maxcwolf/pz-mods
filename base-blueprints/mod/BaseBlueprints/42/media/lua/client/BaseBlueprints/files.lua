--- Reads and writes text files in ~/Zomboid/Lua, which every save can see.
local Files = {}

--- Returns a file's lines, or nil when it does not exist or is empty.
function Files.readLines(name)
    local reader = getFileReader(name, false)
    if not reader then
        return nil
    end
    local lines = {}
    local line = reader:readLine()
    while line ~= nil do
        lines[#lines + 1] = line
        line = reader:readLine()
    end
    reader:close()
    if #lines == 0 then
        return nil
    end
    return lines
end

--- Replaces a file's contents with lines.
function Files.writeLines(name, lines)
    local writer = getFileWriter(name, true, false)
    if not writer then
        return false
    end
    for _, line in ipairs(lines) do
        writer:write(line .. "\n")
    end
    writer:close()
    return true
end

return Files
