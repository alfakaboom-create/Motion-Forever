-- Core: shared namespace, saved settings, and a small event bus.
-- Every other file gets the same `ns` table from the WoW loader.

local ADDON_NAME, ns = ...

ns.ADDON_NAME = ADDON_NAME
ns.VERSION = "0.1.0"

ns.defaults = {
	share = true,      -- send my position to the guild
	show = true,       -- show guild members on my world map
	minInterval = 3,   -- seconds between updates while moving
	heartbeat = 15,    -- seconds between updates while standing still
	debug = false,

	-- Guild list window
	listShowAll = true,     -- also list guild members without the addon
	listSort = "name",      -- "name", "level" or "zone"
	listAscending = true,
}

---------------------------------------------------------------------------
-- Internal event bus, so modules talk through events instead of calling
-- each other directly. Phase 2 (quest sharing) plugs in through these.
--
-- Events used today:
--   READY                       settings loaded, safe to start
--   ROSTER_CHANGED(name, kind)  kind = "added" | "updated" | "removed"
--   SETTINGS_CHANGED(key)
--   PIN_TOOLTIP(tooltip, entry) add lines to a map pin tooltip
--   PIN_CLICK(entry, button)    a map pin was clicked
--   GUILDLIST_ROW_CLICK(row, button)  a guild list row was clicked
---------------------------------------------------------------------------
local listeners = {}

function ns.On(event, fn)
	listeners[event] = listeners[event] or {}
	table.insert(listeners[event], fn)
end

function ns.Fire(event, ...)
	local list = listeners[event]
	if not list then return end
	for i = 1, #list do
		local ok, err = pcall(list[i], ...)
		if not ok then geterrorhandler()(err) end
	end
end

---------------------------------------------------------------------------
-- Game events
---------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local gameHandlers = {}

function ns.RegisterGameEvent(event, fn)
	if not gameHandlers[event] then
		gameHandlers[event] = {}
		eventFrame:RegisterEvent(event)
	end
	table.insert(gameHandlers[event], fn)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
	local list = gameHandlers[event]
	for i = 1, #list do
		list[i](...)
	end
end)

---------------------------------------------------------------------------
-- Capabilities: letters advertised to other clients so they know which
-- features we support (for example "Q" for quest sharing in phase 2).
---------------------------------------------------------------------------
local capabilities = {}

function ns.AddCapability(letter)
	capabilities[letter] = true
end

function ns.GetCaps()
	local letters = {}
	for letter in pairs(capabilities) do letters[#letters + 1] = letter end
	table.sort(letters)
	return table.concat(letters)
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
function ns.Print(...)
	print("|cff33ff99Motion-Forever|r:", ...)
end

function ns.Debug(...)
	if ns.db and ns.db.debug then
		ns.Print("|cff888888[debug]|r", ...)
	end
end

function ns.GetPlayerFullName()
	local name, realm = UnitFullName("player")
	realm = (realm and realm ~= "") and realm or GetNormalizedRealmName()
	if name and realm then return name .. "-" .. realm end
	return name
end

function ns.SetOption(key, value)
	ns.db[key] = value
	ns.Fire("SETTINGS_CHANGED", key)
end

---------------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------------
ns.RegisterGameEvent("ADDON_LOADED", function(name)
	if name ~= ADDON_NAME then return end
	MotionForeverDB = MotionForeverDB or {}
	for key, value in pairs(ns.defaults) do
		if MotionForeverDB[key] == nil then MotionForeverDB[key] = value end
	end
	ns.db = MotionForeverDB
	ns.Fire("READY")
end)
