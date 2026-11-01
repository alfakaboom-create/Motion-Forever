# Phase 2 plan: quest sharing

Ideas and design notes for phase 2. Nothing here is built yet.

Phase 1 (the map dots) comes first, because phase 2 builds on it: you start
a quest request from a guild member's dot, and it uses the same messaging.

---

## Ideas

### 1. See and request a guild member's shareable quests

> See which shareable quests a guildie has that you can take, request one,
> and get a click-to-share popup.

### 2. Choose which quests to request

> The person requesting can select which quests they'd like shared. A UI is
> shown to them with the quest details (level, zone), and they use checkboxes
> to request specific quests.

### 3. Guild list window

> A window listing everyone with the addon, their zone, and how many quests
> they can share with you. It works without opening the map, and helps with
> people who are in dungeons.

### 4. Find quests I can get (whole guild)

> Ask every guild member at once, and show one combined list grouped by who
> has each quest.

---

## How it would work

### For the person asking (the requester)

1. **Open the guild member's quests.** Click their dot on the world map.
   - Hovering first shows a summary in the tooltip, for example "4 quests
     you can get".
2. **A quest window opens** with one row per shareable quest:

   | ☐ | Quest | Level | Zone |
   |---|---|---|---|
   | ☑ | The Fargodeep Mine | 7 | Elwynn Forest |
   | ☐ | Bounty on Murlocs | 9 | Elwynn Forest |
   | ☑ | Red Linen Goods | 6 | Westfall |

   - **Level is colored by difficulty**, like the game's quest log: grey,
     green, yellow, orange, red.
   - **Hidden:** quests you've already completed or already have.
   - **Sorted** by zone, then level.
3. **Tick the quests you want** and click **Request selected**.
4. **When the guild member agrees:** you're invited to their party
   automatically, and each quest you picked is accepted for you as it
   arrives. Quests you didn't pick aren't auto-accepted.

### For the guild member being asked (the sharer)

1. **One popup per request**, even when it's for several quests:
   > **Jade** would like 2 quests: *The Fargodeep Mine*, *Red Linen Goods*
   > [Invite & Share] [Decline]
2. **Clicking Invite & Share:** the addon invites the requester, waits for
   them to join, then shares each quest a moment apart.
3. **Optional:** leave the group automatically afterwards. This would be a
   setting, off by default.

### Messages between the two copies of the addon

These are whispers, so only the two people involved see them.

| Step | Message | Contents |
|---|---|---|
| Ask one person for their list | `QREQ` (whisper) | nothing |
| Ask the whole guild (idea 4) | `QREQ` (guild) | nothing. Everyone with quests to share whispers back a `QLIST` |
| Reply with the list | `QLIST` | part number, total parts, then each quest as `id:level:zone` |
| Ask for chosen quests | `QASK` | the chosen quest IDs |
| Answer | `QREPLY` | per quest: shared, declined, not eligible, or failed |

**Sizes:** a full quest log fits in about 3 messages. Each entry is about 15
characters, and the game allows 255 per message.

**Quest names aren't sent:** the requester's game looks them up itself, which
keeps messages short and shows names in the requester's own language.
Phase 1 already reserves all four message types (see [PROTOCOL.md](PROTOCOL.md)).

---

## What the game allows

| Need | Possible? | Notes |
|---|---|---|
| List the sharer's shareable quests | ✅ | The game has a built-in "can this quest be shared" check |
| Quest level and zone | ✅ | The sharer's quest log has both. The sharer sends them, since the requester's game may not know a quest they've never seen |
| Hide quests the requester completed | ✅ | The game can tell an addon if a quest was completed |
| Hide quests already in the requester's log | ✅ | |
| Hide quests the requester can't take yet (level, class, earlier quests in a chain) | ⚠️ Partly | The game usually doesn't say this in advance. Level coloring catches the obvious cases, and the share attempt itself reports "not eligible" for the rest |
| Share without a party | ❌ | The game only shares quests with party members, so the invite step is required |
| Invite without the sharer clicking | ❌ | Blizzard requires a click, which the Invite & Share button provides |
| Share several quests in a row | ✅ | One at a time, with a short delay between each |
| Auto-accept requested quests | ⚠️ Probably | Auto-accept addons exist today. Confirm it still works under Midnight's restrictions |

---

## Situations to handle

- **The sharer's party is full** (5 players). Tell the requester instead of
  failing silently.
- **The requester is already in another group.** They must leave it first;
  the window should say so.
- **The sharer is in combat or a dungeon.** Delay or decline the request.
- **The quest list changes** between the list and the request. The game
  reports "not eligible" or "failed", which goes back in `QREPLY`.
- **Too many requests.** Add a cooldown per requester, and a sharer setting
  to allow requests from everyone or no one.
- **One side has an older version of the addon.** Only show quest features
  for guild members whose addon advertises quest support. Phase 1 already
  sends this flag.

---

## Guild list window (idea 3)

Opened with `/mforever` or a minimap button, so it works without the map.

| Name | Level | Zone | Quests for you | |
|---|---|---|---|---|
| **Ann** (priest) | 12 | Westfall | 3 | [View] |
| **Bob** (warrior) | 20 | The Deadmines (dungeon) | 1 | [View] |
| **Cid** (mage) | 9 | Elwynn Forest | – | [View] |
| *Dee* | 15 | Redridge Mountains | *no addon* | |

- **Everyone with the addon is listed,** using what phase 1 already
  tracks. That includes people in dungeons, who have no dot on the map.
- **Guild members without the addon** can be shown greyed out, with their
  zone from the guild roster. This shows who to ask to install it. It could
  be a setting, since big guilds may find the list long.
- **"Quests for you"** is filled in once their quest list has been fetched:
  a number, or "–" if they have none for you.
- **View** opens the same quest selection window as clicking their map dot.
- **Sortable** by name, level or zone. Name colored by class.

**Data:** mostly already exists in phase 1, so this window could be built
first, even before the rest of phase 2.

---

## Find quests I can get (idea 4)

A **Search guild** button, in the guild list window, asks everyone at once
and shows one combined list:

| ☐ | Quest | Level | Zone | Who has it |
|---|---|---|---|---|
| ☑ | The Fargodeep Mine | 7 | Elwynn Forest | Ann, Cid |
| ☐ | The Defias Brotherhood | 14 | Westfall | Bob |

- **Grouped by quest**, with everyone who can share it listed, so the same
  quest appears only once.
- **Picking who shares:** each requested quest goes to one person. Prefer
  someone in the same zone as you, then someone not in a dungeon. You can
  also pick a name yourself.
- **Several sharers at once:** if the ticked quests come from different
  people, each of them gets their own popup. You can only be in one party at
  a time, so the requests run one person after another.

**How it works:** one `QREQ` goes out as a hidden addon message on the guild
channel; players never see it in guild chat. It includes your level. Everyone
with shareable quests near your level whispers a `QLIST` back, after a random
delay so the replies don't all arrive at once. Players with nothing to share
don't reply.

### Traffic safeguards

One search is a short burst: 1 guild message, then about 3 whispered replies
per guild member with quests to share. Only the person searching receives the
replies, and no one sends more than the game allows at once. For comparison,
it's less than one minute of phase 1's normal map traffic. These safeguards
keep it that way:

| Safeguard | Enforced by | Why |
|---|---|---|
| **Repliers ignore a repeat search** from the same person within 60 seconds | Every replying copy of the addon | Stops spam, even from a modified or broken addon. A limit only on the searcher's side wouldn't be enough |
| **The search includes the searcher's level**, and repliers only send quests near it, roughly within 5 levels | Replier | Cuts most of the replies. A level 60's quests are no use to a level 10 |
| **The reply delay grows with guild size**: up to about 5 seconds when few people run the addon, up to about 20 seconds for a large guild | Replier, based on how many addon users it knows are online | Spreads replies out so they don't arrive in one burst |
| **One guild search at a time**, at most one per minute | Searcher | No overlapping searches |
| **Results kept for about a minute** | Searcher | Reopening the window doesn't search again |

In a large guild, results fill in over several seconds instead of all at
once, and the window should show this ("Searching… 12 replies so far").

The level range and delays above are starting values to tune after testing.

---

## Caching quest lists

Ideas 1, 3 and 4 all use the same lists, so each guild member's list is kept
for about a minute after it's fetched. It's fetched again when:

- the window is opened after that minute, or
- you click **Refresh**.

Each guild member's entry already has a `quests` slot reserved for this in
phase 1.

---

## Suggested build order

1. ✅ **Guild list window** (idea 3, without the quests column). Built on the
   `phase2-guild-list` branch, not yet tested in game. The Quests column and
   View button are added in steps 2–3, through `GuildList.columns` and the
   `GUILDLIST_ROW_CLICK` event.
2. **Quest lists between two people** (`QREQ` / `QLIST`), shown in the
   map tooltip and the guild list.
3. **Quest selection window** (idea 2).
4. **Request and share flow** (idea 1): popup, invite, share, auto-accept.
5. **Guild-wide search** (idea 4), reusing steps 2–4.

---

## Still to do from phase 1

- [ ] Minimap dots
- [ ] Settings panel (only slash commands for now)

## Questions to answer after launch

- [ ] Do quest functions work outside instances, under Midnight's addon restrictions?
- [ ] Can the requester's addon auto-accept a shared quest?
- [ ] Does the quest log give a zone for every quest, or only a category name?
- [ ] How long does the game need between shares to avoid errors?
