-- Position: sends our position to the guild and handles position
-- messages from others.

local _, ns = ...

local Protocol = ns.Protocol
local MSG = Protocol.MSG

local Position = {
	lastSent = 0,    -- GetTime() of the last send attempt
	last = nil,      -- last payload sent successfully
	sendAt = nil,    -- send early at this time (after a HELLO or zone change)
}
ns.Position = Position

local MOVE_THRESHOLD = 0.001 -- 0.1% of the map counts as having moved

-- True if b differs enough from a to be worth sending.
function Position.HasMoved(a, b)
	if not a or not b then return true end
	if a.mapID ~= b.mapID then return true end
	if a.layer ~= b.layer then return true end
	if (a.x == nil) ~= (b.x == nil) then return true end
	if a.x == nil then return false end
	return math.abs(a.x - b.x) >= MOVE_THRESHOLD or math.abs(a.y - b.y) >= MOVE_THRESHOLD
end

-- Decides whether to send now. Kept free of game calls so it can be tested.
function Position.ShouldSend(now, lastSent, last, current, settings, sendAt)
	if sendAt and now >= sendAt then return true end
	local since = now - lastSent
	if since >= settings.heartbeat then return true end
	if since >= settings.minInterval and Position.HasMoved(last, current) then return true end
	return false
end

function Position:BuildPayload()
	local mapID, x, y = ns.Compat.GetPlayerMapPosition()
	local class, level = ns.Compat.GetPlayerClassAndLevel()
	return {
		mapID = mapID,
		x = x,
		y = y,
		class = class,
		level = level,
		caps = ns.GetCaps(),
		layer = ns.Layer.mine,
	}
end

-- Send soon, with a random delay so a whole guild doesn't answer a HELLO
-- in the same instant.
function Position:RequestSoon()
	local at = GetTime() + 0.5 + math.random() * 2.5
	if not self.sendAt or at < self.sendAt then
		self.sendAt = at
	end
end

function Position:Tick()
	local now = GetTime()
	ns.Roster:Prune(now)

	if not ns.db.share or not IsInGuild() then return end

	local current = self:BuildPayload()
	if not Position.ShouldSend(now, self.lastSent, self.last, current, ns.db, self.sendAt) then
		return
	end

	-- Record the attempt even if it fails, so a blocked channel (for
	-- example inside an instance) is retried every few seconds, not every tick.
	self.lastSent = now
	self.sendAt = nil

	local msg = Protocol.EncodePos(current)
	if msg and ns.Comm:BroadcastRaw(msg) then
		self.last = current
	end
end

function Position:SetSharing(enabled)
	ns.SetOption("share", enabled)
	if enabled then
		self.last = nil
		self:RequestSoon()
	else
		ns.Comm:Broadcast(MSG.BYE)
	end
end

---------------------------------------------------------------------------
-- Incoming messages
---------------------------------------------------------------------------
ns.Comm:RegisterHandler(MSG.HELLO, function(sender, _, channel)
	if channel ~= "GUILD" then return end
	ns.Debug("hello from", sender)
	Position:RequestSoon()
end)

ns.Comm:RegisterHandler(MSG.POS, function(sender, fields, channel)
	if channel ~= "GUILD" then return end
	ns.Roster:Update(sender, Protocol.DecodePos(fields), GetTime())
end)

ns.Comm:RegisterHandler(MSG.BYE, function(sender)
	ns.Roster:Remove(sender)
end)

---------------------------------------------------------------------------
-- Startup and game events
---------------------------------------------------------------------------
ns.On("READY", function()
	ns.Roster.timeout = ns.db.heartbeat * 3
	C_Timer.NewTicker(1, function() Position:Tick() end)
end)

ns.On("SETTINGS_CHANGED", function(key)
	if key == "heartbeat" then ns.Roster.timeout = ns.db.heartbeat * 3 end
end)

-- Tell the guild soon when we find out (or lose track of) our layer.
ns.On("LAYER_CHANGED", function() Position:RequestSoon() end)

ns.RegisterGameEvent("PLAYER_ENTERING_WORLD", function(isLogin, isReload)
	if isLogin or isReload then
		-- Wait a moment: guild info isn't always ready right at login.
		C_Timer.After(5, function()
			if IsInGuild() then
				ns.Comm:Broadcast(MSG.HELLO)
				Position:RequestSoon()
			end
		end)
	else
		Position:RequestSoon() -- went through a loading screen
	end
end)

ns.RegisterGameEvent("PLAYER_LOGOUT", function()
	if ns.db and ns.db.share then ns.Comm:Broadcast(MSG.BYE) end
end)
