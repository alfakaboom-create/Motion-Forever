-- Unit tests for the parts of Motion-Forever that don't need the game.
-- Run from the repo root:   lua tests/run.lua

local root = (arg and arg[0] or ""):match("^(.*)[/\\]tests[/\\]") or "."
local ADDON_DIR = root .. "/Motion-Forever/"

---------------------------------------------------------------------------
-- Minimal stand-ins for the game API
---------------------------------------------------------------------------
local fakeTime = 100
function GetTime() return fakeTime end
function IsInGuild() return true end
function GetNormalizedRealmName() return "TestRealm" end
function geterrorhandler() return function(err) error(err, 0) end end

local sent = {}

local ns = {}
local events = {}
function ns.On(event, fn) events[event] = events[event] or {}; table.insert(events[event], fn) end
function ns.Fire(event, ...) for _, fn in ipairs(events[event] or {}) do fn(...) end end
function ns.RegisterGameEvent() end
function ns.Debug() end
function ns.GetCaps() return "" end
function ns.GetPlayerFullName() return "Me-TestRealm" end
ns.Compat = {
	SendAddonMessage = function(prefix, msg, channel, target)
		sent[#sent + 1] = { prefix = prefix, msg = msg, channel = channel, target = target }
		return true
	end,
}

local function load(file)
	local chunk = assert(loadfile(ADDON_DIR .. file))
	chunk("Motion-Forever", ns)
end

load("Protocol.lua")
load("Roster.lua")
load("Comm.lua")
load("Position.lua")

local P, Roster, Comm, Position = ns.Protocol, ns.Roster, ns.Comm, ns.Position

---------------------------------------------------------------------------
-- Tiny test runner
---------------------------------------------------------------------------
local passed, failed = 0, 0

local function test(name, fn)
	Roster.members = {}
	sent = {}
	local ok, err = pcall(fn)
	if ok then
		passed = passed + 1
		print("  ok   " .. name)
	else
		failed = failed + 1
		print("  FAIL " .. name .. "\n       " .. tostring(err))
	end
end

local function eq(actual, expected, label)
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", label or "value", tostring(expected), tostring(actual)), 2)
	end
end

---------------------------------------------------------------------------
-- Protocol
---------------------------------------------------------------------------
print("Protocol")

test("encode and decode round trip", function()
	local msg = P.Encode("POS", 1429, 10, 20)
	eq(msg, "1;POS;1429;10;20")
	local version, msgType, fields = P.Decode(msg)
	eq(version, 1); eq(msgType, "POS"); eq(#fields, 3); eq(fields[1], "1429")
end)

test("nil and empty fields are kept", function()
	local msg = P.Encode("POS", 1, nil, nil, "MAGE")
	eq(msg, "1;POS;1;;;MAGE")
	local _, _, fields = P.Decode(msg)
	eq(#fields, 4); eq(fields[2], ""); eq(fields[4], "MAGE")
end)

test("message with no fields", function()
	local version, msgType, fields = P.Decode(P.Encode("HELLO"))
	eq(version, 1); eq(msgType, "HELLO"); eq(#fields, 0)
end)

test("rejects a field containing the separator", function()
	eq(P.Encode("POS", "a;b"), nil)
end)

test("rejects messages over 255 characters", function()
	eq(P.Encode("POS", string.rep("x", 300)), nil)
end)

test("ignores garbage", function()
	eq(P.Decode(nil), nil)
	eq(P.Decode(""), nil)
	eq(P.Decode("hello"), nil)
	eq(P.Decode("0;POS;1"), nil)
	eq(P.Decode("1;"), nil)
end)

test("accepts a newer version with extra fields", function()
	local version, msgType, fields = P.Decode("2;POS;1429;5000;5000;MAGE;10;Q;newfield")
	eq(version, 2); eq(msgType, "POS")
	local pos = P.DecodePos(fields)
	eq(pos.mapID, 1429); eq(pos.x, 0.5); eq(pos.caps, "Q")
end)

test("coordinates are packed and clamped", function()
	eq(P.PackCoord(0.45123), 4512)
	eq(P.PackCoord(-0.2), 0)
	eq(P.PackCoord(1.5), 10000)
	eq(P.PackCoord(nil), nil)
	eq(P.UnpackCoord("4512"), 0.4512)
	eq(P.UnpackCoord("20000"), nil)
	eq(P.UnpackCoord(""), nil)
end)

test("POS round trip", function()
	local msg = P.EncodePos({ mapID = 1429, x = 0.4512, y = 0.623, class = "MAGE", level = 12, caps = "" })
	eq(msg, "1;POS;1429;4512;6230;MAGE;12;")
	local _, _, fields = P.Decode(msg)
	local pos = P.DecodePos(fields)
	eq(pos.mapID, 1429); eq(pos.x, 0.4512); eq(pos.y, 0.623)
	eq(pos.class, "MAGE"); eq(pos.level, 12)
end)

test("POS without coordinates (in a dungeon)", function()
	local msg = P.EncodePos({ mapID = 291, class = "WARRIOR", level = 20, caps = "" })
	local _, _, fields = P.Decode(msg)
	local pos = P.DecodePos(fields)
	eq(pos.mapID, 291); eq(pos.x, nil); eq(pos.y, nil); eq(pos.class, "WARRIOR")
end)

test("POS from an old client with missing fields", function()
	local pos = P.DecodePos({ "1429", "100", "200" })
	eq(pos.mapID, 1429); eq(pos.class, nil); eq(pos.level, nil); eq(pos.caps, "")
end)

---------------------------------------------------------------------------
-- Roster
---------------------------------------------------------------------------
print("Roster")

test("adds, updates and fires events", function()
	local seen = {}
	ns.On("ROSTER_CHANGED", function(name, kind) seen[#seen + 1] = kind end)
	Roster:Update("Bob-TestRealm", { mapID = 1, x = 0.1, y = 0.1, class = "MAGE", caps = "" }, 100)
	Roster:Update("Bob-TestRealm", { mapID = 1, x = 0.2, y = 0.1, caps = "" }, 105)
	eq(Roster:Count(), 1)
	eq(Roster:Get("Bob-TestRealm").x, 0.2)
	eq(Roster:Get("Bob-TestRealm").class, "MAGE", "class kept when missing")
	eq(seen[#seen - 1], "added"); eq(seen[#seen], "updated")
	events.ROSTER_CHANGED = nil
end)

test("keeps phase 2 quest data across updates", function()
	local entry = Roster:Update("Bob-TestRealm", { mapID = 1, caps = "Q" }, 100)
	entry.quests = { [123] = true }
	Roster:Update("Bob-TestRealm", { mapID = 2, caps = "Q" }, 101)
	eq(Roster:Get("Bob-TestRealm").quests[123], true)
end)

test("capabilities", function()
	Roster:Update("Bob-TestRealm", { mapID = 1, caps = "Q" }, 100)
	Roster:Update("Ann-TestRealm", { mapID = 1, caps = "" }, 100)
	eq(Roster:HasCap("Bob-TestRealm", "Q"), true)
	eq(Roster:HasCap("Ann-TestRealm", "Q"), false)
	eq(Roster:HasCap("Nobody-TestRealm", "Q"), false)
end)

test("prunes members who went quiet", function()
	Roster.timeout = 45
	Roster:Update("Old-TestRealm", { mapID = 1 }, 100)
	Roster:Update("New-TestRealm", { mapID = 1 }, 140)
	Roster:Prune(150)
	eq(Roster:Get("Old-TestRealm"), nil)
	eq(Roster:Get("New-TestRealm") ~= nil, true)
end)

test("sorted names and wipe", function()
	Roster:Update("Zed-TestRealm", { mapID = 1 }, 1)
	Roster:Update("Amy-TestRealm", { mapID = 1 }, 1)
	local names = Roster:SortedNames()
	eq(names[1], "Amy-TestRealm"); eq(names[2], "Zed-TestRealm")
	Roster:Wipe()
	eq(Roster:Count(), 0)
end)

---------------------------------------------------------------------------
-- Comm (receiving) and Position handlers
---------------------------------------------------------------------------
print("Comm")

test("POS from a guild member lands in the roster", function()
	Comm:OnMessage("MotionForever", "1;POS;1429;5000;2500;PRIEST;30;", "GUILD", "Ann-TestRealm")
	local entry = Roster:Get("Ann-TestRealm")
	eq(entry.mapID, 1429); eq(entry.x, 0.5); eq(entry.y, 0.25); eq(entry.lastSeen, fakeTime)
end)

test("ignores our own echoed messages", function()
	Comm:OnMessage("MotionForever", "1;POS;1;1;1", "GUILD", "Me-TestRealm")
	eq(Roster:Count(), 0)
end)

test("ignores other addons' prefixes and channels", function()
	Comm:OnMessage("OtherAddon", "1;POS;1;1;1", "GUILD", "Ann-TestRealm")
	Comm:OnMessage("MotionForever", "1;POS;1;1;1", "PARTY", "Ann-TestRealm")
	eq(Roster:Count(), 0)
end)

test("adds the realm to names without one", function()
	Comm:OnMessage("MotionForever", "1;POS;1;1;1", "GUILD", "Ann")
	eq(Roster:Get("Ann-TestRealm") ~= nil, true)
end)

test("ignores unknown types (e.g. phase 2 messages on a phase 1 client)", function()
	Comm:OnMessage("MotionForever", "1;QLIST;1;1;123,456", "WHISPER", "Ann-TestRealm")
	Comm:OnMessage("MotionForever", "1;FUTURE;x", "GUILD", "Ann-TestRealm")
	eq(Roster:Count(), 0)
end)

test("BYE removes the sender", function()
	Comm:OnMessage("MotionForever", "1;POS;1;1;1", "GUILD", "Ann-TestRealm")
	Comm:OnMessage("MotionForever", "1;BYE", "GUILD", "Ann-TestRealm")
	eq(Roster:Get("Ann-TestRealm"), nil)
end)

test("HELLO schedules an early send", function()
	Position.sendAt = nil
	Comm:OnMessage("MotionForever", "1;HELLO", "GUILD", "Ann-TestRealm")
	eq(Position.sendAt ~= nil, true)
	eq(Position.sendAt >= fakeTime + 0.5 and Position.sendAt <= fakeTime + 3, true, "delay in range")
end)

test("whisper sends go to the target", function()
	Comm:Whisper("Ann-TestRealm", "QREQ")
	eq(#sent, 1); eq(sent[1].channel, "WHISPER"); eq(sent[1].target, "Ann-TestRealm")
	eq(sent[1].msg, "1;QREQ")
end)

---------------------------------------------------------------------------
-- Position timing
---------------------------------------------------------------------------
print("Position")

local settings = { minInterval = 3, heartbeat = 15 }
local here = { mapID = 1, x = 0.5, y = 0.5 }

test("sends the first time", function()
	eq(Position.ShouldSend(100, 0, nil, here, settings), true)
end)

test("waits while standing still, then sends a heartbeat", function()
	eq(Position.ShouldSend(105, 100, here, here, settings), false)
	eq(Position.ShouldSend(115, 100, here, here, settings), true)
end)

test("sends after moving, but not faster than minInterval", function()
	local moved = { mapID = 1, x = 0.51, y = 0.5 }
	eq(Position.ShouldSend(101, 100, here, moved, settings), false)
	eq(Position.ShouldSend(103, 100, here, moved, settings), true)
end)

test("tiny movements don't count", function()
	local nudged = { mapID = 1, x = 0.5004, y = 0.5 }
	eq(Position.HasMoved(here, nudged), false)
end)

test("changing map or losing the position counts as moving", function()
	eq(Position.HasMoved(here, { mapID = 2, x = 0.5, y = 0.5 }), true)
	eq(Position.HasMoved(here, { mapID = 1 }), true)
	eq(Position.HasMoved({ mapID = 1 }, { mapID = 1 }), false)
end)

test("early send request wins", function()
	eq(Position.ShouldSend(101, 100, here, here, settings, 101), true)
	eq(Position.ShouldSend(101, 100, here, here, settings, 102), false)
end)

---------------------------------------------------------------------------
print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
