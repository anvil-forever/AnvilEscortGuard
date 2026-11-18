-- Package check: run before every release (CI runs it too).
--   lua tools/check_package.lua        (from the add-on's root folder)
-- Checks the TOC (Forever interface, files exist, unsuffixed name) and the repo files
-- the release needs. Prints problems and exits 1 if there are any.

local C = {}

C.ADDON = "AnvilEscortGuard"
C.INTERFACE = "16001" -- WoW Forever 1.60.x

local function readFile(path)
    local fh = io.open(path, "r")
    if not fh then return nil end
    local s = fh:read("*a")
    fh:close()
    return s
end

function C.check(root)
    root = root or "."
    local problems = {}
    local function problem(msg) problems[#problems + 1] = msg end

    local tocPath = root .. "/" .. C.ADDON .. ".toc"
    local toc = readFile(tocPath)
    if not toc then
        problem("missing " .. C.ADDON .. ".toc (unsuffixed; the BigWigs packager skips _Forever.toc)")
        return problems
    end
    if readFile(root .. "/" .. C.ADDON .. "_Forever.toc") then
        problem(C.ADDON .. "_Forever.toc exists: the packager does not recognise it; use the unsuffixed TOC")
    end

    local iface = toc:match("##%s*Interface:%s*([^\r\n]+)")
    if not iface then
        problem("TOC has no ## Interface line")
    elseif not (("," .. iface:gsub("%s", "") .. ","):find("," .. C.INTERFACE .. ",", 1, true)) then
        problem("TOC Interface is '" .. iface .. "', expected it to include " .. C.INTERFACE)
    end
    if not toc:find("##%s*Version:%s*@project%-version@") then
        problem("TOC Version should be @project-version@ (the packager fills it in)")
    end
    if not toc:find("##%s*SavedVariables:%s*AnvilEscortGuardDB") then
        problem("TOC SavedVariables must be AnvilEscortGuardDB")
    end

    local listed = 0
    for line in toc:gmatch("[^\r\n]+") do
        if not line:find("^#") and line:find("%S") then
            listed = listed + 1
            local file = line:gsub("%s+$", ""):gsub("\\", "/")
            if not readFile(root .. "/" .. file) then problem("TOC lists a missing file: " .. file) end
        end
    end
    if listed == 0 then problem("TOC lists no files") end

    local license = readFile(root .. "/LICENSE") or ""
    if not (license:find("GNU GENERAL PUBLIC LICENSE", 1, true) and license:find("Version 3, 29 June 2007", 1, true)) then
        problem("LICENSE must contain the GPLv3 text")
    end
    if not license:find("^%s*GNU GENERAL PUBLIC LICENSE") then
        problem("LICENSE must be the unmodified GPLv3 text (put the copyright notice in NOTICE) so GitHub detects GPL-3.0")
    end
    local notice = readFile(root .. "/NOTICE") or ""
    if not notice:find("Copyright (C) 2026 Anvil Forever", 1, true) then
        problem("NOTICE must carry the Anvil Forever copyright notice")
    end

    for _, f in ipairs({ "README.md", "CHANGELOG.md", "THIRD_PARTY.md", ".pkgmeta" }) do
        if not readFile(root .. "/" .. f) then problem("missing " .. f) end
    end
    local changelog = readFile(root .. "/CHANGELOG.md") or ""
    if not (changelog:find("### For players", 1, true) and changelog:find("### For contributors", 1, true)) then
        problem("CHANGELOG.md needs 'For players' and 'For contributors' sections")
    end
    local pkgmeta = readFile(root .. "/.pkgmeta") or ""
    for _, ignored in ipairs({ "tests", "tools", "docs" }) do
        if not pkgmeta:find("%-%s*" .. ignored) then problem(".pkgmeta should ignore " .. ignored .. "/") end
    end
    return problems
end

-- Command-line use
if arg and arg[0] and arg[0]:find("check_package%.lua$") then
    local problems = C.check(".")
    for _, p in ipairs(problems) do print("PROBLEM: " .. p) end
    print(#problems == 0 and "package check: OK" or ("package check: " .. #problems .. " problem(s)"))
    os.exit(#problems == 0 and 0 or 1)
end

return C
