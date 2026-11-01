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
--   name = "Name-Realm", mapID, x, y, class, level, caps, lastSeen,
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
	entry.lastSeen = now
	-- entry.quests is left alone on purpose: it's managed by phase 2.

	fire("ROSTER_CHANGED", name, kind)
	return entry
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
