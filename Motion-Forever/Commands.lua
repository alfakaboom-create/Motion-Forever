-- Commands: /mforever (or /motionforever)

local _, ns = ...

local function onOff(value)
	return value and "|cff00ff00on|r" or "|cffff0000off|r"
end

local function printHelp()
	ns.Print("v" .. ns.VERSION .. " commands:")
	print("  /mforever - open or close the guild list window")
	print("  /mforever list - guild members currently tracked, in chat")
	print("  /mforever share on|off - send your position to the guild")
	print("  /mforever show on|off - show guild members on your map")
	print("  /mforever ping - ask everyone to send their position now")
	print("  /mforever status - current settings")
	print("  /mforever layer - check your layer (target an NPC first)")
	print("  /mforever debug on|off - extra chat output for testing")
end

local function printList()
	local names = ns.Roster:SortedNames()
	if #names == 0 then
		ns.Print("No guild members with Motion-Forever seen yet.")
		return
	end
	ns.Print(#names .. " guild member(s) tracked:")
	local now = GetTime()
	for _, name in ipairs(names) do
		local entry = ns.Roster:Get(name)
		local zone = ns.Compat.GetMapName(entry.mapID) or "unknown zone"
		local where
		if entry.x then
			where = string.format("%s (%.1f, %.1f)", zone, entry.x * 100, entry.y * 100)
		else
			where = zone .. " (no exact position)"
		end
		local layer = ns.Layer.Describe(ns.Layer.Compare(ns.Layer.mine, entry.layer))
		print(string.format("  %s - %s, %s, %ds ago", ns.ShortName(name), where, layer,
			math.floor(now - entry.lastSeen)))
	end
end

local function printStatus()
	ns.Print("Sharing: " .. onOff(ns.db.share) .. ", showing: " .. onOff(ns.db.show)
		.. ", debug: " .. onOff(ns.db.debug))
	ns.Print("In guild: " .. tostring(IsInGuild()) .. ", tracked: " .. ns.Roster:Count())
	local mapID, x, y = ns.Compat.GetPlayerMapPosition()
	if mapID then
		ns.Print(string.format("Your map: %s (%d), position: %s", ns.Compat.GetMapName(mapID) or "?", mapID,
			x and string.format("%.1f, %.1f", x * 100, y * 100) or "hidden"))
	else
		ns.Print("Your map: unknown")
	end
	ns.Print("Your layer: " .. (ns.Layer.mine or "unknown (target or mouse over an NPC)"))
end

-- Explains how the layer was (or wasn't) worked out, for testing.
local function printLayer()
	ns.Layer:ScanAround()
	ns.Print("Your layer: " .. (ns.Layer.mine or "unknown"))
	print("  Open world: " .. (ns.Compat.IsInOpenWorld() and "yes" or "no (layers only work outside instances)"))
	print("  Zone map: " .. tostring(ns.Compat.GetPlayerZoneMapID()))
	print("  Recent NPC readings: " .. (#ns.Layer.readings > 0 and ns.Layer.Summary(ns.Layer.readings) or "none"))
	print("  Target: " .. ns.Compat.DescribeUnitForLayer("target"))
end

SLASH_MOTIONFOREVER1 = "/mforever"
SLASH_MOTIONFOREVER2 = "/motionforever"

SlashCmdList.MOTIONFOREVER = function(input)
	local cmd, arg = (input or ""):lower():match("^%s*(%S*)%s*(%S*)")

	if cmd == "" then
		ns.GuildList:Toggle()
	elseif cmd == "list" then
		printList()
	elseif cmd == "share" and (arg == "on" or arg == "off") then
		ns.Position:SetSharing(arg == "on")
		ns.Print("Sharing your position: " .. onOff(ns.db.share))
	elseif cmd == "show" and (arg == "on" or arg == "off") then
		ns.SetOption("show", arg == "on")
		ns.Print("Showing guild members on the map: " .. onOff(ns.db.show))
	elseif cmd == "ping" then
		ns.Comm:Broadcast(ns.Protocol.MSG.HELLO)
		ns.Position:RequestSoon()
		ns.Print("Asked the guild for positions.")
	elseif cmd == "status" then
		printStatus()
	elseif cmd == "layer" then
		printLayer()
	elseif cmd == "debug" and (arg == "on" or arg == "off") then
		ns.SetOption("debug", arg == "on")
		ns.Print("Debug: " .. onOff(ns.db.debug))
	else
		printHelp()
	end
end
