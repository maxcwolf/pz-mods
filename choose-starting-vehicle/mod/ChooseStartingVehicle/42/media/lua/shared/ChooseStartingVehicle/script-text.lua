--- Parses Project Zomboid script text ("vehicle X { key = value, part Y { ... } }")
--- into a tree of blocks and properties that keeps source order. Pure Lua with
--- no game globals, so it runs in the test harness and in Kahlua.
local ScriptText = {}

--- Removes leading and trailing whitespace.
function ScriptText.trim(text)
    return (string.match(text or "", "^%s*(.-)%s*$"))
end

--- Removes /* block */ and // line comments.
function ScriptText.stripComments(text)
    local out = {}
    local pos = 1
    while true do
        local s = string.find(text, "/*", pos, true)
        if not s then
            out[#out + 1] = string.sub(text, pos)
            break
        end
        out[#out + 1] = string.sub(text, pos, s - 1)
        local e = string.find(text, "*/", s + 2, true)
        if not e then
            break
        end
        pos = e + 2
    end
    return (string.gsub(table.concat(out), "//[^\n]*", ""))
end

--- Splits text on runs of whitespace.
function ScriptText.words(text)
    local words = {}
    for word in string.gmatch(text or "", "%S+") do
        words[#words + 1] = word
    end
    return words
end

--- Creates a block node from its header text ("template vehicle Name").
local function newBlock(header)
    local words = ScriptText.words(header)
    local name = nil
    if #words > 1 then
        name = words[#words]
    end
    return { header = header, kind = words[1] and string.lower(words[1]) or "", name = name, words = words, items = {} }
end

--- Adds a "key = value" line to a block when the text holds one.
local function addProperty(block, text)
    local eq = string.find(text, "=", 1, true)
    if not eq then
        return false
    end
    local key = ScriptText.trim(string.sub(text, 1, eq - 1))
    if key == "" then
        return false
    end
    block.items[#block.items + 1] = { key = key, value = ScriptText.trim(string.sub(text, eq + 1)) }
    return true
end

--- Parses script text into a root block whose items are properties
--- ({key, value}) and child blocks ({block}).
function ScriptText.parse(text)
    text = ScriptText.stripComments(text or "")
    local root = newBlock("root")
    local stack = { root }
    local pending = ""
    local pos = 1
    local len = #text
    while pos <= len do
        local s = string.find(text, "[{},\r\n]", pos)
        local chunk = string.sub(text, pos, (s or (len + 1)) - 1)
        local ch = s and string.sub(text, s, s) or ""
        local current = stack[#stack]
        if ch == "{" then
            local block = newBlock(ScriptText.trim(pending .. " " .. chunk))
            current.items[#current.items + 1] = { block = block }
            stack[#stack + 1] = block
            pending = ""
        else
            local line = ScriptText.trim(chunk)
            if string.find(line, "=", 1, true) then
                addProperty(current, line)
                pending = ""
            elseif line ~= "" then
                pending = line
            end
            if ch == "}" then
                pending = ""
                if #stack > 1 then
                    stack[#stack] = nil
                end
            end
        end
        if not s then
            break
        end
        pos = s + 1
    end
    return root
end

--- Returns the child blocks of `block` whose kind matches.
function ScriptText.childBlocks(block, kind)
    local found = {}
    for _, item in ipairs(block.items) do
        if item.block and (not kind or item.block.kind == kind) then
            found[#found + 1] = item.block
        end
    end
    return found
end

--- Returns the first block of a kind anywhere under `block`, depth first.
function ScriptText.findBlock(block, kind)
    for _, item in ipairs(block.items) do
        if item.block then
            if item.block.kind == kind then
                return item.block
            end
            local inner = ScriptText.findBlock(item.block, kind)
            if inner then
                return inner
            end
        end
    end
    return nil
end

--- Returns the value of the last property named `key` directly in `block`.
function ScriptText.property(block, key)
    local value = nil
    for _, item in ipairs(block.items) do
        if item.key == key then
            value = item.value
        end
    end
    return value
end

return ScriptText
