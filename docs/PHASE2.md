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
| Ask for the list | `QREQ` | nothing |
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

## Suggestions to consider

These are extra ideas from planning, not part of your list. Keep or drop
them as you like.

- **A guild list window** showing everyone with the addon, their zone, and
  how many quests they can share with you. It would work without opening the
  map, and is useful for people in dungeons.
- **Find quests you can get:** ask every guild member at once and show one
  combined list grouped by who has each quest.

---

## Still to do from phase 1

- [ ] Minimap dots
- [ ] Settings panel (only slash commands for now)

## Questions to answer after launch

- [ ] Do quest functions work outside instances, under Midnight's addon restrictions?
- [ ] Can the requester's addon auto-accept a shared quest?
- [ ] Does the quest log give a zone for every quest, or only a category name?
- [ ] How long does the game need between shares to avoid errors?
