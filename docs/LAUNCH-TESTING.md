# Launch testing checklist

Everything to check in game once WoW Forever launches. Work top to bottom:
each part builds on the one before it.

**You'll need:**
- **A second player** in your guild running Motion-Forever: a guildie, or a
  second account. Two characters on the same account can't be online at once.
- **BugSack and BugGrabber** (recommended). They catch Lua errors quietly, so
  you can copy them out.

**When something fails,** note the test number. Copy the chat output or the
BugSack error (type `/bugsack`) and send it over. Most launch fixes will be
in `Compat.lua`.

---

## A. Loading (on your own)

| # | Do this | Expected |
|---|---|---|
| A1 | At character select, open **AddOns** | Motion-Forever is listed, ticked, and **not** marked "out of date" |
| A2 | Log in | No error pop-up, and nothing in BugSack |
| A3 | `/mforever help` | Lists the commands |
| A4 | `/reload` | Still no errors |

If A1 says "out of date": run `/run print(select(4, GetBuildInfo()))` and
send the number. Until it's fixed, tick "Load out of date AddOns" to carry on.

## B. Your position (on your own)

| # | Do this | Expected |
|---|---|---|
| B1 | `/mforever status` in a town or the open world | Shows your zone name, map number, and coordinates |
| B2 | Walk a bit, run `/mforever status` again | The coordinates change |
| B3 | Compare with the world map's coordinates, or another addon's | Roughly the same numbers |
| B4 | Enter a dungeon, `/mforever status` | Shows the dungeon, with position "hidden". No errors |

## C. Messages between two players

Both players: `/mforever debug on`.

| # | Do this | Expected |
|---|---|---|
| C1 | Both run `/mforever ping` | Within a few seconds, each runs `/mforever list` and sees the other |
| C2 | Check guild chat | **Nothing visible.** The messages are hidden |
| C3 | Player 2 walks around for 30 seconds; Player 1 runs `/mforever list` a few times | The coordinates update, and the "seconds ago" stays under about 15 |
| C4 | Player 2 runs `/reload` | Player 2 shows up again on Player 1's list within about 10 seconds |
| C5 | Player 2 logs out | Player 2 disappears from Player 1's list, at once or within 45 seconds |
| C6 | Look for debug lines saying "send failed" | None in the open world |

If C1 fails, this is the most important problem to fix, because nothing else
works without messages. Send the debug output from both players.

## D. World map dots

| # | Do this | Expected |
|---|---|---|
| D1 | Same zone. Player 1 opens the world map | A class-colored dot where Player 2 stands |
| D2 | Hover over the dot | Tooltip with name, level, layer and zone |
| D3 | Player 2 walks while the map is open | The dot moves every few seconds; the tooltip doesn't flicker |
| D4 | Zoom the map out to the continent | The dot is still there, in the right spot |
| D5 | Zoom out to the whole world map | Note whether the dot shows. It may not, which is expected |
| D6 | Player 2 goes to a different zone | The dot appears on that zone's map |
| D7 | Player 2 enters a dungeon | The dot disappears. `/mforever list` still shows them, "no exact position" |
| D8 | Check the dot's look | Visible, round, with a dark outline, and not hidden under other icons. Note if it looks wrong |
| D9 | Right-click the empty map | The map still zooms out as normal |

## E. Guild list window

| # | Do this | Expected |
|---|---|---|
| E1 | `/mforever` | The window opens, with Name, Level, Zone, Layer and Status columns |
| E2 | Look at Player 2's row | Class-colored name, correct level and zone, "On map" |
| E3 | Look at guildies without the addon | Listed below in grey, with "No addon" |
| E4 | Untick "Show members without addon" | They disappear; the footer count changes |
| E5 | Click Name, Level, Zone headers, twice each | The order changes, and reverses on the second click; the arrow shows the direction |
| E6 | `/reload`, reopen | The sort and the checkbox are remembered |
| E7 | Player 2 enters a dungeon | Their zone shows "(dungeon)", and the status "Position hidden" |
| E8 | Leave the window open while people move and log in or out | It updates by itself |
| E9 | Drag the title bar | The window moves |
| E10 | Press Escape; also try the X button | The window closes |
| E11 | Large guild only: scroll the list | Scrolls smoothly, and the scrollbar works |
| E12 | Run `/mforever` again | The window toggles closed or open |

## F. Settings and privacy

| # | Do this | Expected |
|---|---|---|
| F1 | Player 2 runs `/mforever share off` | Player 2 disappears from Player 1's map and list |
| F2 | Player 2 runs `/mforever share on` | Player 2 reappears within a few seconds |
| F3 | Player 1 runs `/mforever show off` | All dots disappear from Player 1's map |
| F4 | Player 1 runs `/mforever show on` | The dots come back |
| F5 | `/reload` | Settings are kept |

## G. Situations to try

| # | Do this | Expected |
|---|---|---|
| G1 | Fight a mob while the other player moves | No errors. Dots may pause during combat; note it if they do |
| G2 | Go through a loading screen (portal, boat, flight path) | Your position resumes sharing shortly after |
| G3 | Join a party with Player 2 | Both the normal party dot and the Motion-Forever dot show. Note if that's confusing |
| G4 | Play for an hour with the addon on | No slowdown, no errors piling up in BugSack |
| G5 | A busy guild evening, if possible | Note whether `/mforever list` and the window stay responsive |

## H. Layers

First check the server has layers at all: two players in the same spot who
can't see each other are on different layers. If Forever has no layers,
everyone should always show "Same".

| # | Do this | Expected |
|---|---|---|
| H1 | In the open world, target any NPC, then `/mforever status` | "Your layer:" shows two numbers, like `0-1234`. If it stays "unknown", send the output: the game may be hiding NPC IDs |
| H2 | Both players stand together and can see each other | Hovering the dot says "Same layer as you"; the guild list says "Same" |
| H3 | Get onto different layers (for example, one joins a group led by someone on another layer) | Within a few seconds of seeing an NPC: "Different layer" / "Different" |
| H4 | Player 2 enters a dungeon | Player 1 sees "Layer unknown" for them |
| H5 | Players on different continents | "Layer unknown". This is expected |
| H6 | Fight NPCs for a while | No errors in BugSack |

---

## After testing

- **Everything passed:** share it with the guild (see the README).
- **Something failed:** send the test numbers and errors, and I'll fix them.
- **Worth noting either way:** anything that looked odd, even if it didn't
  fail outright. Dot size, colors, the window layout, and wording are all
  easy to adjust.
