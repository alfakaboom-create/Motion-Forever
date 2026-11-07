# Motion-Forever message protocol

Every copy of Motion-Forever talks to the others with hidden addon messages.
Players never see them in chat.

- **Prefix:** `MotionForever`
- **Format:** `<version>;<type>;<field1>;<field2>;...`
- **Max length:** 255 characters per message
- **Current version:** `1`

## Rules for compatibility

These rules let people on old and new versions of the addon play together.

1. **Unknown message types are ignored.** For example, a phase 1 client
   ignores the phase 2 `Q*` messages.
2. **Extra fields at the end are ignored.** New versions add fields only at
   the end of a message, and never change what existing fields mean.
3. **Empty fields are allowed** and mean "unknown".
4. **Capabilities** are letters in the `caps` field of `POS`. Check for a
   letter before sending a feature's messages to someone, for example `Q`
   before sending `QREQ`.

## Phase 1 messages (GUILD channel)

| Type | Fields | Meaning |
|---|---|---|
| `HELLO` | none | "I just came online." Everyone replies with `POS` within about 3 seconds, at a random time so replies don't all arrive at once. |
| `POS` | `mapID;x;y;class;level;caps;layer` | My position. `x` and `y` are whole numbers from 0 to 10000 (0.0001 of the map each). They're empty when the position is hidden, for example in dungeons. `layer` is empty when unknown, and missing from older versions. |
| `BYE` | none | "Stop showing me": I logged out or turned sharing off. |

Example: `1;POS;1429;4512;6230;MAGE;12;` is a level 12 mage in Elwynn Forest
(map 1429), at 45.1, 62.3, on an unknown layer.

### The layer field

`layer` is `zoneMapID:zoneUID`, for example `1429:1234`. `zoneUID` is read
from the hidden ID of nearby NPCs (see `Layer.lua`). It differs per zone
as well as per layer, so it's tagged with the zone it was read in. The
numbers mean nothing on their own: two players are on the same layer when
their keys match, and keys from different zones can't be compared. Each
player's key is the most common one among their last few NPC readings.

It's empty in instances, right after a loading screen or group change,
and until the player has seen an NPC. A change of layer sends a `POS`
within a few seconds.

Versions before this fix sent `continent-zoneUID` (for example `0-1234`).
Those keys could wrongly say "different layer", so newer versions ignore
them and show that player's layer as unknown.

### Timing

- `POS` is sent at most every `minInterval` seconds (default 3) while you
  move, and every `heartbeat` seconds (default 15) while you stand still.
- A member is dropped from the map after `heartbeat × 3` seconds (default 45)
  with no messages from them.

## Phase 2 messages (reserved, not yet implemented)

These are sent by WHISPER, one to one, and only to players whose `caps`
contain `Q`. The one exception is a guild-wide search: `QREQ` sent on the
GUILD channel asks everyone at once. Each player with shareable quests near
the searcher's level then whispers a `QLIST` back after a random delay: up to
about 5 seconds in a small guild, up to about 20 seconds in a large one.
Players with nothing to share stay silent, and a repeat guild `QREQ` from the
same player within 60 seconds is ignored. See "Traffic safeguards" in
[PHASE2.md](PHASE2.md).

| Type | Fields (planned) | Meaning |
|---|---|---|
| `QREQ` | `level` | "Which quests can you share?" `level` is the requester's level, so the replier can leave out quests far from it |
| `QLIST` | `part;total;id:level:zone,...` | Quests I can share, split across several messages if it's too long for one |
| `QASK` | `id,id,...` | "Please share these quests with me": one or more quests the requester ticked. The other player sees one popup to accept or decline. |
| `QREPLY` | `id:status,...` | `status` per quest: `ok`, `declined`, `busy`, `ineligible` or `failed` |

The full flow, the quest selection window, and the cases to handle are in
[PHASE2.md](PHASE2.md).
