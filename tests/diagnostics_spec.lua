local Mock = require("tests.mock.wow")

describe("bug report", function()
    local m, ns

    before_each(function()
        m = Mock.new()
        ns = m.boot()
        m.clearOutput()
    end)

    it("has version, game build, interface, locale and settings", function()
        local text = ns.BuildDiagnostics()
        assert.matches("addon=AnvilEscortGuard v0%.1%.0%-test", text)
        assert.matches("game=1%.60%.1 %(70959%)", text)
        assert.matches("iface=16001", text)
        assert.matches("locale=enUS", text)
        assert.matches("settings: enabled=on dialog=on group=on groupOnly=off notify=on allowed=0 added=0", text)
        assert.matches("wrapped: AcceptQuest=on ConfirmAcceptQuest=on", text)
        assert.matches("errors: none", text)
        assert.matches("recent: none", text)
    end)

    it("lists other loaded add-ons with versions, but not Blizzard's or ours", function()
        local text = ns.BuildDiagnostics()
        assert.matches("addons: Questie 12%.10%.0, RXPGuides 4%.9%.1", text)
        assert.is_falsy(text:find("Blizzard_WorldMap", 1, true))
        assert.is_falsy(text:find("addons:.-AnvilEscortGuard"))
    end)

    it("contains no character name or realm", function()
        m.accept(94556, "questie")
        local text = ns.BuildDiagnostics()
        assert.is_falsy(text:find("Secretcharname", 1, true))
        assert.is_falsy(text:find("Secretrealm", 1, true))
    end)

    it("shows recent blocks and errors with a stable signature", function()
        m.accept(94556, "questie")
        ns.RecordError("Interface/AddOns/AnvilEscortGuard/Core.lua:12: something broke")
        local text = ns.BuildDiagnostics()
        assert.matches("recent: %d%d%d%d%-%d%d%-%d%d %d%d:%d%d UTC accept q=94556 by=Questie", text)
        local sig = ns.Hash("something broke")
        assert.matches("sig=" .. sig, text)
        assert.matches("error " .. sig .. " x1: ", text)
    end)

    it("signature ignores the file and line, so the same bug matches across versions", function()
        ns.RecordError("Interface/AddOns/AnvilEscortGuard/Core.lua:12: same")
        ns.RecordError("Interface/AddOns/AnvilEscortGuard/Core.lua:99: same")
        assert.are.equal(1, #ns.db.errors)
        assert.are.equal(2, ns.db.errors[1].count)
    end)

    it("hash is a stable 8-digit hex string", function()
        assert.are.equal(ns.Hash("abc"), ns.Hash("abc"))
        assert.matches("^%x%x%x%x%x%x%x%x$", ns.Hash("abc"))
        assert.is_true(ns.Hash("abc") ~= ns.Hash("abd"))
    end)

    it("caps the add-on list at 40 names", function()
        for i = 1, 60 do m.addons[#m.addons + 1] = { name = "Addon" .. i, version = "1" } end
        local text = ns.BuildDiagnostics()
        assert.matches("%+22 more", text)
    end)

    it("/aeg bug opens a window with the report selected and the link", function()
        m.slash("bug")
        local f = ns.bugFrame
        assert.is_not_nil(f)
        assert.is_true(f.shown)
        assert.matches("addon=AnvilEscortGuard", f.edit.text)
        assert.are.equal("https://github.com/anvil-forever/AnvilEscortGuard/issues/new/choose", f.url.text)
    end)

    it("the report box cannot be edited by typing", function()
        m.slash("bug")
        local edit = ns.bugFrame.edit
        local original = edit.text
        edit.text = "typed over"
        edit.scripts.OnTextChanged(edit, true)
        assert.are.equal(original, edit.text)
    end)

    it("falls back to chat if the window cannot be created", function()
        m.createFrameError = true
        m.slash("bug")
        assert.matches("could not open the report window", m.output())
        assert.matches("addon=AnvilEscortGuard", m.output())
    end)
end)
