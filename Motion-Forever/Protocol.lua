-- Protocol: turns data into addon-message strings and back.
-- No game API calls in here, so it can be unit tested outside WoW.
-- The full message format is documented in docs/PROTOCOL.md.

local _, ns = ...

local Protocol = {}
ns.Protocol = Protocol

Protocol.PREFIX = "MotionForever"   -- max 16 characters
Protocol.VERSION = 1
Protocol.MAX_LENGTH = 255         -- WoW's limit for one addon message
Protocol.SEP = ";"

-- Message types. Phase 1 uses HELLO, POS and BYE.
-- The Q* types are reserved for phase 2 (quest sharing). Clients ignore
-- types they don't handle, so phase 1 and phase 2 users can mix freely.
Protocol.MSG = {
	HELLO = "HELLO",   -- "I just came online, please send me your position"
	POS = "POS",       -- my position and basic info
	BYE = "BYE",       -- "stop showing me" (logout or sharing turned off)

	QREQ = "QREQ",     -- phase 2: "which quests can you share?" (whisper)
	QLIST = "QLIST",   -- phase 2: list of shareable quest IDs (whisper)
	QASK = "QASK",     -- phase 2: "please share quest X with me" (whisper)
	QREPLY = "QREPLY", -- phase 2: accepted / declined / failed (whisper)
}

-- Capability letters sent in POS.
Protocol.CAPS = {
	QUESTS = "Q",      -- phase 2: supports QREQ / QLIST / QASK
}

local SEP = Protocol.SEP
local COORD_SCALE = 10000 -- 0.0001 of a map, about 1 yard in a typical zone

---------------------------------------------------------------------------
-- Generic encode / decode
---------------------------------------------------------------------------

-- Encode("POS", a, b, c) -> "1;POS;a;b;c". nil fields become empty.
function Protocol.Encode(msgType, ...)
	local parts = { tostring(Protocol.VERSION), msgType }
	for i = 1, select("#", ...) do
		local value = select(i, ...)
		if value == nil then value = "" end
		value = tostring(value)
		if value:find(SEP, 1, true) then
			return nil, "field contains separator"
		end
		parts[#parts + 1] = value
	end
	local msg = table.concat(parts, SEP)
	if #msg > Protocol.MAX_LENGTH then
		return nil, "message too long"
	end
	return msg
end

-- Returns version, msgType, fields (a list of strings), or nil if invalid.
-- Extra fields from newer versions are kept, so callers can ignore them.
function Protocol.Decode(msg)
	if type(msg) ~= "string" or msg == "" then return nil end

	local parts = {}
	local start = 1
	while true do
		local i = msg:find(SEP, start, true)
		if not i then
			parts[#parts + 1] = msg:sub(start)
			break
		end
		parts[#parts + 1] = msg:sub(start, i - 1)
		start = i + 1
	end

	local version = tonumber(parts[1])
	local msgType = parts[2]
	if not version or version < 1 or not msgType or msgType == "" then
		return nil
	end

	local fields = {}
	for i = 3, #parts do fields[#fields + 1] = parts[i] end
	return version, msgType, fields
end

---------------------------------------------------------------------------
-- Coordinates: 0..1 map positions sent as whole numbers 0..10000
---------------------------------------------------------------------------
function Protocol.PackCoord(value)
	if value == nil then return nil end
	local n = math.floor(value * COORD_SCALE + 0.5)
	if n < 0 then n = 0 elseif n > COORD_SCALE then n = COORD_SCALE end
	return n
end

function Protocol.UnpackCoord(text)
	local n = tonumber(text)
	if not n or n < 0 or n > COORD_SCALE then return nil end
	return n / COORD_SCALE
end

---------------------------------------------------------------------------
-- POS: mapID;x;y;class;level;caps
-- x and y are empty when the position is unknown (for example inside a
-- dungeon), so others can still show which zone the player is in.
---------------------------------------------------------------------------
function Protocol.EncodePos(p)
	return Protocol.Encode(Protocol.MSG.POS,
		p.mapID,
		Protocol.PackCoord(p.x),
		Protocol.PackCoord(p.y),
		p.class,
		p.level,
		p.caps)
end

function Protocol.DecodePos(fields)
	local x = Protocol.UnpackCoord(fields[2])
	local y = Protocol.UnpackCoord(fields[3])
	if not (x and y) then x, y = nil, nil end

	local class = fields[4]
	if class == "" then class = nil end

	return {
		mapID = tonumber(fields[1]),
		x = x,
		y = y,
		class = class,
		level = tonumber(fields[5]),
		caps = fields[6] or "",
	}
end
