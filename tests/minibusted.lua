-- A tiny stand-in for busted, so the specs run with any Lua (5.1, LuaJIT, 5.4,
-- or `pandoc lua`) when busted is not installed. It supports only what our specs use:
-- describe, it, before_each, and the luassert calls listed below.
-- On CI the same spec files run under real busted.

local R = { passed = 0, failed = 0, failures = {} }
local stack = {}

local function fmt(v)
    if type(v) == "string" then return string.format("%q", v) end
    return tostring(v)
end

local function deepEqual(a, b)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for k, v in pairs(a) do if not deepEqual(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

local function fail(msg) error({ assertion = msg }, 3) end

local nativeAssert = assert
local A = setmetatable({}, { __call = function(_, ...) return nativeAssert(...) end })
A.are = {
    equal = function(e, a) if e ~= a then fail("expected " .. fmt(e) .. ", got " .. fmt(a)) end end,
    same = function(e, a) if not deepEqual(e, a) then fail("tables differ") end end,
}
A.is_true = function(v) if v ~= true then fail("expected true, got " .. fmt(v)) end end
A.is_false = function(v) if v ~= false then fail("expected false, got " .. fmt(v)) end end
A.is_nil = function(v) if v ~= nil then fail("expected nil, got " .. fmt(v)) end end
A.is_not_nil = function(v) if v == nil then fail("expected a value, got nil") end end
A.is_truthy = function(v) if not v then fail("expected truthy, got " .. fmt(v)) end end
A.is_falsy = function(v) if v then fail("expected falsy, got " .. fmt(v)) end end
A.matches = function(p, s)
    if type(s) ~= "string" or not s:find(p) then fail("expected " .. fmt(s) .. " to match " .. fmt(p)) end
end
A.has_no = { errors = function(fn) local ok, err = pcall(fn); if not ok then fail("unexpected error: " .. tostring(err)) end end }
A.has_error = function(fn) if pcall(fn) then fail("expected an error") end end

local root = { name = "", children = {}, before = {} }
local current = root

local function describe(name, fn)
    local node = { name = name, children = {}, before = {}, parent = current }
    table.insert(current.children, node)
    local prev = current
    current = node
    fn()
    current = prev
end

local function it(name, fn)
    table.insert(current.children, { name = name, test = fn, parent = current })
end

local function before_each(fn) table.insert(current.before, fn) end

local function fullName(node)
    local parts = {}
    while node and node.name ~= "" do table.insert(parts, 1, node.name); node = node.parent end
    return table.concat(parts, " > ")
end

local function runNode(node, befores)
    local all = {}
    for _, b in ipairs(befores) do all[#all + 1] = b end
    for _, b in ipairs(node.before or {}) do all[#all + 1] = b end
    for _, child in ipairs(node.children) do
        if child.test then
            local ok, err = pcall(function()
                for _, b in ipairs(all) do b() end
                child.test()
            end)
            if ok then
                R.passed = R.passed + 1
            else
                R.failed = R.failed + 1
                local msg = type(err) == "table" and err.assertion or tostring(err)
                R.failures[#R.failures + 1] = fullName(child) .. "\n    " .. msg
            end
        else
            runNode(child, all)
        end
    end
end

function R.install()
    _G.describe, _G.it, _G.before_each, _G.assert = describe, it, before_each, A
end

function R.run()
    runNode(root, {})
    for _, f in ipairs(R.failures) do print("FAIL " .. f) end
    print(("%d passed, %d failed"):format(R.passed, R.failed))
    return R.failed == 0
end

return R
