# Motion-Forever

A World of Warcraft addon for **WoW Forever** that shows your guild members
on the world map, the way party members are shown, plus a guild list window.

> **Status: built, waiting for launch.** Everything is written and unit
> tested, but nothing has been tested in game yet: WoW Forever is installed
> (client version 1.60.1) but hasn't launched. The code targets the modern
> Retail (Midnight) addon system, which Forever is reported to use. See
> [Launch testing](#launch-testing).

## How it works

The game only sends exact positions for people in your party, so
Motion-Forever shares them itself:

1. Every few seconds, each copy of the addon sends its player's position to
   the guild as a hidden addon message. These never appear in guild chat.
2. Every copy listens for those messages and draws a class-colored dot for
   each guild member on the world map.

**Only guild members who also run Motion-Forever appear on the map.**

## Features

**Phase 1: guild members on the map**
- [x] Guild members shown on zone and continent maps, colored by class
- [x] Tooltip on hover: name, level, layer and zone
- [x] Layers: shows whether each guild member is on the same layer as you,
      in the map tooltip and the guild list. Worked out from nearby NPCs, so
      it reads "unknown" until you've seen one. Only compares players in the
      same zone, because the game's layer numbers differ from zone to zone
- [x] Members in dungeons are still listed, without an exact position
- [x] Option to stop sharing your position
- [ ] Minimap dots
- [ ] Settings panel (slash commands only for now)

**Phase 2: guild list and quest sharing** ([full plan](docs/PHASE2.md))
- [x] Guild list window: everyone online with the addon, with level, zone
      and status, sortable. Can also list guild members without the addon
- [ ] See which quests a guild member can share with you
- [ ] Choose quests from a window showing level and zone, and request them
- [ ] Click-to-share popup for the guild member being asked
- [ ] Guild-wide "find quests I can get" search

## Installing (for players)

1. Download the latest `Motion-Forever-x.y.z.zip`.
2. Unzip it into `World of Warcraft\_forever_\Interface\AddOns`.
3. Check the folder ends up as `AddOns\Motion-Forever`, with the `.toc` file
   directly inside it. **Not** `AddOns\Motion-Forever\Motion-Forever`.
4. Restart the game, or `/reload`, and type `/mforever`.

## Commands

`/mforever` and `/motionforever` both work.

| Command | What it does |
|---|---|
| `/mforever` | Opens or closes the guild list window |
| `/mforever list` | Lists tracked guild members with zone, position and layer, in chat |
| `/mforever share on\|off` | Turns sharing your position on or off |
| `/mforever show on\|off` | Shows or hides guild members on your map |
| `/mforever ping` | Asks everyone to send their position now |
| `/mforever status` | Shows your settings, your current position and your layer |
| `/mforever layer` | Checks your layer and explains what it read from your target (target an NPC first) |
| `/mforever debug on\|off` | Prints extra messages, useful for testing |
| `/mforever help` | Lists all commands |

---

# For developers

**Repository:** https://github.com/alfakaboom-create/Motion-Forever

## Project layout

```
Motion-Forever/             <- repo root
├─ Motion-Forever/          <- the addon itself (this folder goes in Interface\AddOns)
│  ├─ Motion-Forever.toc    addon info and file load order
│  ├─ Core.lua              shared setup, settings, internal events
│  ├─ Protocol.lua          message format (no game calls, unit tested)
│  ├─ Roster.lua            who's online and where (no game calls, unit tested)
│  ├─ Layer.lua             which layer you and guild members are on (partly unit tested)
│  ├─ Compat.lua            every game API call that might differ on Forever
│  ├─ Comm.lua              sending and receiving messages
│  ├─ Position.lua          when to send your position
│  ├─ MapPins.lua/.xml      the dots on the world map
│  ├─ GuildListData.lua     guild list rows and sorting (unit tested)
│  ├─ GuildListUI.lua       the guild list window
│  └─ Commands.lua          /mforever
├─ CLAUDE.md                project notes Claude Code reads automatically
├─ tests/run.lua            unit tests, run outside the game
├─ scripts/
│  ├─ link-addon.ps1        links the addon into your WoW folder
│  └─ package.ps1           builds the release zip
└─ docs/
   ├─ PHASE2.md             phase 2 ideas and design
   ├─ PROTOCOL.md           message format, including phase 2 messages
   └─ LAUNCH-TESTING.md     in-game test checklist for launch day
```

**If something breaks on the Forever client, start with `Compat.lua`.**

## Ready for phase 2

The rest of phase 2 can be added without rewriting what's there:

- **Messages:** `QREQ`, `QLIST`, `QASK` and `QREPLY` are reserved. Current
  versions ignore them, so people on old and new versions can mix.
- **Capability letters:** a phase 2 copy advertises `Q`, so quest requests
  only go to players who can answer them.
- **One-to-one messages:** `Comm:Whisper()` is ready for quest requests.
- **Map dot hooks:** the `PIN_TOOLTIP` and `PIN_CLICK` events let the quest
  code add tooltip lines and open a menu from a dot.
- **Guild list hooks:** new columns (like Quests) go in `GuildList.columns`,
  and the `GUILDLIST_ROW_CLICK` event opens things from a row.
- **Data slot:** each guild member's entry reserves `entry.quests`.

## Getting set up

**On this computer** it's already done: the repo is connected to GitHub, git
knows your name and email, and the addon is linked into WoW Forever.

**On another computer:**

1. Get the code:
   ```bash
   git clone https://github.com/alfakaboom-create/Motion-Forever.git
   ```
2. Tell git who you are, for this project only. Run this inside the folder:
   ```bash
   git config user.name "alfakaboom"
   ```
   ```bash
   git config user.email "alfakaboom@gmail.com"
   ```
3. Link the addon into WoW, in PowerShell from the project folder:
   ```powershell
   .\scripts\link-addon.ps1 -WowPath "C:\Program Files (x86)\World of Warcraft\_forever_"
   ```
   The game then loads the addon straight from the project folder. Edit,
   type `/reload` in game, and check. To catch errors, install **BugSack** and
   **BugGrabber**.

The link loads whichever branch is checked out, so `git switch` also changes
what the game runs.

## Day-to-day workflow

| You want to... | Command |
|---|---|
| See what changed | `git status`, then `git diff` |
| Save a checkpoint | `git add -A` then `git commit -m "Describe the change"` |
| Upload to GitHub | `git push` |
| Get the latest from GitHub | `git pull` |
| Start a new feature | `git switch -c phase2-quests` (a new branch) |
| Go back to the main version | `git switch main` |
| Undo uncommitted changes to a file | `git restore <file>` |

A simple habit: keep `main` working, and build each feature on its own
branch. Merge it into `main` once it works.

## Unit tests

Protocol, roster tracking, send timing, and the guild list's rows and
sorting are tested outside the game. This needs Lua 5.1 or newer; on Windows,
`winget install DEVCOM.Lua` installs it.

```bash
lua tests/run.lua
```

## Releasing a version

1. Update the version in two places: `## Version:` in
   `Motion-Forever/Motion-Forever.toc`, and `ns.VERSION` in `Core.lua`.
2. Commit, tag and push:
   ```bash
   git tag v0.1.0
   ```
   ```bash
   git push --tags
   ```
3. Build the zip: `.\scripts\package.ps1` creates `dist\Motion-Forever-0.1.0.zip`.
4. On GitHub, go to **Releases → Draft a new release**, choose the tag, and
   attach the zip.

## Sharing

| Who | Easiest way |
|---|---|
| **One tester** | Send them the zip directly, for example on Discord. If they use git, they can clone the repo and run the link script instead, then `git pull` for each fix |
| **The guild** | Make the repo public, then share `https://github.com/alfakaboom-create/Motion-Forever/releases/latest`. It always points to the newest version |
| **Auto-updates** | Guildies can add the repo URL to **WowUp**, which installs new releases automatically. Check that WowUp supports the `_forever_` client first |
| **Everyone, later** | Publish on CurseForge or Wago |

A public repo shows the commit author email to anyone.

---

# Launch testing

The step-by-step checklist is in [docs/LAUNCH-TESTING.md](docs/LAUNCH-TESTING.md).
It covers 54 checks across loading, your position, messages between two
players, map dots, the guild list window, settings, situations like
combat and dungeons, and layers.

Already done:

- [x] **Addon folder path:** `_forever_\Interface\AddOns`, linked with `link-addon.ps1`.
- [x] **Interface number:** the `.toc` uses `16001`, from the installed
      client (version 1.60.1). If the game lists the addon as out of date
      after a patch, run `/run print(select(4, GetBuildInfo()))` in game
      and put that number in `## Interface:`.
