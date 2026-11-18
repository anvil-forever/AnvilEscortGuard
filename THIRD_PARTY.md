# Third-party sources and credits

Anvil Escort Guard contains no third-party code or libraries.

| Source | What we used | How | Permission / license |
|---|---|---|---|
| [Questie](https://github.com/Questie/Questie), file `Modules/Auto/DisallowedIDs.lua` (commit `e4b2451caa`, 2026-11-16) | **Quest ID numbers only**: the escort entries of its auto-accept exclusion list, classic-era and WoW Forever sections. Non-escort entries (profession, warlock, flight quests) were left out. Quest names in our comments are the in-game titles | Reference for `EscortIDs.lua`; no code copied | Questie's `LICENSE.md`: the Questie team accepts reuse under GPLv3 terms. Our add-on is GPL-3.0-or-later. Questie's name and logo are not used. Thank you, Questie team |
| [Blizzard UI source, `forever` branch](https://github.com/Gethe/wow-ui-source/tree/forever) (build 1.60.1.70959) | API facts: the `QUEST_ACCEPT_CONFIRM(name, questTitle, questID)` payload, the `QUEST_ACCEPT` popup calling `ConfirmAcceptQuest()` | Reference only; no code copied | — |
| [Warcraft Wiki](https://warcraft.wiki.gg/) | API documentation (`AcceptQuest`, `ConfirmAcceptQuest`, `C_QuestLog.GetQuestTagInfo`, secret values) | Reference only | — |
| [GNU GPL v3](https://www.gnu.org/licenses/gpl-3.0.txt) | License text in `LICENSE` | Verbatim | © Free Software Foundation |

To add a source, list it here in the same pull request.
