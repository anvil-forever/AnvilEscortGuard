-- Anvil Escort Guard
-- Copyright (C) 2026 Anvil Forever
-- SPDX-License-Identifier: GPL-3.0-or-later
--
-- How it works, in short:
--   * AcceptQuest() and ConfirmAcceptQuest() are wrapped once, when this file loads.
--   * A call from Blizzard's own UI (your click) always goes through.
--   * A call from another add-on is stopped when it would start an escort quest.
--   * If anything in the guard fails, the call goes through (fail open) and the
--     error is kept for /aeg bug.
-- No OnUpdate, no timers: the guard only runs when one of the two functions is called.

local ADDON, ns = ...

ns.NAME = "Anvil Escort Guard"
ns.ESCORT_TAG = 84          -- quest tag ID for "Escort"
ns.CONFIRM_WINDOW = 60      -- seconds a "<player> is starting <quest>" popup counts as open
ns.RETRY_MIN_GAP = 0.4      -- a second try in the same dialog this much later counts as a person
ns.LOG_SIZE = 10
ns.ERROR_SIZE = 5
ns.BUG_URL = "https://github.com/anvil-forever/AnvilEscortGuard/issues/new/choose"

local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
ns.VERSION = (getMeta and getMeta(ADDON, "Version")) or "dev"

-- Player-facing text (English; translations can replace these keys).
local L = {
    PREFIX = "|cffe08a3cAnvil Escort Guard:|r ",
    BLOCKED_ACCEPT = "stopped %s from auto-accepting the escort quest \"%s\". Accept it yourself when your group is ready.",
    BLOCKED_CONFIRM = "stopped %s from auto-joining \"%s\", an escort that %s started. Click Yes in the popup to join.",
    RETRY_HINT = "Using a quest add-on to click Accept? Click it once more.",
    FIRST_RUN_1 = "(beta) is on. Add-ons can no longer start escort quests for you; you still accept them yourself.",
    FIRST_RUN_2 = "Type /aeg for options.",
    SOMEONE = "a group member",
    AN_ADDON = "an add-on",
}
ns.L = L

ns.defaults = {
    enabled = true,       -- master switch
    guardDialog = true,   -- quest-giver dialog (AcceptQuest)
    guardGroup = true,    -- "<player> is starting <quest>" popup (ConfirmAcceptQuest)
    groupOnly = false,    -- only guard while in a group
    notify = true,        -- chat line when something is stopped
    firstRunDone = false,
    allow = {},           -- [questID] = true: never guard
    extra = {},           -- [questID] = true: always treat as escort
    log = {},             -- last blocks, for /aeg bug
    errors = {},          -- last errors inside the guard, for /aeg bug
}

local function applyDefaults(db, defaults)
    for k, v in pairs(defaults) do
        if db[k] == nil or type(db[k]) ~= type(v) then
            if type(v) == "table" then db[k] = {} else db[k] = v end
        end
    end
    return db
end
ns.ApplyDefaults = applyDefaults

ns.db = applyDefaults({}, ns.defaults) -- replaced by the saved copy at ADDON_LOADED

local state = { serial = 0, confirm = nil, pending = nil, noticed = {} }
ns.state = state

local function now()
    return GetTime and GetTime() or 0
end

---------------------------------------------------------------------------
-- Errors (kept small; never thrown at the player)
---------------------------------------------------------------------------
function ns.Hash(s)
    local h = 5381
    s = tostring(s)
    for i = 1, #s do
        h = (h * 33 + s:byte(i)) % 4294967296
    end
    return string.format("%08x", math.floor(h))
end

function ns.RecordError(err)
    local msg = tostring(err):sub(1, 200)
    local errors = ns.db.errors
    local sig = ns.Hash(msg:gsub("^[^:]*:%d+: ", ""))
    for _, e in ipairs(errors) do
        if e.sig == sig then
            e.count = (e.count or 1) + 1
            return err
        end
    end
    errors[#errors + 1] = { sig = sig, msg = msg, count = 1 }
    while #errors > ns.ERROR_SIZE do table.remove(errors, 1) end
    return err
end

---------------------------------------------------------------------------
-- Who is calling? Read the Lua call stack.
--   "blizzard": only Blizzard UI code on the stack (a click on Blizzard's button)
--   "addon":    another add-on's file is on the stack (first one is named)
--   "unknown":  neither, e.g. a /run macro typed by the player
---------------------------------------------------------------------------
function ns.ClassifyStack(stack)
    if type(stack) ~= "string" then return "unknown" end
    local sawBlizzard = false
    for path in stack:gmatch("[Ii][Nn][Tt][Ee][Rr][Ff][Aa][Cc][Ee][/\\]([^\n:\"%]]+)") do
        local name = path:match("^[Aa][Dd][Dd][Oo][Nn][Ss][/\\]([^/\\]+)")
        if name then
            if name:find("^Blizzard_") then
                sawBlizzard = true
            elseif name ~= ADDON then
                return "addon", name
            end
        elseif path:find("^FrameXML") or path:find("^SharedXML") or path:find("^GlueXML") then
            sawBlizzard = true
        end
    end
    if sawBlizzard then return "blizzard" end
    return "unknown"
end

local function callerInfo()
    if type(debugstack) ~= "function" then return "unknown" end
    return ns.ClassifyStack(debugstack(1, 30, 0))
end

---------------------------------------------------------------------------
-- Is this quest an escort?
---------------------------------------------------------------------------
local function readTag(questID)
    if not (C_QuestLog and C_QuestLog.GetQuestTagInfo) then return nil end
    local info = C_QuestLog.GetQuestTagInfo(questID)
    if type(info) ~= "table" then return nil end
    local tag = info.tagID
    if issecretvalue and issecretvalue(tag) then return nil end
    return tag
end
ns.ReadTag = readTag

-- Returns isEscort, reason ("allowed" | "added" | "list" | "tag" | "none")
function ns.IsEscort(questID)
    if type(questID) ~= "number" or questID <= 0 then return false, "none" end
    local db = ns.db
    if db.allow[questID] then return false, "allowed" end
    if db.extra[questID] then return true, "added" end
    if ns.EscortIDs and ns.EscortIDs[questID] then return true, "list" end
    local ok, tag = pcall(readTag, questID)
    if ok and tag == ns.ESCORT_TAG then return true, "tag" end
    return false, "none"
end

---------------------------------------------------------------------------
-- The decision. kind: "accept" (quest dialog) or "confirm" (group popup).
-- Returns allow (boolean), reason (string).
---------------------------------------------------------------------------
function ns.Decide(kind, questID, origin, t)
    local db = ns.db
    if not db.enabled then return true, "disabled" end
    if origin ~= "addon" then return true, origin end
    if db.groupOnly and not (IsInGroup and IsInGroup()) then return true, "solo" end

    if kind == "accept" then
        if not db.guardDialog then return true, "off" end
        if not ns.IsEscort(questID) then return true, "not-escort" end
    else
        if not db.guardGroup then return true, "off" end
        local c = state.confirm
        if not c or (t - c.time) > ns.CONFIRM_WINDOW then return true, "no-popup" end
        if questID and db.allow[questID] then return true, "allowed" end
    end

    -- Quest UIs that replace Blizzard's (e.g. a custom quest frame) call the same
    -- functions when you click. A second try in the same dialog, a moment later,
    -- is treated as you.
    local p = state.pending
    local same = p and p.kind == kind and p.questID == questID and p.serial == state.serial
    if same and (t - p.time) >= ns.RETRY_MIN_GAP then
        state.pending = nil
        return true, "retry"
    end
    if not same then
        state.pending = { kind = kind, questID = questID, serial = state.serial, time = t }
    end
    return false, "blocked"
end

---------------------------------------------------------------------------
-- Telling the player
---------------------------------------------------------------------------
local function questTitle(kind, questID)
    if kind == "confirm" and state.confirm and state.confirm.title then
        return state.confirm.title
    end
    local title
    if C_QuestLog and C_QuestLog.GetTitleForQuestID and questID then
        local ok, v = pcall(C_QuestLog.GetTitleForQuestID, questID)
        if ok and type(v) == "string" and v ~= "" then title = v end
    end
    if not title and GetTitleText then
        local ok, v = pcall(GetTitleText)
        if ok and type(v) == "string" and v ~= "" then title = v end
    end
    return title or ("quest " .. tostring(questID))
end

function ns.Print(msg)
    print(L.PREFIX .. msg)
end

function ns.Notify(kind, questID, addonName)
    if not ns.db.notify then return end
    local key = kind .. ":" .. tostring(questID)
    if state.noticed[key] then return end
    state.noticed[key] = true
    local who = addonName or L.AN_ADDON
    if kind == "accept" then
        ns.Print(L.BLOCKED_ACCEPT:format(who, questTitle(kind, questID)))
    else
        local starter = state.confirm and state.confirm.name or L.SOMEONE
        ns.Print(L.BLOCKED_CONFIRM:format(who, questTitle(kind, questID), starter))
    end
    if not state.hintShown then
        state.hintShown = true -- once per session, to keep chat calm
        ns.Print(L.RETRY_HINT)
    end
end

local function record(kind, questID, addonName)
    local log = ns.db.log
    log[#log + 1] = { t = time and time() or 0, kind = kind, q = questID, a = addonName }
    while #log > ns.LOG_SIZE do table.remove(log, 1) end
end

-- Runs inside xpcall. Returns allow.
function ns.Guard(kind, questID)
    local origin, addonName = callerInfo()
    local allow, reason = ns.Decide(kind, questID, origin, now())
    if not allow then
        record(kind, questID, addonName)
        ns.Notify(kind, questID, addonName)
    end
    return allow, reason
end

---------------------------------------------------------------------------
-- Wrappers. Installed at load time so that add-ons loading after us, even ones
-- that keep a local copy of these functions, get the guarded version.
---------------------------------------------------------------------------
local function guardAccept()
    return ns.Guard("accept", GetQuestID and GetQuestID() or nil)
end

local function guardConfirm()
    local c = state.confirm
    return ns.Guard("confirm", c and c.questID or nil)
end

function ns.InstallWrappers()
    if ns.installed then return true end
    local origAccept, origConfirm = AcceptQuest, ConfirmAcceptQuest
    if type(origAccept) ~= "function" or type(origConfirm) ~= "function" then
        ns.RecordError("quest API missing: AcceptQuest/ConfirmAcceptQuest")
        return false
    end
    ns.original = { AcceptQuest = origAccept, ConfirmAcceptQuest = origConfirm }

    AcceptQuest = function(...)
        local ok, allow = xpcall(guardAccept, ns.RecordError)
        if ok and not allow then return end
        return origAccept(...)
    end

    ConfirmAcceptQuest = function(...)
        local ok, allow = xpcall(guardConfirm, ns.RecordError)
        if ok and not allow then return end
        state.confirm = nil
        return origConfirm(...)
    end

    ns.installed = true
    return true
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local function newDialog()
    state.serial = state.serial + 1
    state.pending = nil
    state.noticed = {}
end

local handlers = {}

function handlers.ADDON_LOADED(name)
    if name ~= ADDON then return end
    local early = ns.db
    local db = applyDefaults(type(AnvilEscortGuardDB) == "table" and AnvilEscortGuardDB or {}, ns.defaults)
    for _, e in ipairs(early.errors) do db.errors[#db.errors + 1] = e end
    while #db.errors > ns.ERROR_SIZE do table.remove(db.errors, 1) end
    AnvilEscortGuardDB = db
    ns.db = db
end

function handlers.PLAYER_LOGIN()
    if not ns.db.firstRunDone then
        ns.Print(L.FIRST_RUN_1)
        ns.Print(L.FIRST_RUN_2)
        ns.db.firstRunDone = true
    end
    if ns.OnLogin then
        local ok, err = pcall(ns.OnLogin)
        if not ok then ns.RecordError(err) end
    end
end

-- A quest dialog closed: the next one is a new dialog.
function handlers.QUEST_FINISHED()
    newDialog()
end

-- "<name> is starting <questTitle>": the escort popup. Payload per the Forever
-- API docs: name, questTitle, questID.
function handlers.QUEST_ACCEPT_CONFIRM(name, title, questID)
    newDialog()
    state.confirm = { name = name, title = title, questID = questID, time = now() }
end

ns.handlers = handlers

local frame = CreateFrame("Frame")
-- Registered while this file loads, so our handler runs before add-ons that
-- load later (Questie, RXPGuides and ForeverAutoQuest load after "Anvil...").
for event in pairs(handlers) do frame:RegisterEvent(event) end
frame:SetScript("OnEvent", function(_, event, ...)
    local ok, err = pcall(handlers[event], ...)
    if not ok then ns.RecordError(err) end
end)
ns.frame = frame

ns.InstallWrappers()
