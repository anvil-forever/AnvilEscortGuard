-- Anvil Escort Guard
-- Copyright (C) 2026 Anvil Forever
-- SPDX-License-Identifier: GPL-3.0-or-later
--
-- Slash command, settings panel, bug report window and self-test.
-- Nothing here runs until the player uses it (the bug window is created on first use).

local ADDON, ns = ...

local function onoff(v) return v and "on" or "off" end

local function count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

local function sortedKeys(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys)
    return keys
end

---------------------------------------------------------------------------
-- Settings panel (Blizzard's Settings window is searchable)
---------------------------------------------------------------------------
ns.SETTINGS = {
    { key = "enabled", label = "Enable Anvil Escort Guard",
      tip = "Stop other add-ons from starting escort quests for you. You can still accept them yourself." },
    { key = "guardDialog", label = "Guard the quest-giver window",
      tip = "Stop add-ons from auto-accepting an escort quest when you talk to the quest giver." },
    { key = "guardGroup", label = "Guard group escort popups",
      tip = "Stop add-ons from auto-joining an escort that a group member started. You can still click Yes." },
    { key = "groupOnly", label = "Only while in a group",
      tip = "Let add-ons auto-accept escorts when you play alone." },
    { key = "notify", label = "Chat message when something is stopped",
      tip = "One short line in chat each time the guard steps in." },
}

function ns.RegisterSettings()
    if ns.settingsCategory then return true end
    if not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnSetting
            and Settings.CreateCheckbox and Settings.RegisterAddOnCategory) then
        return false
    end
    local category = Settings.RegisterVerticalLayoutCategory(ns.NAME)
    for _, s in ipairs(ns.SETTINGS) do
        local setting = Settings.RegisterAddOnSetting(category, ADDON .. "_" .. s.key, s.key, ns.db,
            "boolean", s.label, ns.defaults[s.key])
        Settings.CreateCheckbox(category, setting, s.tip)
    end
    Settings.RegisterAddOnCategory(category)
    ns.settingsCategory = category
    return true
end

function ns.OpenSettings()
    if ns.settingsCategory and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(ns.settingsCategory:GetID())
        return true
    end
    return false
end

---------------------------------------------------------------------------
-- Bug report: copyable text (add-ons cannot send anything over the network)
---------------------------------------------------------------------------
local function otherAddons()
    local api = C_AddOns or {}
    local num = api.GetNumAddOns or GetNumAddOns
    local info = api.GetAddOnInfo or GetAddOnInfo
    local loaded = api.IsAddOnLoaded or IsAddOnLoaded
    local meta = api.GetAddOnMetadata or GetAddOnMetadata
    if not (num and info and loaded) then return "unknown" end
    local list = {}
    for i = 1, num() do
        local name = info(i)
        if name and name ~= ADDON and not name:find("^Blizzard_") and loaded(i) then
            local v = meta and meta(name, "Version")
            list[#list + 1] = v and (name .. " " .. v) or name
        end
    end
    table.sort(list)
    if #list > 40 then
        local more = #list - 40
        for i = #list, 41, -1 do list[i] = nil end
        list[#list + 1] = "+" .. more .. " more"
    end
    return #list > 0 and table.concat(list, ", ") or "none"
end

-- No character name, realm or BattleTag goes into the report.
function ns.BuildDiagnostics()
    local db = ns.db
    local lines = {}
    local version, build, toc = "?", "?", "?"
    if GetBuildInfo then
        local v, b, _, t = GetBuildInfo()
        version, build, toc = tostring(v), tostring(b), tostring(t)
    end
    lines[#lines + 1] = ("addon=%s v%s | game=%s (%s) | iface=%s | locale=%s"):format(
        ADDON, tostring(ns.VERSION), version, build, toc, GetLocale and GetLocale() or "?")
    lines[#lines + 1] = ("settings: enabled=%s dialog=%s group=%s groupOnly=%s notify=%s allowed=%d added=%d"):format(
        onoff(db.enabled), onoff(db.guardDialog), onoff(db.guardGroup), onoff(db.groupOnly),
        onoff(db.notify), count(db.allow), count(db.extra))
    lines[#lines + 1] = ("wrapped: AcceptQuest=%s ConfirmAcceptQuest=%s"):format(
        onoff(ns.installed and AcceptQuest ~= ns.original.AcceptQuest),
        onoff(ns.installed and ConfirmAcceptQuest ~= ns.original.ConfirmAcceptQuest))
    if #db.errors == 0 then
        lines[#lines + 1] = "errors: none"
    else
        lines[#lines + 1] = "sig=" .. db.errors[#db.errors].sig
        for i = #db.errors, 1, -1 do
            local e = db.errors[i]
            lines[#lines + 1] = ("error %s x%d: %s"):format(e.sig, e.count or 1, e.msg)
        end
    end
    if #db.log == 0 then
        lines[#lines + 1] = "recent: none"
    else
        for i = #db.log, math.max(1, #db.log - 4), -1 do
            local e = db.log[i]
            local when = (date and e.t and e.t > 0) and date("!%Y-%m-%d %H:%M", e.t) or "?"
            lines[#lines + 1] = ("recent: %s UTC %s q=%s by=%s"):format(when, e.kind, tostring(e.q), tostring(e.a))
        end
    end
    if db.selftest then
        lines[#lines + 1] = "selftest: " .. db.selftest.summary
    end
    lines[#lines + 1] = "addons: " .. otherAddons()
    return table.concat(lines, "\n")
end

local function readOnlyBox(box, getText)
    box:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            self:SetText(getText())
            self:HighlightText()
        end
    end)
    box:SetScript("OnEscapePressed", function(self) self:GetParent():Hide() end)
end

local function createBugFrame()
    local f = CreateFrame("Frame", "AnvilEscortGuardBugFrame", UIParent, "BackdropTemplate")
    f:SetSize(580, 340)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
    end

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -18)
    title:SetText(ns.NAME .. ": report a bug")

    local help = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", 22, -44)
    help:SetPoint("RIGHT", -22, 0)
    help:SetJustifyH("LEFT")
    help:SetText("1. The text below is selected: press Ctrl+C (Cmd+C on Mac) to copy it.\n"
        .. "2. Open the address at the bottom in your browser and paste it into a new issue.")

    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 22, -78)
    scroll:SetPoint("BOTTOMRIGHT", -40, 64)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(510)
    scroll:SetScrollChild(edit)
    readOnlyBox(edit, function() return f.report or "" end)
    edit:SetScript("OnEscapePressed", function() f:Hide() end)
    f.edit = edit

    local url = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    url:SetSize(400, 22)
    url:SetPoint("BOTTOMLEFT", 30, 26)
    url:SetAutoFocus(false)
    url:SetText(ns.BUG_URL)
    readOnlyBox(url, function() return ns.BUG_URL end)
    url:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    url:SetScript("OnEscapePressed", function() f:Hide() end)
    f.url = url

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    if UISpecialFrames then table.insert(UISpecialFrames, "AnvilEscortGuardBugFrame") end -- Esc closes it
    return f
end

function ns.ShowBugReport()
    local text = ns.BuildDiagnostics()
    if not ns.bugFrame then
        local ok, f = pcall(createBugFrame)
        if not ok then
            ns.RecordError(f)
            ns.Print("could not open the report window. Report at " .. ns.BUG_URL .. " and paste this:")
            for line in text:gmatch("[^\n]+") do print(line) end
            return text
        end
        ns.bugFrame = f
    end
    local f = ns.bugFrame
    f.report = text
    f.edit:SetText(text)
    f:Show()
    f.edit:SetFocus()
    f.edit:HighlightText()
    return text
end

---------------------------------------------------------------------------
-- Self-test: checks the parts the unit tests can only fake.
---------------------------------------------------------------------------
function ns.SelfTest()
    local results = {}
    local function check(name, ok, detail)
        results[#results + 1] = { name = name, ok = ok, detail = detail }
    end
    check("AcceptQuest wrapped", ns.installed == true and AcceptQuest ~= ns.original.AcceptQuest)
    check("ConfirmAcceptQuest wrapped", ns.installed == true and ConfirmAcceptQuest ~= ns.original.ConfirmAcceptQuest)
    check("GetQuestID present", type(GetQuestID) == "function")
    check("GetQuestTagInfo present", C_QuestLog ~= nil and type(C_QuestLog.GetQuestTagInfo) == "function")
    -- Typed into chat, the call stack holds only Blizzard's chat code.
    local origin, name = "unknown", nil
    if type(debugstack) == "function" then origin, name = ns.ClassifyStack(debugstack(1, 30, 0)) end
    check("call-stack reading", origin == "blizzard", origin .. (name and (" " .. name) or ""))
    -- Information only (not pass/fail): is the escort tag readable for a known escort?
    -- It can be empty until the game has loaded that quest's data.
    local okTag, tag = pcall(ns.ReadTag, 94556)
    results[#results + 1] = { name = "escort tag for quest 94556", info = true,
        detail = okTag and ("tag=" .. tostring(tag)) or "error" }

    local passed, total = 0, 0
    local failed = {}
    for _, r in ipairs(results) do
        if not r.info then
            total = total + 1
            if r.ok then
                passed = passed + 1
            else
                failed[#failed + 1] = r.name .. (r.detail and (" (" .. r.detail .. ")") or "")
            end
        end
    end
    local summary = ("%d/%d passed"):format(passed, total)
    if #failed > 0 then summary = summary .. "; failed: " .. table.concat(failed, "; ") end
    ns.db.selftest = { t = time and time() or 0, summary = summary }
    return results, summary
end

---------------------------------------------------------------------------
-- /aeg and /escortguard
---------------------------------------------------------------------------
local HELP = {
    "/aeg on | off  - turn the guard on or off",
    "/aeg dialog on|off, group on|off, grouponly on|off, notify on|off",
    "/aeg check <questID>  - is this quest guarded, and why",
    "/aeg allow <questID>  - never guard this quest",
    "/aeg add <questID>    - always guard this quest",
    "/aeg reset <questID>  - undo allow/add",
    "/aeg list | config | selftest | bug",
}

local TOGGLES = { dialog = "guardDialog", group = "guardGroup", grouponly = "groupOnly", notify = "notify" }

local REASONS = {
    allowed = "not guarded: you allowed it",
    added = "guarded: you added it",
    list = "guarded: built-in escort list",
    tag = "guarded: the game tags it as an escort",
    none = "not an escort as far as the guard knows",
}

local function parseID(arg)
    local id = tonumber(arg)
    if id and id > 0 and id == math.floor(id) then return id end
    return nil
end

function ns.HandleSlash(msg)
    local db = ns.db
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")

    if cmd == "" or cmd == "help" or cmd == "status" then
        ns.Print(("is %s (quest window %s, group popups %s%s). Version %s."):format(
            onoff(db.enabled), onoff(db.guardDialog), onoff(db.guardGroup),
            db.groupOnly and ", only in groups" or "", tostring(ns.VERSION)))
        for _, line in ipairs(HELP) do print("  " .. line) end
    elseif cmd == "on" or cmd == "off" then
        db.enabled = (cmd == "on")
        ns.Print("is " .. cmd .. ".")
    elseif TOGGLES[cmd] then
        if arg ~= "on" and arg ~= "off" then
            ns.Print("use /aeg " .. cmd .. " on  or  /aeg " .. cmd .. " off")
        else
            db[TOGGLES[cmd]] = (arg == "on")
            ns.Print(cmd .. " is " .. arg .. ".")
        end
    elseif cmd == "check" or cmd == "allow" or cmd == "add" or cmd == "reset" then
        local id = parseID(arg)
        if not id then
            ns.Print("give a quest ID number, e.g. /aeg " .. cmd .. " 94556")
            return
        end
        if cmd == "allow" then
            db.allow[id], db.extra[id] = true, nil
        elseif cmd == "add" then
            db.extra[id], db.allow[id] = true, nil
        elseif cmd == "reset" then
            db.allow[id], db.extra[id] = nil, nil
        end
        local _, why = ns.IsEscort(id)
        ns.Print(("quest %d: %s."):format(id, REASONS[why] or why))
    elseif cmd == "list" then
        local allow, extra = sortedKeys(db.allow), sortedKeys(db.extra)
        ns.Print("allowed by you: " .. (#allow > 0 and table.concat(allow, ", ") or "none"))
        ns.Print("added by you: " .. (#extra > 0 and table.concat(extra, ", ") or "none"))
        local n = 0
        for _ in pairs(ns.EscortIDs) do n = n + 1 end
        ns.Print(("built-in list: %d escort quests."):format(n))
    elseif cmd == "config" or cmd == "options" then
        if not ns.OpenSettings() then ns.Print("the settings window is not available; use the /aeg commands.") end
    elseif cmd == "selftest" or cmd == "test" then
        local results, summary = ns.SelfTest()
        for _, r in ipairs(results) do
            print(("  %s %s%s"):format(r.info and "INFO" or (r.ok and "PASS" or "FAIL"), r.name, r.detail and (" (" .. r.detail .. ")") or ""))
        end
        ns.Print("self-test " .. summary .. ".")
    elseif cmd == "bug" then
        ns.ShowBugReport()
    else
        ns.Print("unknown command. Type /aeg for help.")
    end
end

SLASH_ANVILESCORTGUARD1 = "/aeg"
SLASH_ANVILESCORTGUARD2 = "/escortguard"
SlashCmdList.ANVILESCORTGUARD = function(msg)
    local ok, err = pcall(ns.HandleSlash, msg)
    if not ok then
        ns.RecordError(err)
        ns.Print("something went wrong. Type /aeg bug to report it.")
    end
end

function ns.OnLogin()
    ns.RegisterSettings()
end
