# Motion-Forever

A World of Warcraft addon for **WoW Forever** that shows your guild members
on the world map, the way party members are shown.

> **Status: first pass, untested in game.** The WoW Forever client isn't out
> yet. This version is written against the modern Retail (Midnight) addon
> system, which Forever is reported to use. See [Launch checklist](#launch-checklist).

## How it works

The game only sends exact positions for people in your party, so
Motion-Forever shares them itself:

1. Every few seconds, each copy of the addon sends its player's position to
   the guild as a hidden addon message.
2. Every copy listens for those messages and draws a class-colored dot for
   each guild member on the world map.

**Only guild members who also run Motion-Forever appear on the map.**

## Features

- [x] Guild members shown on zone and continent maps, colored by class
- [x] Tooltip on hover: name, level and zone
- [x] Members in dungeons are still listed in `/mforever list`, without an exact position
- [x] Option to stop sharing your position
- [x] Guild list window (`/mforever`): everyone online with the addon, their
      level, zone and status, sortable. It can also list guild members
      without the addon
- [ ] Minimap dots
- [ ] Settings panel (only slash commands for now)
- [ ] **Phase 2:** see which quests a guild member can share with you, pick the
      ones you want, and request them. See [docs/PHASE2.md](docs/PHASE2.md)

## Commands

| Command | What it does |
|---|---|
| `/mforever` | Opens or closes the guild list window |
| `/mforever list` | Lists tracked guild members with zone and position, in chat |
| `/mforever help` | Lists all commands |
| `/mforever share on\|off` | Turns sharing your position on or off |
| `/mforever show on\|off` | Shows or hides guild members on your map |
| `/mforever ping` | Asks everyone to send their position now |
| `/mforever status` | Shows your settings and your current position |
| `/mforever debug on\|off` | Prints extra messages, useful for testing |

## Project layout

```
Motion-Forever/             <- repo root
├─ Motion-Forever/          <- the addon itself (this folder goes in Interface\AddOns)
│  ├─ Motion-Forever.toc    addon info and file load order
│  ├─ Core.lua              shared setup, settings, internal events
│  ├─ Protocol.lua          message format (no game calls, unit tested)
│  ├─ Roster.lua            who's online and where (no game calls, unit tested)
│  ├─ Compat.lua            every game API call that might differ on Forever
│  ├─ Comm.lua              sending and receiving messages
│  ├─ Position.lua          when to send your position
│  ├─ MapPins.lua/.xml      the dots on the world map
│  ├─ GuildListData.lua     guild list rows and sorting (unit tested)
│  ├─ GuildListUI.lua       the guild list window
│  └─ Commands.lua          /mforever
├─ tests/run.lua            unit tests, run outside the game
├─ scripts/                 link-addon.ps1 and package.ps1
└─ docs/
   ├─ PROTOCOL.md           message format, including phase 2 messages
   └─ PHASE2.md             phase 2 ideas and design (quest sharing)
```

## Built with phase 2 in mind

Phase 2 (quest sharing) can be added as new files without rewriting phase 1:

- **Message types `QREQ`, `QLIST`, `QASK`, `QREPLY` are already reserved.**
  Phase 1 clients ignore them, so people on old and new versions can mix.
- **Capability letters.** A phase 2 client advertises `Q`, so it only
  sends quest requests to players who can answer them.
- **One-to-one messages.** `Comm:Whisper()` is already there for quest
  requests.
- **Hooks on the map dots.** The `PIN_TOOLTIP` and `PIN_CLICK` events let
  the quest module add lines to the tooltip and open a menu when a dot is
  clicked.
- **Space in each guild member's entry.** Each entry has an `entry.quests`
  field reserved for phase 2.

---

# Working with git

## One-time setup

1. **Tell git who you are**, if you haven't already:
   ```bash
   git config --global user.name "Your Name"
   ```
   ```bash
   git config --global user.email "you@example.com"
   ```
2. **Optional: put it on GitHub** for a backup and easy sharing. Create an
   empty repository on github.com, then:
   ```bash
   git remote add origin https://github.com/<you>/Motion-Forever.git
   ```
   ```bash
   git push -u origin main
   ```

## Testing in game straight from the repo

Link the repo's addon folder into WoW once. The game then loads your working
copy directly, so you don't need to copy files:

```powershell
.\scripts\link-addon.ps1 -WowPath "C:\Program Files (x86)\World of Warcraft\_forever_"
```

Use the folder that contains `Interface`. For WoW Forever, that's `_forever_`.

After that, the loop is: **edit → `/reload` in game → check**.

To catch errors, install **BugSack** + **BugGrabber**.

## Day-to-day workflow

| You want to... | Command |
|---|---|
| See what changed | `git status`, then `git diff` |
| Save a checkpoint | `git add -A` then `git commit -m "Describe the change"` |
| Try something risky | `git switch -c phase2-quests` (a new branch) |
| Go back to the main version | `git switch main` |
| Undo uncommitted changes to a file | `git restore <file>` |
| Upload to GitHub | `git push` |

A simple habit: keep `main` working, and do each feature on its own branch.
Merge the branch into `main` once it works in game.

## Releasing a version

1. Bump `## Version:` in `Motion-Forever/Motion-Forever.toc`, and `ns.VERSION` in `Core.lua`.
2. Commit, then tag it: `git tag v0.1.0`, then `git push --tags`.
3. Build the zip: `.\scripts\package.ps1` creates `dist\Motion-Forever-0.1.0.zip`.
4. Share the zip, or attach it to a GitHub Release.

## Unit tests

The message format, the guild member tracking and the "when to send" logic
can be tested without the game. You need Lua (5.1 or newer) installed:

```bash
lua tests/run.lua
```

---

# Launch checklist

Things that can only be confirmed once the WoW Forever client is out:

- [ ] **Interface number.** The `.toc` uses `16001`, based on the installed
      client (version 1.60.1). If the game lists the addon as out of date
      after a patch, run `/run print(select(4, GetBuildInfo()))` in game
      and put that number in `## Interface:`.
- [x] **Addon folder path.** `_forever_\Interface\AddOns`, linked with `link-addon.ps1`.
- [ ] **Messages get through.** With a second character in the same guild,
      run `/mforever debug on`, then `/mforever ping`. Each should show up in
      the other's `/mforever list`.
- [ ] **Your position can be read.** `/mforever status` should show
      coordinates in the open world.
- [ ] **Dots appear on the world map**, on both the zone and continent maps.
- [ ] **Behavior in dungeons and combat.** Midnight added restrictions for
      addons. Check what still works.
- [ ] If anything fails, start with `Compat.lua`.
