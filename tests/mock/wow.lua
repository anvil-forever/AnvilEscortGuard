-- Minimal mock of the WoW API surface Anvil Escort Guard uses.
-- Each test boots a fresh sandbox: the add-on's files run in their own global table
-- (like the game), so tests can inspect globals the add-on sets or replaces.

local M = {}

M.ADDON = "AnvilEscortGuard"
M.ROOT = (os.getenv("AEG_ROOT") or ".")

-- Call stacks in the format WoW's debugstack() produces (both old and new styles).
M.stacks = {
    blizzardQuestFrame = table.concat({
        "Interface/AddOns/AnvilEscortGuard/Core.lua:231: in function 'AcceptQuest'",
        "Interface/AddOns/Blizzard_UIPanels_Game/Mainline/QuestFrame.lua:646: in function 'QuestDetailAcceptButton_OnClick'",
        "[string \"*QuestFrame.xml:740_OnClick\"]:1: in function <[string \"*QuestFrame.xml:740_OnClick\"]:1>",
    }, "\n"),
    blizzardPopup = table.concat({
        "Interface/AddOns/AnvilEscortGuard/Core.lua:238: in function 'ConfirmAcceptQuest'",
        "Interface/AddOns/Blizzard_StaticPopup_Game/GameDialogDefs.lua:1622: in function 'OnAccept'",
        "Interface/AddOns/Blizzard_StaticPopup/StaticPopup.lua:410: in function 'StaticPopup_OnClick'",
        "[C]: in function 'Click'",
    }, "\n"),
    questie = table.concat({
        "Interface/AddOns/AnvilEscortGuard/Core.lua:231: in function 'AcceptQuest'",
        "Interface/AddOns/Questie/Modules/Auto/AutoQuesting.lua:51: in function 'OnQuestDetail'",
        "Interface/AddOns/Questie/Modules/EventHandler/EventHandler.lua:168: in function <Interface/AddOns/Questie/Modules/EventHandler/EventHandler.lua:167>",
    }, "\n"),
    questieConfirm = table.concat({
        "Interface/AddOns/AnvilEscortGuard/Core.lua:238: in function 'ConfirmAcceptQuest'",
        "Interface/AddOns/Questie/Modules/EventHandler/EventHandler.lua:187: in function <Interface/AddOns/Questie/Modules/EventHandler/EventHandler.lua:183>",
    }, "\n"),
    -- Old style: [string "@Interface\AddOns\..."] with backslashes
    rxpOldStyle = table.concat({
        "[string \"@Interface\\AddOns\\AnvilEscortGuard\\Core.lua\"]:231: in function `AcceptQuest'",
        "[string \"@Interface\\AddOns\\RXPGuides\\RXPGuides.lua\"]:1199: in function <...>",
    }, "\n"),
    -- An add-on that clicks Blizzard's popup button for you
    autoQuestClicksPopup = table.concat({
        "Interface/AddOns/AnvilEscortGuard/Core.lua:238: in function 'ConfirmAcceptQuest'",
        "Interface/AddOns/Blizzard_StaticPopup_Game/GameDialogDefs.lua:1622: in function 'OnAccept'",
        "Interface/AddOns/Blizzard_StaticPopup/StaticPopup.lua:410: in function 'StaticPopup_OnClick'",
        "[C]: in function 'Click'",
        "Interface/AddOns/ForeverAutoQuest/Core.lua:88: in function <Interface/AddOns/ForeverAutoQuest/Core.lua:80>",
    }, "\n"),
    immersion = table.concat({
        "Interface/AddOns/AnvilEscortGuard/Core.lua:231: in function 'AcceptQuest'",
        "Interface/AddOns/Immersion/Buttons.lua:40: in function <Interface/AddOns/Immersion/Buttons.lua:38>",
    }, "\n"),
    runMacro = table.concat({
        "Interface/AddOns/AnvilEscortGuard/Core.lua:231: in function 'AcceptQuest'",
        "[string \"AcceptQuest()\"]:1: in main chunk",
    }, "\n"),
    chatSlash = table.concat({
        "Interface/AddOns/AnvilEscortGuard/UI.lua:200: in function 'SelfTest'",
        "Interface/AddOns/AnvilEscortGuard/UI.lua:300: in function <Interface/AddOns/AnvilEscortGuard/UI.lua:298>",
        "Interface/AddOns/Blizzard_ChatFrameBase/Mainline/ChatFrame.lua:2500: in function 'ChatEdit_ParseText'",
    }, "\n"),
}

local function newFrame(m, kind, name)
    local f = { kind = kind, name = name, events = {}, scripts = {}, shown = false, text = "" }
    local methods = {}
    function methods.RegisterEvent(self, e) self.events[e] = true end
    function methods.UnregisterEvent(self, e) self.events[e] = nil end
    function methods.SetScript(self, k, fn) self.scripts[k] = fn end
    function methods.GetScript(self, k) return self.scripts[k] end
    function methods.Show(self) self.shown = true end
    function methods.Hide(self) self.shown = false end
    function methods.IsShown(self) return self.shown end
    function methods.SetText(self, t) self.text = t end
    function methods.GetText(self) return self.text end
    function methods.CreateFontString() return newFrame(m, "FontString") end
    function methods.CreateTexture() return newFrame(m, "Texture") end
    return setmetatable(f, {
        __index = function(_, k)
            return methods[k] or function() end
        end,
    })
end

local function loadInEnv(path, env)
    if setfenv then -- Lua 5.1 / LuaJIT (what WoW and busted on CI use)
        local chunk, err = loadfile(path)
        if not chunk then return nil, err end
        setfenv(chunk, env)
        return chunk
    end
    return loadfile(path, "t", env) -- Lua 5.2+ (e.g. `pandoc lua`)
end

function M.tocFiles(root)
    local files = {}
    local fh = assert(io.open(root .. "/" .. M.ADDON .. ".toc", "r"))
    for line in fh:lines() do
        line = line:gsub("\r$", "")
        if line ~= "" and not line:find("^#") then files[#files + 1] = line end
    end
    fh:close()
    return files
end

-- opts.saved: SavedVariables table to start from
-- opts.settings: true to provide a fake Settings API
function M.new(opts)
    opts = opts or {}
    local m = {
        t = 100, wall = 1763470000, questID = 0, stack = "", printed = {},
        calls = { AcceptQuest = 0, ConfirmAcceptQuest = 0 },
        tags = {}, titles = {}, frames = {}, newGlobals = {}, inGroup = true,
        settings = {},
        addons = {
            { name = "AnvilEscortGuard", version = "0.1.0-test" },
            { name = "Questie", version = "12.10.0" },
            { name = "RXPGuides", version = "4.9.1" },
            { name = "Blizzard_WorldMap", version = nil },
        },
    }
    local env = {}
    setmetatable(env, {
        __index = _G,
        __newindex = function(t, k, v)
            m.newGlobals[k] = true
            rawset(t, k, v)
        end,
    })
    rawset(env, "_G", env)

    rawset(env, "GetTime", function() return m.t end)
    rawset(env, "time", function() return m.wall end)
    rawset(env, "date", os.date)
    rawset(env, "GetQuestID", function() return m.questID end)
    rawset(env, "GetTitleText", function() return m.titles[m.questID] or "" end)
    rawset(env, "C_QuestLog", {
        GetQuestTagInfo = function(id)
            if m.tagError then error("tag lookup failed") end
            local tag = m.tags[id]
            if tag ~= nil then return { tagID = tag, tagName = "Escort" } end
            return nil
        end,
        GetTitleForQuestID = function(id) return m.titles[id] end,
    })
    rawset(env, "issecretvalue", function(v) return type(v) == "table" and v.__secret == true end)
    rawset(env, "debugstack", function() return m.stack end)
    rawset(env, "IsInGroup", function() return m.inGroup end)
    rawset(env, "print", function(...)
        local parts = {}
        for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
        m.printed[#m.printed + 1] = table.concat(parts, " ")
    end)
    rawset(env, "AcceptQuest", function() m.calls.AcceptQuest = m.calls.AcceptQuest + 1 end)
    rawset(env, "ConfirmAcceptQuest", function() m.calls.ConfirmAcceptQuest = m.calls.ConfirmAcceptQuest + 1 end)
    rawset(env, "GetBuildInfo", function() return "1.60.1", "70959", "Nov 1 2026", 16001 end)
    rawset(env, "GetLocale", function() return "enUS" end)
    rawset(env, "UnitName", function() return "Secretcharname" end)
    rawset(env, "GetRealmName", function() return "Secretrealm" end)
    rawset(env, "C_AddOns", {
        GetNumAddOns = function() return #m.addons end,
        GetAddOnInfo = function(i) return m.addons[i].name end,
        IsAddOnLoaded = function(i) return true end,
        GetAddOnMetadata = function(name, key)
            if key ~= "Version" then return nil end
            for _, a in ipairs(m.addons) do if a.name == name then return a.version end end
            return nil
        end,
    })
    rawset(env, "SlashCmdList", {})
    rawset(env, "UISpecialFrames", {})
    rawset(env, "UIParent", newFrame(m, "Frame", "UIParent"))
    rawset(env, "ChatFontNormal", {})
    rawset(env, "CreateFrame", function(kind, name, parent, template)
        if m.createFrameError then error("CreateFrame failed") end
        local f = newFrame(m, kind, name)
        m.frames[#m.frames + 1] = f
        return f
    end)
    if opts.settings then
        local category = { GetID = function() return 42 end }
        rawset(env, "Settings", {
            RegisterVerticalLayoutCategory = function(name) m.settings.name = name; return category end,
            RegisterAddOnSetting = function(cat, variable, key, tbl, vtype, label, default)
                m.settings[key] = { variable = variable, tbl = tbl, vtype = vtype, label = label, default = default }
                return { key = key }
            end,
            CreateCheckbox = function(cat, setting, tip) m.settings[setting.key].tip = tip end,
            RegisterAddOnCategory = function(cat) m.settings.registered = true end,
            OpenToCategory = function(id) m.settings.opened = id end,
        })
    end
    if opts.saved then rawset(env, "AnvilEscortGuardDB", opts.saved) end

    m.env = env

    function m.fire(event, ...)
        for _, f in ipairs(m.frames) do
            if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
        end
    end

    function m.load(root)
        root = root or M.ROOT
        local ns = {}
        for _, file in ipairs(M.tocFiles(root)) do
            local chunk = assert(loadInEnv(root .. "/" .. file, env))
            chunk(M.ADDON, ns)
        end
        m.ns = ns
        return ns
    end

    -- Load files, then the game's start-up events.
    function m.boot(root)
        local ns = m.load(root)
        m.fire("ADDON_LOADED", "Blizzard_Something")
        m.fire("ADDON_LOADED", M.ADDON)
        m.fire("PLAYER_LOGIN")
        return ns
    end

    function m.slash(msg) env.SlashCmdList.ANVILESCORTGUARD(msg) end

    function m.output() return table.concat(m.printed, "\n") end

    function m.clearOutput() m.printed = {} end

    -- Simulate an add-on (or Blizzard) calling AcceptQuest in a quest dialog.
    function m.accept(questID, stack)
        m.questID = questID
        m.stack = M.stacks[stack] or stack
        env.AcceptQuest()
    end

    function m.confirm(stack)
        m.stack = M.stacks[stack] or stack
        env.ConfirmAcceptQuest()
    end

    return m
end

return M
