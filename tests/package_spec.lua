local Check = require("tools.check_package")

describe("package", function()
    it("passes the package check (TOC, LICENSE, changelog, .pkgmeta)", function()
        local problems = Check.check(".")
        assert.are.equal("", table.concat(problems, "; "))
    end)

    it("every Lua file the add-on ships is listed in the TOC", function()
        local Mock = require("tests.mock.wow")
        local listed = {}
        for _, f in ipairs(Mock.tocFiles(".")) do listed[f] = true end
        for _, f in ipairs({ "EscortIDs.lua", "Core.lua", "UI.lua" }) do
            assert.is_true(listed[f] == true)
        end
    end)

    it("the built-in escort list holds only positive whole quest IDs", function()
        local ns = {}
        local chunk = assert(loadfile("EscortIDs.lua"))
        chunk("AnvilEscortGuard", ns)
        local n = 0
        for id, v in pairs(ns.EscortIDs) do
            n = n + 1
            assert.are.equal("number", type(id))
            assert.is_true(id > 0 and id == math.floor(id))
            assert.is_true(v)
        end
        assert.is_true(n >= 60)
    end)
end)
