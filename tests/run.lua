-- Run all specs without busted:   lua tests/run.lua      (or: pandoc lua tests/run.lua)
-- Run from the add-on's root folder. With busted installed, just run: busted
package.path = "./?.lua;" .. package.path
unpack = unpack or table.unpack -- luacheck: ignore

local R = require("tests.minibusted")
R.install()

local specs = {
    "tests/guard_spec.lua",
    "tests/slash_spec.lua",
    "tests/diagnostics_spec.lua",
    "tests/package_spec.lua",
}
for _, file in ipairs(specs) do
    local chunk = assert(loadfile(file))
    chunk()
end

local ok = R.run()
os.exit(ok and 0 or 1)
