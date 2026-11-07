# Motion-Forever

WoW Forever addon: shows guild members who run it on the world map, by
sharing positions over hidden guild addon messages, plus a guild list
window. README.md covers features, layout and workflow for people.

## Status (as of 2026-11-06)

- Phase 1 (map dots), phase 2 step 1 (guild list window) and layer display
  (`Layer.lua`) are built, unit tested and merged into `main`. In-game
  testing has started; the first round of fixes (smaller dots, names
  without server, clearer layer status, `/mforever layer`) is in.
- Layer detection isn't confirmed working in game yet. If it stays
  unknown, the output of `/mforever layer` shows the NPC ID the game gives.
- 2026-11-08: same-layer players showed "Different layer". Cause: the
  layer number in NPC IDs (zoneUID) differs per zone, not just per layer.
  Fix on branch `fix-layer-compare`: keys are now `zoneMapID:zoneUID`,
  only same-zone keys are compared, and the key is a vote over the last 9
  NPCs. Old `0-1234` keys are ignored. Not yet confirmed in game.
- Next: launch-day testing with `docs/LAUNCH-TESTING.md`, then phase 2
  step 2 (quest lists, `QREQ`/`QLIST`). The plan and build order are in
  `docs/PHASE2.md`.
- Expect launch-day fixes, most likely in `Compat.lua`, `MapPins.lua/.xml`
  and `GuildListUI.lua`.

## Client facts

- Client version 1.60.1, so `## Interface: 16001` in the `.toc`.
- Install folder: `C:\Program Files (x86)\World of Warcraft\_forever_`.
- `_forever_\Interface\AddOns\Motion-Forever` is a **junction** to this
  repo's `Motion-Forever/` folder. The game loads whatever branch is checked
  out. Never delete files through that path.
- BugSack and BugGrabber are installed there for catching errors.
- The API is reported to be Retail (Midnight) style: `C_Map`, `C_ChatInfo`,
  map canvas pins, ScrollBox. Midnight restricts some addon features in
  combat and instances, so wrap risky calls in `pcall`.

## Code rules

- **Lua 5.1 only** (WoW's version): no `//`, `goto`, `<const>`, bitwise
  operators, or `string.format("%d")` on non-integers.
- Every file starts with `local _, ns = ...`. Share code through `ns`,
  not globals. The only globals are those the game requires: saved
  variables (`MotionForeverDB`), slash commands, the pin mixin and template,
  and the guild list frame name.
- **Every game API call that might differ on Forever goes in `Compat.lua`.**
- Modules talk through the event bus (`ns.On` / `ns.Fire` in `Core.lua`),
  not by calling each other's internals. List any new event in Core.lua's
  comment block.
- Keep logic pure where possible (`Protocol`, `Roster`, `GuildListData`,
  `Position.ShouldSend`): no game calls, time passed in, so it can be unit
  tested.
- New settings go in `ns.defaults` (Core.lua); change them with
  `ns.SetOption` so `SETTINGS_CHANGED` fires.
- New files go in the `.toc` in load order. A mixin's Lua file loads
  before its XML.
- Plain, short comments. Names in code use `MotionForever`; anything shown
  to players uses `Motion-Forever`.

## Message protocol rules

See `docs/PROTOCOL.md`. Don't break compatibility with older copies of the
addon:
- Only add fields at the **end** of a message; never change existing ones.
- Unknown message types are ignored, so new types are safe.
- New features advertise a capability letter in `POS` (`Q` = quests).
- Stay under 255 characters per message. Avoid traffic bursts; see the
  "Traffic safeguards" section in `docs/PHASE2.md`.

## Testing

Lua 5.4 was installed with winget, but it isn't on the Bash tool's PATH in
this environment. Run the tests with:

```bash
export PATH="/c/Users/jade_/AppData/Local/Microsoft/WinGet/Packages/DEVCOM.Lua_Microsoft.Winget.Source_8wekyb3d8bbwe/bin:$PATH"; lua tests/run.lua
```

Before committing code:
1. `lua tests/run.lua`: all tests must pass. Add tests for new pure logic.
2. `luac -p` on every changed `.lua` file.
3. Grep for Lua 5.4-only syntax (Lua 5.4 accepts it, WoW doesn't).

## Workflow

- Build each feature on a branch (e.g. `phase2-quests`). Keep `main` working,
  and merge when done. Push to GitHub when the user agrees.
- Remote: https://github.com/alfakaboom-create/Motion-Forever. Git identity
  is set in this repo's local config.
- When features change, update the docs too: README (features, commands,
  layout), `docs/PHASE2.md` (build order), `docs/PROTOCOL.md` (messages),
  and `docs/LAUNCH-TESTING.md` (new things to test).
- Releases: bump the version in both the `.toc` and `ns.VERSION`, tag
  `vX.Y.Z`, and build the zip with `scripts/package.ps1`.

## Working with the user

- The user isn't a developer: explain in plain language and avoid jargon.
- Answer questions before taking action. When asked "is this possible" or
  "should I", answer first, and only build once they say so.
- Confirm before anything permanent or public: deleting, pushing, merging,
  or publishing.
