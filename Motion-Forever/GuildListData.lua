-- GuildListData: builds and sorts the rows for the guild list window.
-- No game API calls in here (map lookups are passed in), so it can be
-- unit tested. The window itself is in GuildListUI.lua.

local _, ns = ...

local GuildList = ns.GuildList or {}
ns.GuildList = GuildList

-- Builds one row per online guild member.
--
-- addonMembers: ns.Roster.members, people running Motion-Forever
-- guildMembers: online guild members from the guild roster, as a list of
--               { name, level, class, zone }
-- opts:
--   showAll    include guild members without the addon
--   selfName   our own "Name-Realm", left out of the list
--   mapName    function(mapID) -> zone name
--   isDungeon  function(mapID) -> true if the map is a dungeon or raid
--   myLayer    our layer key, or nil if unknown
--
-- A row looks like:
-- { name, class, level, zone, hasAddon, hasPosition, inDungeon,
--   layer,          -- "same", "different", why it is unknown, or nil without the addon (see Layer.Compare)
--   quests = nil }  -- phase 2: quest count, filled in from QLIST
function GuildList.BuildRows(addonMembers, guildMembers, opts)
	local rows, byName = {}, {}

	for name, entry in pairs(addonMembers) do
		if name ~= opts.selfName then
			local row = {
				name = name,
				class = entry.class,
				level = entry.level,
				hasAddon = true,
				hasPosition = entry.x ~= nil,
				inDungeon = false,
				layer = ns.Layer.Compare(opts.myLayer, entry.layer),
			}
			if entry.mapID then
				row.zone = opts.mapName(entry.mapID)
				row.inDungeon = opts.isDungeon(entry.mapID) and true or false
			end
			rows[#rows + 1] = row
			byName[name] = row
		end
	end

	for _, member in ipairs(guildMembers) do
		if member.name ~= opts.selfName then
			local row = byName[member.name]
			if row then
				-- Fill gaps in what the addon told us from the guild roster.
				row.class = row.class or member.class
				row.level = row.level or member.level
				row.zone = row.zone or member.zone
			elseif opts.showAll then
				rows[#rows + 1] = {
					name = member.name,
					class = member.class,
					level = member.level,
					zone = member.zone,
					hasAddon = false,
					hasPosition = false,
					inDungeon = false,
				}
			end
		end
	end

	return rows
end

GuildList.SORT_KEYS = { name = true, level = true, zone = true }

-- Sorts in place. People with the addon always come first; within each
-- group rows are sorted by `key`, with name as the tie-breaker.
function GuildList.SortRows(rows, key, ascending)
	table.sort(rows, function(a, b)
		if a.hasAddon ~= b.hasAddon then return a.hasAddon end

		local va, vb
		if key == "level" then
			va, vb = a.level or 0, b.level or 0
		elseif key == "zone" then
			va, vb = (a.zone or ""):lower(), (b.zone or ""):lower()
		else
			va, vb = a.name:lower(), b.name:lower()
		end

		if va ~= vb then
			if ascending then return va < vb end
			return va > vb
		end
		return a.name < b.name
	end)
	return rows
end

-- Returns how many rows have the addon, and how many rows there are.
function GuildList.Count(rows)
	local withAddon = 0
	for _, row in ipairs(rows) do
		if row.hasAddon then withAddon = withAddon + 1 end
	end
	return withAddon, #rows
end
