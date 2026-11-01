-- MapPins: draws guild members on the world map using the game's own map
-- pin system (the same one Blizzard uses for party members).

local _, ns = ...

local PIN_TEMPLATE = "MotionForeverPinTemplate"

---------------------------------------------------------------------------
-- Pin (one dot). The XML template in MapPins.xml uses this mixin, so this
-- file must load before MapPins.xml.
---------------------------------------------------------------------------
MotionForeverPinMixin = CreateFromMixins(MapCanvasPinMixin)

function MotionForeverPinMixin:OnLoad()
	self:UseFrameLevelType("PIN_FRAME_LEVEL_GROUP_MEMBER")
	self:SetScalingLimits(1, 1.0, 1.4)
	self.Border:SetVertexColor(0, 0, 0, 0.9)
end

function MotionForeverPinMixin:OnAcquired(entry, x, y)
	self:SetEntry(entry)
	self:SetPosition(x, y)
end

function MotionForeverPinMixin:SetEntry(entry)
	self.entry = entry
	self.Icon:SetVertexColor(ns.Compat.GetClassColor(entry.class))
end

function MotionForeverPinMixin:OnMouseEnter()
	local entry = self.entry
	if not entry then return end

	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:AddLine(Ambiguate(entry.name, "guild"), ns.Compat.GetClassColor(entry.class))
	if entry.level then
		GameTooltip:AddLine(LEVEL .. " " .. entry.level, 1, 1, 1)
	end
	GameTooltip:AddLine(ns.Layer.Describe(ns.Layer.Compare(ns.Layer.mine, entry.layer)))
	local zone = ns.Compat.GetMapName(entry.mapID)
	if zone then
		GameTooltip:AddLine(zone, 0.8, 0.8, 0.8)
	end

	-- Phase 2 adds "3 quests you can get" lines here.
	ns.Fire("PIN_TOOLTIP", GameTooltip, entry)
	GameTooltip:Show()
end

function MotionForeverPinMixin:OnMouseLeave()
	GameTooltip:Hide()
end

function MotionForeverPinMixin:OnMouseUp(button)
	-- Phase 2 opens the quest request menu from here.
	ns.Fire("PIN_CLICK", self.entry, button)
end

---------------------------------------------------------------------------
-- Data provider: keeps one pin per guild member in sync with the roster.
---------------------------------------------------------------------------
local Provider = CreateFromMixins(MapCanvasDataProviderMixin)
Provider.pins = {}

function Provider:RemoveAllData()
	self:GetMap():RemoveAllPinsByTemplate(PIN_TEMPLATE)
	self.pins = {}
end

function Provider:RefreshAllData()
	self:RemoveAllData()
	self:UpdatePins()
end

-- Moves existing pins instead of rebuilding them, so tooltips don't
-- flicker while someone is moving.
function Provider:UpdatePins()
	local map = self:GetMap()
	if not map then return end
	local mapID = map:GetMapID()
	local seen = {}

	if mapID and ns.db and ns.db.show then
		for name, entry in ns.Roster:Iterate() do
			local x, y
			if entry.mapID and entry.x and entry.y then
				x, y = ns.Compat.TranslatePosition(entry.mapID, entry.x, entry.y, mapID)
			end
			if x then
				seen[name] = true
				local pin = self.pins[name]
				if pin then
					pin:SetEntry(entry)
					pin:SetPosition(x, y)
				else
					self.pins[name] = map:AcquirePin(PIN_TEMPLATE, entry, x, y)
				end
			end
		end
	end

	for name, pin in pairs(self.pins) do
		if not seen[name] then
			map:RemovePin(pin)
			self.pins[name] = nil
		end
	end
end

---------------------------------------------------------------------------
-- Hook up to the world map
---------------------------------------------------------------------------
local registered = false

local function Register()
	if registered or not WorldMapFrame then return end
	WorldMapFrame:AddDataProvider(Provider)
	registered = true
end

ns.On("READY", Register)
ns.RegisterGameEvent("ADDON_LOADED", function(name)
	if name == "Blizzard_WorldMap" then Register() end
end)

-- Roster changes arrive often, so batch them into one update.
local updatePending = false

local function QueueUpdate()
	if updatePending or not registered or not WorldMapFrame:IsShown() then return end
	updatePending = true
	C_Timer.After(0.25, function()
		updatePending = false
		if WorldMapFrame:IsShown() then Provider:UpdatePins() end
	end)
end

ns.On("ROSTER_CHANGED", QueueUpdate)
ns.On("SETTINGS_CHANGED", function(key)
	if key == "show" then QueueUpdate() end
end)
