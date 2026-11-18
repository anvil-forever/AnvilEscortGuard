# Anvil Escort Guard

**Quest add-ons should not start escort quests for you.** Anvil Escort Guard stops other add-ons (Questie, RestedXP/RXP Guides, auto-accept add-ons) from auto-accepting escort quests in WoW Forever. That covers the "<player> is starting <quest>" popup when a group member starts one. You still accept escorts yourself, with one click, when your group is ready.

Free, no ads, nothing locked. By [Anvil Forever](https://anvilforever.com).

## For players

### What it does
- **Quest-giver window:** an add-on tries to auto-accept an escort quest → stopped. Click **Accept** yourself.
- **Group escort popup:** a group member starts an escort and your add-on tries to click **Yes** for you → stopped. Click **Yes** yourself.
- **Normal quests are not touched.** Auto-accept keeps working for everything else.
- **Your own clicks always go through.**
- When it steps in, you see one short line in chat that names the add-on and the quest.

### How it knows a quest is an escort
1. The game marks most escort quests with an "Escort" tag.
2. A built-in list of escort quests checked for WoW Forever covers quests whose tag is missing.
3. Your own list: `/aeg add <questID>` and `/aeg allow <questID>`.

The group popup is always an escort, so every auto-click on it is stopped.

### Commands
| Command | What it does |
|---|---|
| `/aeg` | status and help (`/escortguard` works too) |
| `/aeg on` / `/aeg off` | turn the guard on or off |
| `/aeg dialog on\|off` | guard the quest-giver window |
| `/aeg group on\|off` | guard group escort popups |
| `/aeg grouponly on\|off` | only guard while you are in a group |
| `/aeg notify on\|off` | chat line when something is stopped |
| `/aeg check <questID>` | is this quest guarded, and why |
| `/aeg allow <questID>` / `add` / `reset` | your own exceptions |
| `/aeg list` | your exceptions and the size of the built-in list |
| `/aeg config` | open the settings page (Options → AddOns, searchable) |
| `/aeg selftest` | quick health check |
| `/aeg bug` | report a bug |

### Using a quest add-on that replaces Blizzard's quest window?
The first click on its Accept button is stopped. Click it once more and it goes through.

### Performance
It does no work while you play. It runs only when something calls accept or confirm on a quest, then checks one table. It registers no per-frame updates or timers.

### Report a bug
Type `/aeg bug`. A window opens with a short report already selected. Copy it (Ctrl+C, or Cmd+C on Mac) and paste it at **https://anvilforever.com/bug**, or open an issue on GitHub. The report holds versions, settings and recent events, **never** your character name or realm. Add-ons cannot send anything over the internet, so nothing leaves your computer unless you paste it.

### Support the project
Anvil Forever add-ons are free and stay free. Donation links will appear here and on CurseForge at release.

## For contributors

### Layout
| File | What it holds |
|---|---|
| `AnvilEscortGuard.toc` | unsuffixed TOC, `## Interface: 16001` (the BigWigs packager does not recognise `_Forever.toc`) |
| `EscortIDs.lua` | built-in escort quest IDs |
| `Core.lua` | the guard: wraps `AcceptQuest` / `ConfirmAcceptQuest`, reads the call stack, decides, fails open |
| `UI.lua` | `/aeg`, the settings page, the bug window, the self-test |
| `tests/` | unit tests with a mocked WoW API (`tests/mock/wow.lua`) |
| `tools/check_package.lua` | the release check |
| `docs/IN_CLIENT_TEST_PLAN.md` | the checklist for testing in the game client |

### Run the tests
- `busted`, with Lua 5.1 or LuaJIT and busted installed.
- Without busted: `lua tests/run.lua`, or `pandoc lua tests/run.lua`, from this folder.
- `luacheck .` lints. `lua tools/check_package.lua` checks the package.

### Adding an escort quest
Open a pull request to `EscortIDs.lua` with the quest ID, the quest name and how you confirmed it is an escort in WoW Forever.

## License
GPL-3.0-or-later. Copyright (C) 2026 Anvil Forever. See `LICENSE` and `THIRD_PARTY.md`.
Not affiliated with or endorsed by Blizzard Entertainment.
