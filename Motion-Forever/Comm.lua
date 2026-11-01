-- Comm: sends and receives addon messages and hands each one to the
-- handler registered for its type. Supports the GUILD channel (phase 1)
-- and WHISPER (used by phase 2 for one-to-one quest requests).

local _, ns = ...

local Comm = {
	handlers = {},
}
ns.Comm = Comm

local Protocol = ns.Protocol

-- fn(sender, fields, channel, version)
function Comm:RegisterHandler(msgType, fn)
	self.handlers[msgType] = fn
end

function Comm:SendRaw(channel, target, msg)
	local ok, code = ns.Compat.SendAddonMessage(Protocol.PREFIX, msg, channel, target)
	if not ok then
		ns.Debug("send failed on", channel, tostring(code))
	end
	return ok
end

function Comm:Send(channel, target, msgType, ...)
	local msg, err = Protocol.Encode(msgType, ...)
	if not msg then
		ns.Debug("could not encode", msgType, err)
		return false
	end
	return self:SendRaw(channel, target, msg)
end

function Comm:Broadcast(msgType, ...)
	if not IsInGuild() then return false end
	return self:Send("GUILD", nil, msgType, ...)
end

function Comm:BroadcastRaw(msg)
	if not IsInGuild() then return false end
	return self:SendRaw("GUILD", nil, msg)
end

function Comm:Whisper(target, msgType, ...)
	return self:Send("WHISPER", target, msgType, ...)
end

function Comm:OnMessage(prefix, text, channel, sender)
	if prefix ~= Protocol.PREFIX then return end
	if channel ~= "GUILD" and channel ~= "WHISPER" then return end
	if not sender or sender == "" then return end

	-- Always store names as "Name-Realm" so lookups are consistent.
	if not sender:find("-", 1, true) then
		sender = sender .. "-" .. (GetNormalizedRealmName() or "")
	end

	-- Our own guild messages are echoed back to us; ignore them.
	if sender == ns.GetPlayerFullName() then return end

	local version, msgType, fields = Protocol.Decode(text)
	if not version then
		ns.Debug("bad message from", sender)
		return
	end

	local handler = self.handlers[msgType]
	if handler then
		handler(sender, fields, channel, version)
	else
		ns.Debug("ignoring", msgType, "from", sender)
	end
end

ns.On("READY", function()
	ns.Compat.RegisterPrefix(Protocol.PREFIX)
end)

ns.RegisterGameEvent("CHAT_MSG_ADDON", function(prefix, text, channel, sender)
	Comm:OnMessage(prefix, text, channel, sender)
end)
