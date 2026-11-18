# In-client test plan: Anvil Escort Guard 0.1.0

This is for the first session in the WoW Forever client on the Mac mini, with the dedicated test account.

**Rules:**
- Testing only: log in, test, log out.
- No gameplay automation. Every step is done by hand.
- The Mac is shared with VintedBot (see `VINTEDBOT-RULES.md`): do not close other apps or Chrome windows. Keep ≥ 20 GB disk free.

**Time:**
- About 45 minutes for the solo part (A–E).
- About 20 minutes more for the group part (F), which needs a second account in the group.

Fill in the result column (PASS, FAIL or a note) and save the copy as `docs/test-runs/YYYY-MM-DD.md`.

## 0. Setup
| # | Step | Expected | Result |
|---|---|---|---|
| 0.1 | Copy the `AnvilEscortGuard` folder (TOC, Lua files, LICENSE) into `World of Warcraft/_forever_/Interface/AddOns/`. The exact game folder name on Mac is unverified: check it | the folder sits next to other add-ons | |
| 0.2 | Install Questie (Forever build, ≥ 12.10.0) from CurseForge. Later: RXP Guides and ForeverAutoQuest, one at a time | listed in the add-on list | |
| 0.3 | At character select, open AddOns: Anvil Escort Guard is listed and not marked "out of date" | Interface 16001 accepted | |
| 0.4 | Turn on Lua errors (`/console scriptErrors 1`) and the taint log (`/console taintLog 1`); log in | no Lua error on login | |
| 0.5 | First login | two chat lines: "Anvil Escort Guard: is on…" and "Type /aeg for options." | |
| 0.6 | `/reload` | the first-run message does **not** repeat | |

## A. Self-test and basics
| # | Step | Expected | Result |
|---|---|---|---|
| A.1 | `/aeg selftest` | `5/5 passed`. Write down the INFO line (`tag=84` or `tag=nil`) | |
| A.2 | If "call-stack reading" FAILs: copy `/aeg bug` into the notes | the real `debugstack` format, needed to fix the parser | |
| A.3 | `/aeg` | status line and help | |
| A.4 | `/aeg config` | the settings page opens; typing "escort" in the search box finds it | |
| A.5 | `/aeg check 94556`, `/aeg check 783` | "guarded: built-in escort list" / "not an escort…" | |
| A.6 | `/aeg bug` | the window opens with the text selected; Cmd+C copies it; the link box shows anvilforever.com/bug; Esc closes it | |
| A.7 | Paste the copied report into a text file | no character name or realm in it | |

## B. Quest-giver window, solo (Questie auto-accept on)
Pick an escort available to the test character, for example a low-level one from `EscortIDs.lua`. Write down its ID.

| # | Step | Expected | Result |
|---|---|---|---|
| B.1 | Talk to a giver of a **normal** quest | Questie auto-accepts it; no chat line from us | |
| B.2 | Talk to the **escort** giver | the quest window stays open; chat says "stopped Questie from auto-accepting the escort quest …"; the escort does **not** start | |
| B.3 | Click **Accept** yourself | the quest is accepted and the escort starts | |
| B.4 | Abandon it, reopen the dialog, `/aeg allow <id>` | Questie now auto-accepts it; then `/aeg reset <id>` | |
| B.5 | `/aeg grouponly on` while solo | Questie auto-accepts the escort; then `/aeg grouponly off` | |
| B.6 | `/aeg off`, then `/aeg on` | the guard steps aside, then guards again | |
| B.7 | Check the escort tag: `/aeg check <id>` for an escort **not** in the list, if one is found | the tag reason shows, or note that the tag was empty | |
| B.8 | After B.2–B.3: check the taint log `Logs/taint.log` for `AnvilEscortGuard` | no "blocked action" lines; quote any lines that mention us | |

## C. Other auto-accepters (one at a time, Questie off)
| # | Step | Expected | Result |
|---|---|---|---|
| C.1 | RXP Guides with a guide step that accepts an escort | blocked with "stopped RXPGuides…" | |
| C.2 | ForeverAutoQuest with default settings (escort auto-confirm on) | blocked; note which path it uses | |
| C.3 | A quest-window replacement, if one exists for Forever (e.g. Immersion) | first Accept click blocked, second click accepted | |

## D. Resilience
| # | Step | Expected | Result |
|---|---|---|---|
| D.1 | Enter combat, then talk to a quest giver right after combat | no Lua errors | |
| D.2 | `/reload` with the bug window open | no errors; settings kept | |
| D.3 | Log out and back in | settings and the allow/add lists kept | |

## E. Performance
| # | Step | Expected | Result |
|---|---|---|---|
| E.1 | `/run UpdateAddOnMemoryUsage() print(GetAddOnMemoryUsage("AnvilEscortGuard"))` after login and after 10 minutes | under ~100 KB and not growing | |
| E.2 | Note the frame rate in town with the add-on on and off | no difference you can see | |

## F. Group escort popup (needs a second account in the group)
| # | Step | Expected | Result |
|---|---|---|---|
| F.1 | The second character starts the escort; the test character runs Questie | the "<name> is starting <quest>" popup stays; chat says "stopped Questie from auto-joining …, an escort that <name> started" | |
| F.2 | Click **Yes** | the test character joins the escort | |
| F.3 | Repeat with ForeverAutoQuest | blocked the same way | |
| F.4 | `/aeg group off`, repeat | the add-on auto-joins | |

## After the session
- Log out of the game.
- Delete local test notes containing anything personal.
- File any FAIL as a GitHub issue with the `/aeg bug` text.
- Release gate: A–E PASS (F PASS, or explicitly waived) → promote the beta to release.
