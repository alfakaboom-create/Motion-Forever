-- Roster: the latest known state of each guild member running the addon.
-- No game API calls in here (time is passed in), so it can be unit tested.

local _, ns = ...

local Roster = {
	members = {},  -- ["Name-Realm"] = entry
	timeout = 45,  -- seconds without a message before someone is dropped
}
ns.Roster = Roster

-- An entry looks like:
-- {
--   name = "Name-Realm", mapID, x, y, class, level, caps, layer, lastSeen,
--   sightedAt = nil, -- when we last saw them in the world (so same layer)
--   quests = nil,  -- phase 2: shareable quest IDs, filled from QLIST
-- }

local function fire(...)
	if ns.Fire then ns.Fire(...) end
end

function Roster:Update(name, data, now)
	local entry = self.members[name]
	local kind = "updated"
	if not entry then
		entry = { name = name }
		self.members[name] = entry
		kind = "added"
	end

	entry.mapID = data.mapID
	entry.x = data.x
	entry.y = data.y
	entry.class = data.class or entry.class
	entry.level = data.level or entry.level
	entry.caps = data.caps or ""
	-- If their layer changed, they may have moved, so an old sighting no
	-- longer proves anything. It's renewed if they're still in view.
	if data.layer ~= entry.layer then entry.sightedAt = nil end
	entry.layer = data.layer -- nil when unknown, or from an older addon
	entry.lastSeen = now
	-- entry.quests is left alone on purpose: it's managed by phase 2.

	fire("ROSTER_CHANGED", name, kind)
	return entry
end

-- A sighting counts for this long after we last saw them. Nameplates are
-- rechecked every 5 seconds, so someone in view stays sighted.
Roster.SIGHT_WINDOW = 30

function Roster.IsSighted(entry, now)
	return entry.sightedAt ~= nil and now - entry.sightedAt <= Roster.SIGHT_WINDOW
end

-- We can see this guild member in the world. Fires ROSTER_CHANGED only
-- when they weren't already marked, since this happens every few seconds.
function Roster:MarkSighted(name, now)
	local entry = self.members[name]
	if not entry then return end
	local isNew = not Roster.IsSighted(entry, now)
	entry.sightedAt = now
	if isNew then fire("ROSTER_CHANGED", name, "updated") end
end

-- Forget all sightings, for example after we change layer ourselves.
function Roster:ClearSightings()
	for name, entry in pairs(self.members) do
		if entry.sightedAt then
			entry.sightedAt = nil
			fire("ROSTER_CHANGED", name, "updated")
		end
	end
end

function Roster:Remove(name)
	if self.members[name] then
		self.members[name] = nil
		fire("ROSTER_CHANGED", name, "removed")
	end
end

function Roster:Get(name)
	return self.members[name]
end

function Roster:Iterate()
	return pairs(self.members)
end

function Roster:Count()
	local n = 0
	for _ in pairs(self.members) do n = n + 1 end
	return n
end

function Roster:SortedNames()
	local names = {}
	for name in pairs(self.members) do names[#names + 1] = name end
	table.sort(names)
	return names
end

function Roster:HasCap(name, cap)
	local entry = self.members[name]
	return entry ~= nil and entry.caps ~= nil and entry.caps:find(cap, 1, true) ~= nil
end

-- Drop anyone we haven't heard from in a while (they logged off,
-- left the guild, or their messages are being blocked).
function Roster:Prune(now)
	for name, entry in pairs(self.members) do
		if now - entry.lastSeen > self.timeout then
			self:Remove(name)
		end
	end
end

function Roster:Wipe()
	for name in pairs(self.members) do self:Remove(name) end
end
