local Mock = require("tests.mock.wow")

local ESCORT = 94556      -- Jom-jom's Escape (in the built-in list)
local TAGGED = 123456     -- not in the list; the game tags it as an escort
local NORMAL = 783        -- a normal quest

describe("escort guard", function()
    local m, ns

    before_each(function()
        m = Mock.new()
        m.titles[ESCORT] = "Jom-jom's Escape"
        m.tags[TAGGED] = 84
        m.tags[NORMAL] = 0
        ns = m.boot()
        m.clearOutput()
    end)

    describe("quest-giver window (AcceptQuest)", function()
        it("stops Questie from auto-accepting an escort on the list", function()
            m.accept(ESCORT, "questie")
            assert.are.equal(0, m.calls.AcceptQuest)
            assert.matches("stopped Questie from auto%-accepting the escort quest \"Jom%-jom's Escape\"", m.output())
        end)

        it("lets Questie auto-accept a normal quest", function()
            m.accept(NORMAL, "questie")
            assert.are.equal(1, m.calls.AcceptQuest)
            assert.are.equal("", m.output())
        end)

        it("stops an escort found only by the game's escort tag", function()
            m.accept(TAGGED, "questie")
            assert.are.equal(0, m.calls.AcceptQuest)
        end)

        it("always lets the player's own click on Blizzard's Accept button through", function()
            m.accept(ESCORT, "blizzardQuestFrame")
            assert.are.equal(1, m.calls.AcceptQuest)
        end)

        it("stops RXP Guides (old-style stack with backslashes)", function()
            m.accept(ESCORT, "rxpOldStyle")
            assert.are.equal(0, m.calls.AcceptQuest)
            assert.matches("stopped RXPGuides", m.output())
        end)

        it("lets a /run macro typed by the player through", function()
            m.accept(ESCORT, "runMacro")
            assert.are.equal(1, m.calls.AcceptQuest)
        end)

        it("does nothing when the quest dialog has no quest ID", function()
            m.accept(0, "questie")
            assert.are.equal(1, m.calls.AcceptQuest)
        end)
    end)

    describe("group escort popup (ConfirmAcceptQuest)", function()
        it("stops Questie from auto-joining an escort a group member started", function()
            m.fire("QUEST_ACCEPT_CONFIRM", "Bobby", "Jom-jom's Escape", ESCORT)
            m.confirm("questieConfirm")
            assert.are.equal(0, m.calls.ConfirmAcceptQuest)
            assert.matches("auto%-joining \"Jom%-jom's Escape\", an escort that Bobby started", m.output())
        end)

        it("lets the player click Yes in Blizzard's popup", function()
            m.fire("QUEST_ACCEPT_CONFIRM", "Bobby", "Jom-jom's Escape", ESCORT)
            m.confirm("blizzardPopup")
            assert.are.equal(1, m.calls.ConfirmAcceptQuest)
        end)

        it("stops an add-on that clicks Blizzard's popup button for you", function()
            m.fire("QUEST_ACCEPT_CONFIRM", "Bobby", "Jom-jom's Escape", ESCORT)
            m.confirm("autoQuestClicksPopup")
            assert.are.equal(0, m.calls.ConfirmAcceptQuest)
            assert.matches("stopped ForeverAutoQuest", m.output())
        end)

        it("guards every group escort popup, even for quests not on the list", function()
            m.fire("QUEST_ACCEPT_CONFIRM", "Bobby", "Some New Escort", 777777)
            m.confirm("questieConfirm")
            assert.are.equal(0, m.calls.ConfirmAcceptQuest)
        end)

        it("leaves ConfirmAcceptQuest alone when no escort popup is open (e.g. quest log full)", function()
            m.confirm("questieConfirm")
            assert.are.equal(1, m.calls.ConfirmAcceptQuest)
        end)

        it("stops guarding the popup after 60 seconds", function()
            m.fire("QUEST_ACCEPT_CONFIRM", "Bobby", "Jom-jom's Escape", ESCORT)
            m.t = m.t + 61
            m.confirm("questieConfirm")
            assert.are.equal(1, m.calls.ConfirmAcceptQuest)
        end)

        it("respects the allow list for group popups", function()
            ns.db.allow[ESCORT] = true
            m.fire("QUEST_ACCEPT_CONFIRM", "Bobby", "Jom-jom's Escape", ESCORT)
            m.confirm("questieConfirm")
            assert.are.equal(1, m.calls.ConfirmAcceptQuest)
        end)
    end)

    describe("settings", function()
        it("master switch off lets everything through", function()
            ns.db.enabled = false
            m.accept(ESCORT, "questie")
            assert.are.equal(1, m.calls.AcceptQuest)
        end)

        it("guardDialog off lets dialog auto-accepts through", function()
            ns.db.guardDialog = false
            m.accept(ESCORT, "questie")
            assert.are.equal(1, m.calls.AcceptQuest)
        end)

        it("guardGroup off lets popup auto-joins through", function()
            ns.db.guardGroup = false
            m.fire("QUEST_ACCEPT_CONFIRM", "Bobby", "Jom-jom's Escape", ESCORT)
            m.confirm("questieConfirm")
            assert.are.equal(1, m.calls.ConfirmAcceptQuest)
        end)

        it("groupOnly lets add-ons auto-accept escorts while solo", function()
            ns.db.groupOnly = true
            m.inGroup = false
            m.accept(ESCORT, "questie")
            assert.are.equal(1, m.calls.AcceptQuest)
            m.inGroup = true
            m.fire("QUEST_FINISHED")
            m.accept(ESCORT, "questie")
            assert.are.equal(1, m.calls.AcceptQuest)
        end)

        it("allow list wins over the built-in list", function()
            ns.db.allow[ESCORT] = true
            m.accept(ESCORT, "questie")
            assert.are.equal(1, m.calls.AcceptQuest)
        end)

        it("quests added by the player are guarded", function()
            ns.db.extra[NORMAL] = true
            m.accept(NORMAL, "questie")
            assert.are.equal(0, m.calls.AcceptQuest)
        end)

        it("notify off keeps chat quiet but still blocks", function()
            ns.db.notify = false
            m.accept(ESCORT, "questie")
            assert.are.equal(0, m.calls.AcceptQuest)
            assert.are.equal("", m.output())
        end)
    end)

    describe("quest UIs that replace Blizzard's window", function()
        it("a second click in the same dialog goes through", function()
            m.accept(ESCORT, "immersion")
            assert.are.equal(0, m.calls.AcceptQuest)
            m.t = m.t + 1.2
            m.accept(ESCORT, "immersion")
            assert.are.equal(1, m.calls.AcceptQuest)
        end)

        it("a repeat in the same instant is still blocked (not a person)", function()
            m.accept(ESCORT, "questie")
            m.accept(ESCORT, "questie")
            assert.are.equal(0, m.calls.AcceptQuest)
        end)

        it("re-opening the dialog starts over, so the auto-accepter is blocked again", function()
            m.accept(ESCORT, "questie")
            m.fire("QUEST_FINISHED")
            m.t = m.t + 5
            m.accept(ESCORT, "questie")
            assert.are.equal(0, m.calls.AcceptQuest)
        end)
    end)

    describe("chat messages", function()
        it("says it once per dialog, and the retry hint once per session", function()
            m.accept(ESCORT, "questie")
            m.accept(ESCORT, "questie")
            local _, n = m.output():gsub("stopped Questie", "")
            assert.are.equal(1, n)
            local _, hints = m.output():gsub("Click it once more", "")
            assert.are.equal(1, hints)
            m.fire("QUEST_FINISHED")
            m.accept(ESCORT, "questie")
            _, hints = m.output():gsub("Click it once more", "")
            assert.are.equal(1, hints)
        end)

        it("records blocks for the bug report", function()
            m.accept(ESCORT, "questie")
            local last = ns.db.log[#ns.db.log]
            assert.are.equal("accept", last.kind)
            assert.are.equal(ESCORT, last.q)
            assert.are.equal("Questie", last.a)
        end)

        it("keeps only the last 10 blocks", function()
            for _ = 1, 15 do
                m.fire("QUEST_FINISHED")
                m.accept(ESCORT, "questie")
            end
            assert.are.equal(10, #ns.db.log)
        end)
    end)

    describe("failing safe", function()
        it("an error in the tag lookup does not block normal quests", function()
            m.tagError = true
            m.accept(NORMAL, "questie")
            assert.are.equal(1, m.calls.AcceptQuest)
        end)

        it("a broken guard lets the call through and records the error", function()
            ns.Decide = function() error("guard exploded") end
            m.accept(ESCORT, "questie")
            assert.are.equal(1, m.calls.AcceptQuest)
            assert.are.equal(1, #ns.db.errors)
            assert.matches("guard exploded", ns.db.errors[1].msg)
        end)

        it("the same error is counted, not repeated", function()
            ns.Decide = function() error("guard exploded") end
            m.accept(ESCORT, "questie")
            m.accept(ESCORT, "questie")
            assert.are.equal(1, #ns.db.errors)
            assert.are.equal(2, ns.db.errors[1].count)
        end)

        it("a secret escort tag is treated as unknown, without errors", function()
            m.tags[TAGGED] = { __secret = true }
            m.accept(TAGGED, "questie")
            assert.are.equal(1, m.calls.AcceptQuest)
            assert.are.equal(0, #ns.db.errors)
        end)
    end)

    describe("loading", function()
        it("wraps both functions when the file loads", function()
            assert.is_true(ns.installed)
            assert.is_true(m.env.AcceptQuest ~= ns.original.AcceptQuest)
            assert.is_true(m.env.ConfirmAcceptQuest ~= ns.original.ConfirmAcceptQuest)
        end)

        it("chains to another add-on's replacement made before us", function()
            local m2 = Mock.new()
            local theirs = 0
            m2.env.AcceptQuest = function() theirs = theirs + 1 end
            m2.boot()
            m2.accept(NORMAL, "questie")
            assert.are.equal(1, theirs)
        end)

        it("keeps saved settings and fills in missing ones", function()
            local m2 = Mock.new({ saved = { enabled = false, allow = { [5] = true }, firstRunDone = true } })
            local ns2 = m2.boot()
            assert.is_false(ns2.db.enabled)
            assert.is_true(ns2.db.allow[5])
            assert.is_true(ns2.db.guardGroup)
            assert.are.equal(ns2.db, m2.env.AnvilEscortGuardDB)
            assert.are.equal("", m2.output())
        end)

        it("repairs saved settings of the wrong type", function()
            local m2 = Mock.new({ saved = { allow = "oops", notify = "yes" } })
            local ns2 = m2.boot()
            assert.are.equal("table", type(ns2.db.allow))
            assert.is_true(ns2.db.notify)
        end)

        it("shows the first-run message once", function()
            local m2 = Mock.new()
            local ns2 = m2.boot()
            assert.matches("%(beta%) is on%. Add%-ons can no longer start escort quests", m2.output())
            assert.is_true(ns2.db.firstRunDone)
        end)

        it("creates only the expected globals", function()
            local allowed = {
                AnvilEscortGuardDB = true,
                SLASH_ANVILESCORTGUARD1 = true,
                SLASH_ANVILESCORTGUARD2 = true,
            }
            for name in pairs(m.newGlobals) do
                assert.is_true(allowed[name] == true)
            end
        end)

        it("registers no per-frame work (no OnUpdate)", function()
            for _, f in ipairs(m.frames) do
                assert.is_nil(f.scripts.OnUpdate)
            end
        end)
    end)

    describe("call-stack reading", function()
        it("classifies the sample stacks", function()
            assert.are.equal("blizzard", (ns.ClassifyStack(Mock.stacks.blizzardQuestFrame)))
            assert.are.equal("blizzard", (ns.ClassifyStack(Mock.stacks.blizzardPopup)))
            assert.are.equal("blizzard", (ns.ClassifyStack(Mock.stacks.chatSlash)))
            assert.are.equal("unknown", (ns.ClassifyStack(Mock.stacks.runMacro)))
            local origin, name = ns.ClassifyStack(Mock.stacks.autoQuestClicksPopup)
            assert.are.equal("addon", origin)
            assert.are.equal("ForeverAutoQuest", name)
            assert.are.equal("unknown", (ns.ClassifyStack(nil)))
        end)

        it("handles lower-case paths and FrameXML", function()
            assert.are.equal("addon", (ns.ClassifyStack("interface/addons/SomeAddon/x.lua:1: in main chunk")))
            assert.are.equal("blizzard", (ns.ClassifyStack("Interface/FrameXML/QuestFrame.lua:10: in function")))
        end)
    end)
end)
