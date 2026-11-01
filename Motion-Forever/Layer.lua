-- Layer: works out which layer (copy of the world) we're on, and compares
-- it with guild members' layers.
--
-- The game has no "which layer am I on" function. Every NPC's hidden ID
-- (GUID) looks like Creature-0-server-continent-zoneUID-npcID-spawnUID,
-- and the zoneUID part is the same for everything on one layer of one
-- continent. So we read it from NPCs we target, mouse over, or see a
-- nameplate for.
--
-- A layer key is "continent-zoneUID", for example "0-1234". The numbers mean
-- nothing on their own; keys can only be compared, and only on the same
-- continent.
--
-- The functions at the top are pure (no game calls) so they can be tested.

local _, ns = ...

local Layer = {
	mine = nil, -- our layer key, or nil while unknown
}
ns.Layer = Layer

local UNIT_TYPES = { Creature = true, Vehicle = true }

-- Returns the layer key for an NPC's GUID, or nil if it doesn't have one.
function Layer.KeyFromGUID(guid)
	if type(guid) ~= "string" then return nil end
	local unitType, continent, zoneUID = guid:match("^(%a+)%-0%-%d+%-(%d+)%-(%d+)%-%d+%-")
	if not unitType or not UNIT_TYPES[unitType] or zoneUID == "0" then return nil end
	return continent .. "-" .. zoneUID
end

-- True if text looks like a layer key. Used to check incoming messages.
function Layer.IsKey(text)
	return type(text) == "string" and text:match("^%d+%-%d+$") ~= nil
end

-- Returns "same", "different", or nil when it can't be told (either layer
-- unknown, or the two players are on different continents).
function Layer.Compare(mine, theirs)
	if not Layer.IsKey(mine) or not Layer.IsKey(theirs) then return nil end
	if mine:match("^(%d+)") ~= theirs:match("^(%d+)") then return nil end
	return mine == theirs and "same" or "different"
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
	local key = ns.Compat.GetUnitLayer(unit)
	if key then self:Set(key) end
end

function Layer:ScanNameplates()
	for _, unit in ipairs(ns.Compat.GetNameplateUnits()) do
		self:Observe(unit)
	end
end

-- After something that may move us to another layer, forget the old one,
-- then look again at what's around us a moment later.
function Layer:Reset()
	self:Set(nil)
	C_Timer.After(3, function() Layer:ScanNameplates() end)
end

ns.RegisterGameEvent("PLAYER_TARGET_CHANGED", function() Layer:Observe("target") end)
ns.RegisterGameEvent("UPDATE_MOUSEOVER_UNIT", function() Layer:Observe("mouseover") end)
ns.RegisterGameEvent("NAME_PLATE_UNIT_ADDED", function(unit) Layer:Observe(unit) end)

-- Loading screens can change continent or enter an instance.
ns.RegisterGameEvent("PLAYER_ENTERING_WORLD", function() Layer:Reset() end)
-- Joining or leaving a group often moves you to the leader's layer.
ns.RegisterGameEvent("GROUP_JOINED", function() Layer:Reset() end)
ns.RegisterGameEvent("GROUP_LEFT", function() Layer:Reset() end)
