std = "lua51"
max_line_length = 140
codes = true
exclude_files = { ".luarocks", "lua_modules" }

-- Globals the add-on creates or replaces on purpose
globals = {
    "AnvilEscortGuardDB",
    "SLASH_ANVILESCORTGUARD1", "SLASH_ANVILESCORTGUARD2", "SlashCmdList",
    "AcceptQuest", "ConfirmAcceptQuest",
    "UISpecialFrames",
}

-- WoW API we read
read_globals = {
    "C_AddOns", "C_QuestLog", "ChatFontNormal", "CreateFrame", "GetAddOnInfo", "GetAddOnMetadata",
    "GetBuildInfo", "GetLocale", "GetNumAddOns", "GetQuestID", "GetTime", "GetTitleText",
    "IsAddOnLoaded", "IsInGroup", "Settings", "UIParent", "date", "debugstack", "issecretvalue", "time",
}

files["tests/"] = { std = "+busted", globals = { "unpack" }, unused_args = false }
files["tools/"] = { std = "+lua51" }
