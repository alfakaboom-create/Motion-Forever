-- Compat: every direct call to the WoW API that might differ on the
-- WoW Forever client lives here. If something breaks at launch, this is
-- the first file to look at.
--
-- Calls are wrapped in pcall where Midnight-era restrictions (for example
-- "secret" values in instances or combat) could make them error.

local _, ns = ...

local Compat = {}
ns.Compat = Compat

---------------------------------------------------------------------------
-- Addon messages
---------------------------------------------------------------------------
function Compat.RegisterPrefix(prefix)
	if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
		return C_ChatInfo.RegisterAddonMessagePrefix(prefix)
	elseif RegisterAddonMessagePrefix then
		return RegisterAddonMessagePrefix(prefix)
	end
end

-- Returns true on success, or false plus an error/result code.
function Compat.SendAddonMessage(prefix, msg, channel, target)
	local send = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage
	if not send then return false, "no send function" end

	local ok, result = pcall(send, prefix, msg, channel, target)
	if not ok then return false, result end

	-- Modern clients return a result code where 0 means success.
	-- Older clients return nothing or a boolean.
	if type(result) == "number" then return result == 0, result end
	if result == false then return false, "rejected" end
	return true
end

---------------------------------------------------------------------------
-- Player info
---------------------------------------------------------------------------

-- Returns mapID, x, y. x and y are nil when the position is hidden
-- (dungeons, some restricted areas). mapID is nil if even that is unknown.
function Compat.GetPlayerMapPosition()
	if not (C_Map and C_Map.GetBestMapForUnit) then return nil end

	local mapID = C_Map.GetBestMapForUnit("player")
	if not mapID then return nil end

	local ok, x, y = pcall(function()
		local pos = C_Map.GetPlayerMapPosition(mapID, "player")
		if not pos then return nil end
		local px, py = pos:GetXY()
		if not px or not py or (px == 0 and py == 0) then return nil end
		return px, py
	end)

	if ok and x then return mapID, x, y end
	return mapID
end

function Compat.GetPlayerClassAndLevel()
	local _, class = UnitClass("player")
	return class, UnitLevel("player")
end

---------------------------------------------------------------------------
-- Layers (see Layer.lua for how this works)
---------------------------------------------------------------------------

-- True outside dungeons, raids, battlegrounds and so on.
function Compat.IsInOpenWorld()
	local ok, inInstance = pcall(IsInInstance)
	return ok and not inInstance
end

-- Returns the layer key read from an NPC unit, or nil. Players and pets
-- are skipped. Midnight can hide GUIDs as "secret" values, so this is
-- wrapped in pcall and returns nil if they're hidden.
function Compat.GetUnitLayer(unit)
	local ok, key = pcall(function()
		if not UnitExists(unit) or UnitIsPlayer(unit) or UnitPlayerControlled(unit) then return nil end
		local guid = UnitGUID(unit)
		if guid == nil or (issecretvalue and issecretvalue(guid)) then return nil end
		return ns.Layer.KeyFromGUID(guid)
	end)
	if ok then return key end
	return nil
end

-- Units for the nameplates currently on screen.
function Compat.GetNameplateUnits()
	local units = {}
	for i = 1, 40 do
		local unit = "nameplate" .. i
		if UnitExists(unit) then units[#units + 1] = unit end
	end
	return units
end

---------------------------------------------------------------------------
-- Maps
---------------------------------------------------------------------------
function Compat.GetMapName(mapID)
	if not mapID then return nil end
	local info = C_Map.GetMapInfo(mapID)
	return info and info.name
end

-- Converts a position on one map (e.g. Elwynn Forest) to another map
-- (e.g. the Eastern Kingdoms continent map). Returns nil if the point
-- isn't on the target map.
function Compat.TranslatePosition(fromMapID, x, y, toMapID)
	if fromMapID == toMapID then return x, y end

	local ok, tx, ty = pcall(function()
		local continentID, worldPos = C_Map.GetWorldPosFromMapPos(fromMapID, CreateVector2D(x, y))
		if not continentID or not worldPos then return nil end
		local _, mapPos = C_Map.GetMapPosFromWorldPos(continentID, worldPos, toMapID)
		if not mapPos then return nil end
		return mapPos:GetXY()
	end)

	if not ok or not tx or not ty then return nil end
	if tx < 0 or tx > 1 or ty < 0 or ty > 1 then return nil end
	return tx, ty
end

-- True for dungeon maps. Raids also count as dungeons here.
function Compat.IsDungeonMap(mapID)
	if not mapID then return false end
	local info = C_Map.GetMapInfo(mapID)
	return info ~= nil and Enum and Enum.UIMapType and info.mapType == Enum.UIMapType.Dungeon
end

---------------------------------------------------------------------------
-- Guild roster
---------------------------------------------------------------------------

-- Asks the server for fresh guild roster data. GUILD_ROSTER_UPDATE fires
-- when it arrives.
function Compat.RequestGuildRoster()
	if C_GuildInfo and C_GuildInfo.GuildRoster then
		C_GuildInfo.GuildRoster()
	elseif GuildRoster then
		GuildRoster()
	end
end

-- Returns online guild members as a list of { name, level, class, zone }.
-- name is "Name-Realm"; class is the English class token, like "MAGE".
function Compat.GetGuildMembers()
	local members = {}
	if not IsInGuild() then return members end

	local total = GetNumGuildMembers() or 0
	for i = 1, total do
		local name, _, _, level, _, zone, _, _, isOnline, _, class = GetGuildRosterInfo(i)
		if name and isOnline then
			if not name:find("-", 1, true) then
				name = name .. "-" .. (GetNormalizedRealmName() or "")
			end
			members[#members + 1] = { name = name, level = level, class = class, zone = zone }
		end
	end
	return members
end

---------------------------------------------------------------------------
-- Colors
---------------------------------------------------------------------------
function Compat.GetClassColor(class)
	if class then
		if C_ClassColor and C_ClassColor.GetClassColor then
			local color = C_ClassColor.GetClassColor(class)
			if color then return color.r, color.g, color.b end
		end
		local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
		if color then return color.r, color.g, color.b end
	end
	return 0.25, 1.0, 0.25 -- guild green
end
