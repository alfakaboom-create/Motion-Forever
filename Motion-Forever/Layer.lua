-- Layer: works out which layer (copy of the world) we're on, and compares
-- it with guild members' layers.
--
-- The game has no "which layer am I on" function. Every NPC's hidden ID
-- (GUID) looks like Creature-0-server-continent-zoneUID-npcID-spawnUID.
-- zoneUID names the server piece running that NPC's zone on our layer.
-- It is NOT one number per layer: each zone (or group of zones) has its
-- own. So a reading only means something together with the zone it was
-- taken in, and two players can only be compared when their readings come
-- from the same zone.
--
-- A layer key is "zoneMapID:zoneUID", for example "1429:1234". The numbers
-- mean nothing on their own; keys can only be compared with each other.
--
-- One odd NPC (for example across a zone border) shouldn't flip our layer,
-- so we keep the last few readings and go with the most common one.
--
-- The functions at the top are pure (no game calls) so they can be tested.

local _, ns = ...

local Layer = {
	mine = nil,     -- our layer key, or nil while unknown
	readings = {},  -- recent readings, oldest first: { key = "1429:1234", guid = "..." }
}
ns.Layer = Layer

Layer.MAX_READINGS = 9

local UNIT_TYPES = { Creature = true, Vehicle = true }

-- Returns the layer key for an NPC's GUID seen in zone zoneID, or nil.
function Layer.KeyFromGUID(guid, zoneID)
	if type(guid) ~= "string" or type(zoneID) ~= "number" or zoneID <= 0 then return nil end
	local unitType, zoneUID = guid:match("^(%a+)%-0%-%d+%-%d+%-(%d+)%-%d+%-")
	if not unitType or not UNIT_TYPES[unitType] or zoneUID == "0" then return nil end
	return string.format("%d:%s", zoneID, zoneUID)
end

-- True if text looks like a layer key. Used to check incoming messages.
-- Keys from older copies of the addon ("0-1234") don't match on purpose:
-- they can't be compared safely.
function Layer.IsKey(text)
	return type(text) == "string" and text:match("^%d+:%d+$") ~= nil
end

local function zoneOf(key)
	return key:match("^(%d+):")
end

-- Returns "same" or "different" when it can be told. Otherwise says why
-- not: "mine-unknown" (we haven't found our layer yet), "theirs-unknown"
-- (they haven't, or they run an older copy), or "elsewhere" (our readings
-- come from different zones, so they can't be compared).
function Layer.Compare(mine, theirs)
	if not Layer.IsKey(mine) then return "mine-unknown" end
	if not Layer.IsKey(theirs) then return "theirs-unknown" end
	if zoneOf(mine) ~= zoneOf(theirs) then return "elsewhere" end
	return mine == theirs and "same" or "different"
end

-- Adds a reading. The same NPC only counts once, and only the newest
-- `max` readings are kept.
function Layer.AddReading(readings, key, guid, max)
	for i = #readings, 1, -1 do
		if readings[i].guid == guid then table.remove(readings, i) end
	end
	readings[#readings + 1] = { key = key, guid = guid }
	while #readings > max do table.remove(readings, 1) end
end

-- Picks our layer from the readings: only readings from the zone of the
-- newest one count, and the most common key wins. On a tie, the key seen
-- most recently wins.
function Layer.Pick(readings)
	local newest = readings[#readings]
	if not newest then return nil end
	local zone = zoneOf(newest.key)

	local counts, lastSeen = {}, {}
	for i, reading in ipairs(readings) do
		if zoneOf(reading.key) == zone then
			counts[reading.key] = (counts[reading.key] or 0) + 1
			lastSeen[reading.key] = i
		end
	end

	local best
	for key, count in pairs(counts) do
		if not best or count > counts[best] or (count == counts[best] and lastSeen[key] > lastSeen[best]) then
			best = key
		end
	end
	return best
end

-- "1429:1234 x7, 1429:5678 x1", for /mforever layer.
function Layer.Summary(readings)
	local counts, order = {}, {}
	for _, reading in ipairs(readings) do
		if not counts[reading.key] then order[#order + 1] = reading.key end
		counts[reading.key] = (counts[reading.key] or 0) + 1
	end
	local parts = {}
	for _, key in ipairs(order) do parts[#parts + 1] = key .. " x" .. counts[key] end
	return table.concat(parts, ", ")
end

local GREEN = { 0.25, 1, 0.25 }
local ORANGE = { 1, 0.5, 0.25 }
local GREY = { 0.6, 0.6, 0.6 }

-- Text and color for a Compare() result. `short` is for the guild list.
function Layer.Describe(state, short)
	if state == "same" then
		return short and "Same" or "Same layer as you", unpack(GREEN)
	elseif state == "different" then
		return short and "Different" or "Different layer", unpack(ORANGE)
	elseif state == "mine-unknown" then
		return short and "Unknown" or "Layer unknown: target any NPC", unpack(GREY)
	elseif state == "theirs-unknown" then
		return short and "Unknown" or "Their layer isn't known yet", unpack(GREY)
	elseif state == "elsewhere" then
		return short and "Other zone" or "In another zone: can't compare", unpack(GREY)
	end
	return short and "Unknown" or "Layer unknown", unpack(GREY)
end

---------------------------------------------------------------------------
-- Detecting our own layer (game calls go through Compat)
---------------------------------------------------------------------------
function Layer:Set(key)
	if key == self.mine then return end
	self.mine = key
	ns.Debug("layer", key or "unknown")
	ns.Fire("LAYER_CHANGED", key)
end

function Layer:Observe(unit)
	if not ns.Compat.IsInOpenWorld() then return end
	local key, guid = ns.Compat.GetUnitLayer(unit, ns.Compat.GetPlayerZoneMapID())
	if not key then return end
	Layer.AddReading(self.readings, key, guid, Layer.MAX_READINGS)
	self:Set(Layer.Pick(self.readings))
end

-- Units worth checking besides nameplates: current target, what the mouse
-- is over, and the soft targets used by action targeting.
local NEARBY_UNITS = { "target", "mouseover", "focus", "softenemy", "softfriend", "softinteract" }

-- Checks every NPC we can currently see.
function Layer:ScanAround()
	for _, unit in ipairs(NEARBY_UNITS) do
		self:Observe(unit)
	end
	for _, unit in ipairs(ns.Compat.GetNameplateUnits()) do
		self:Observe(unit)
	end
end

-- After something that may move us to another layer, forget the old
-- readings, then look again at what's around us a moment later.
function Layer:Reset()
	self.readings = {}
	self:Set(nil)
	C_Timer.After(3, function() Layer:ScanAround() end)
end

-- While our layer is unknown, keep looking every few seconds, so it's found
-- even if the NPC was targeted before a loading screen finished.
ns.On("READY", function()
	C_Timer.NewTicker(5, function()
		if not Layer.mine then Layer:ScanAround() end
	end)
end)

ns.RegisterGameEvent("PLAYER_TARGET_CHANGED", function() Layer:Observe("target") end)
ns.RegisterGameEvent("UPDATE_MOUSEOVER_UNIT", function() Layer:Observe("mouseover") end)
ns.RegisterGameEvent("NAME_PLATE_UNIT_ADDED", function(unit) Layer:Observe(unit) end)

-- New zone: take readings there as soon as possible.
ns.RegisterGameEvent("ZONE_CHANGED_NEW_AREA", function() Layer:ScanAround() end)
-- Loading screens can change continent or enter an instance.
ns.RegisterGameEvent("PLAYER_ENTERING_WORLD", function() Layer:Reset() end)
-- Joining or leaving a group often moves you to the leader's layer.
ns.RegisterGameEvent("GROUP_JOINED", function() Layer:Reset() end)
ns.RegisterGameEvent("GROUP_LEFT", function() Layer:Reset() end)
