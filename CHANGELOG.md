# Changelog

## 0.1.0 (unreleased)

### For players
- First version. Stops other add-ons from auto-accepting escort quests in the quest-giver window.
- Stops add-ons from auto-joining an escort that a group member started. You can still click Yes.
- Escort quests are recognised by the game's Escort tag and by a built-in list for WoW Forever (72 quests).
- `/aeg` commands, a searchable settings page, `/aeg check <questID>`, and `/aeg bug` for a copyable bug report.

### For contributors
- Unit tests with a mocked WoW API (`busted`, or `lua tests/run.lua` without busted).
- `tools/check_package.lua` checks the TOC, LICENSE, changelog and `.pkgmeta` before a release.
- In-client checklist in `docs/IN_CLIENT_TEST_PLAN.md`.
