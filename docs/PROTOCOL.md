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
| `POS` | `mapID;x;y;class;level;caps` | My position. `x` and `y` are whole numbers from 0 to 10000 (0.0001 of the map each). They're empty when the position is hidden, for example in dungeons. |
| `BYE` | none | "Stop showing me": I logged out or turned sharing off. |

Example: `1;POS;1429;4512;6230;MAGE;12;` is a level 12 mage in Elwynn Forest
(map 1429), at 45.1, 62.3.

### Timing

- `POS` is sent at most every `minInterval` seconds (default 3) while you
  move, and every `heartbeat` seconds (default 15) while you stand still.
- A member is dropped from the map after `heartbeat × 3` seconds (default 45)
  with no messages from them.

## Phase 2 messages (reserved, not yet implemented)

These are sent by WHISPER, one to one, and only to players whose `caps`
contain `Q`.

| Type | Fields (planned) | Meaning |
|---|---|---|
| `QREQ` | none | "Which quests can you share?" |
| `QLIST` | `part;total;id,id,id...` | Quest IDs I can share, split across several messages if it's too long for one |
| `QASK` | `questID` | "Please share this quest with me." The other player sees a popup to accept or decline. |
| `QREPLY` | `questID;status` | `status` is `ok`, `declined`, `busy` or `failed` |

Planned flow:

1. Hover over a dot. If they have `Q`, send `QREQ`.
2. They reply with `QLIST`. Hide quests you've completed or already have.
3. Show "N quests available" in the tooltip.
4. Click to choose a quest and send `QASK`.
5. They see a popup and click Invite & Share. The game requires that click
   before an addon can invite someone.
6. They invite you to a party, share the quest, then send `QREPLY`.
