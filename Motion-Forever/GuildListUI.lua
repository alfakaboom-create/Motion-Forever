-- GuildListUI: the guild list window, opened with /mforever.
-- Lists online guild members with Motion-Forever (and optionally those
-- without it), with their level and zone. Sortable by clicking a header.
--
-- Phase 2 adds a "Quests" column and a View button by adding entries to
-- GuildList.columns before the window is first opened, and listens to the
-- GUILDLIST_ROW_CLICK event.

local _, ns = ...

local GuildList = ns.GuildList

local FRAME_NAME = "MotionForeverGuildList"
local ROW_HEIGHT = 20
local GREY = { 0.5, 0.5, 0.5 }

local function classColor(row)
	if not row.hasAddon then return unpack(GREY) end
	return ns.Compat.GetClassColor(row.class)
end

---------------------------------------------------------------------------
-- Columns. text(row) returns the text plus an optional r, g, b color.
---------------------------------------------------------------------------
GuildList.columns = {
	{
		key = "name", label = "Name", width = 140,
		text = function(row)
			return ns.ShortName(row.name), classColor(row)
		end,
	},
	{
		key = "level", label = "Level", width = 50,
		text = function(row)
			return row.level and tostring(row.level) or ""
		end,
	},
	{
		key = "zone", label = "Zone", width = 200,
		text = function(row)
			local zone = row.zone or "Unknown"
			if row.inDungeon then zone = zone .. " (dungeon)" end
			return zone
		end,
	},
	{
		key = "layer", label = "Layer", width = 70, sortable = false,
		text = function(row)
			if not row.hasAddon then return "" end
			return ns.Layer.Describe(row.layer, true)
		end,
	},
	{
		key = "status", label = "Status", width = 110, sortable = false,
		text = function(row)
			if not row.hasAddon then return "No addon", unpack(GREY) end
			if row.hasPosition then return "On map", 0.25, 1, 0.25 end
			return "Position hidden", 1, 0.82, 0
		end,
	},
}

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local frame

local function Refresh()
	if not frame or not frame:IsShown() then return end

	local rows = GuildList.BuildRows(ns.Roster.members, ns.Compat.GetGuildMembers(), {
		showAll = ns.db.listShowAll,
		selfName = ns.GetPlayerFullName(),
		mapName = ns.Compat.GetMapName,
		isDungeon = ns.Compat.IsDungeonMap,
		myLayer = ns.Layer.mine,
	})
	GuildList.SortRows(rows, ns.db.listSort, ns.db.listAscending)

	frame.scrollBox:SetDataProvider(CreateDataProvider(rows), ScrollBoxConstants.RetainScrollPosition)

	-- Header sort arrows
	for _, header in ipairs(frame.headers) do
		local active = header.column.key == ns.db.listSort
		header.arrow:SetShown(active)
		if active then
			if ns.db.listAscending then
				header.arrow:SetTexCoord(0, 0.5625, 0, 1)
			else
				header.arrow:SetTexCoord(0, 0.5625, 1, 0)
			end
		end
	end

	local withAddon, total = GuildList.Count(rows)
	if not IsInGuild() then
		frame.footer:SetText("You're not in a guild.")
	elseif ns.db.listShowAll then
		frame.footer:SetText(string.format("%d of %d online use Motion-Forever", withAddon, total))
	else
		frame.footer:SetText(string.format("%d online use Motion-Forever", withAddon))
	end

	frame.empty:SetShown(#rows == 0 and IsInGuild())
end

-- Roster updates arrive often, so batch them.
local refreshPending = false
local function QueueRefresh()
	if refreshPending or not frame or not frame:IsShown() then return end
	refreshPending = true
	C_Timer.After(0.5, function()
		refreshPending = false
		Refresh()
	end)
end

local function OnHeaderClick(header)
	local key = header.column.key
	if ns.db.listSort == key then
		ns.db.listAscending = not ns.db.listAscending
	else
		ns.db.listSort = key
		ns.db.listAscending = key ~= "level" -- highest level first feels natural
	end
	Refresh()
end

local function InitRow(button, row)
	if not button.cells then
		button:SetHeight(ROW_HEIGHT)
		button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		button.cells = {}

		local x = 4
		for i, column in ipairs(GuildList.columns) do
			local cell = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			cell:SetPoint("LEFT", button, "LEFT", x, 0)
			cell:SetWidth(column.width - 8)
			cell:SetJustifyH("LEFT")
			cell:SetWordWrap(false)
			button.cells[i] = cell
			x = x + column.width
		end

		local highlight = button:CreateTexture(nil, "HIGHLIGHT")
		highlight:SetAllPoints()
		highlight:SetColorTexture(1, 1, 1, 0.08)

		-- Phase 2 opens the quest window from here.
		button:SetScript("OnClick", function(self, mouseButton)
			ns.Fire("GUILDLIST_ROW_CLICK", self.row, mouseButton)
		end)
	end

	button.row = row
	for i, column in ipairs(GuildList.columns) do
		local text, r, g, b = column.text(row)
		button.cells[i]:SetText(text or "")
		button.cells[i]:SetTextColor(r or 1, g or 1, b or 1)
	end
end

local function CreateWindow()
	local width = 36
	for _, column in ipairs(GuildList.columns) do width = width + column.width end

	frame = CreateFrame("Frame", FRAME_NAME, UIParent, "BasicFrameTemplateWithInset")
	frame:SetSize(width, 420)
	frame:SetPoint("CENTER")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:Hide()
	table.insert(UISpecialFrames, FRAME_NAME) -- Escape closes it

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	title:SetPoint("TOP", frame, "TOP", 0, -5)
	title:SetText("Motion-Forever: Guild")

	-- Column headers
	frame.headers = {}
	local x = 14
	for _, column in ipairs(GuildList.columns) do
		local header = CreateFrame("Button", nil, frame)
		header:SetSize(column.width, 20)
		header:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -30)
		header.column = column

		local label = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		label:SetPoint("LEFT", header, "LEFT", 0, 0)
		label:SetText(column.label)

		header.arrow = header:CreateTexture(nil, "OVERLAY")
		header.arrow:SetTexture("Interface\\Buttons\\UI-SortArrow")
		header.arrow:SetSize(9, 8)
		header.arrow:SetPoint("LEFT", label, "RIGHT", 3, -1)
		header.arrow:Hide()

		if column.sortable ~= false then
			header:SetScript("OnClick", OnHeaderClick)
			header:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
			header:GetHighlightTexture():SetAlpha(0.3)
			frame.headers[#frame.headers + 1] = header
		end

		x = x + column.width
	end

	-- Scrolling list
	frame.scrollBox = CreateFrame("Frame", nil, frame, "WowScrollBoxList")
	frame.scrollBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -52)
	frame.scrollBox:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -26, 38)

	local scrollBar = CreateFrame("EventFrame", nil, frame, "MinimalScrollBar")
	scrollBar:SetPoint("TOPLEFT", frame.scrollBox, "TOPRIGHT", 6, 0)
	scrollBar:SetPoint("BOTTOMLEFT", frame.scrollBox, "BOTTOMRIGHT", 6, 0)

	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(ROW_HEIGHT)
	view:SetElementInitializer("Button", InitRow)
	ScrollUtil.InitScrollBoxListWithScrollBar(frame.scrollBox, scrollBar, view)

	frame.empty = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	frame.empty:SetPoint("CENTER", frame.scrollBox, "CENTER")
	frame.empty:SetText("No guild members online with Motion-Forever yet.")
	frame.empty:Hide()

	-- Footer
	frame.footer = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 14)

	local showAll = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
	showAll:SetSize(24, 24)
	showAll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -170, 8)
	showAll:SetChecked(ns.db.listShowAll)
	showAll:SetScript("OnClick", function(self)
		ns.SetOption("listShowAll", self:GetChecked() and true or false)
		Refresh()
	end)
	local showAllLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	showAllLabel:SetPoint("LEFT", showAll, "RIGHT", 2, 0)
	showAllLabel:SetText("Show members without addon")

	-- While open, keep the guild roster fresh. The game limits roster
	-- requests to about one every 10 seconds anyway.
	frame:SetScript("OnShow", function(self)
		ns.Compat.RequestGuildRoster()
		self.ticker = C_Timer.NewTicker(10, ns.Compat.RequestGuildRoster)
		Refresh()
	end)
	frame:SetScript("OnHide", function(self)
		if self.ticker then self.ticker:Cancel() end
		self.ticker = nil
	end)
end

function GuildList:Toggle()
	if not frame then CreateWindow() end
	frame:SetShown(not frame:IsShown())
end

function GuildList:IsShown()
	return frame ~= nil and frame:IsShown()
end

ns.On("ROSTER_CHANGED", QueueRefresh)
ns.On("LAYER_CHANGED", QueueRefresh)
ns.RegisterGameEvent("GUILD_ROSTER_UPDATE", QueueRefresh)
