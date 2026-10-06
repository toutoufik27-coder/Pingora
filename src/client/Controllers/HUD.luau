-- Top-right status (coins, kindness, level), weather widget, trip and event
-- timers, and the column of side buttons.

local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Weather = require(Shared.Config.Weather)
local Kit = require(script.Parent.Parent.UI.Kit)
local App = require(script.Parent.Parent.UI.App)
local Locale = require(script.Parent.Parent.Locale)
local State = require(script.Parent.Parent.State)

local HUD = {}

local coinsLabel, kindLabel, levelLabel, xpBar
local weatherLabel, forecastLabel, tripLabel, eventLabel, storyLabel

local SIDE_BUTTONS = {
	{ panel = "Inventory", key = "ui.bag", color = Color3.fromRGB(200, 150, 90) },
	{ panel = "Animals", key = "ui.animals", color = Color3.fromRGB(230, 170, 120) },
	{ panel = "Quests", key = "ui.quests", color = Color3.fromRGB(110, 160, 220) },
	{ panel = "Almanac", key = "ui.almanac", color = Color3.fromRGB(150, 120, 200) },
	{ panel = "TradeList", key = "ui.trade", color = Color3.fromRGB(90, 180, 160) },
	{ panel = "Farm", key = "ui.farm", color = Color3.fromRGB(120, 175, 85) },
	{ panel = "RobuxShop", key = "ui.shop", color = Color3.fromRGB(240, 190, 50) },
	{ panel = "Settings", key = "ui.settings", color = Color3.fromRGB(150, 150, 150) },
}

local sideButtons: { TextButton } = {}

local function stat(parent: Instance, color: Color3, order: number): TextLabel
	local f = Kit.new("Frame", { Size = UDim2.fromOffset(150, 34), BackgroundColor3 = Color3.fromRGB(255, 250, 240), LayoutOrder = order, Parent = parent })
	Kit.corner(f, 10)
	Kit.stroke(f, color, 2)
	local l = Kit.label("", { Size = UDim2.new(1, -10, 1, 0), Position = UDim2.fromOffset(5, 0), AutomaticSize = Enum.AutomaticSize.None, Font = Kit.font, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Center, Parent = f })
	return l
end

local function update()
	local p = State.profile
	if not p then
		return
	end
	coinsLabel.Text = "🪙 " .. Locale.num(p.Coins)
	kindLabel.Text = "💗 " .. Locale.num(p.Kindness)
	levelLabel.Text = Locale.t("ui.level", { n = p.Level }) .. (if p.Rebirths > 0 then " ★" .. p.Rebirths else "")
	local frac = if p.XPNeed > 0 then p.XP / p.XPNeed else 1
	local fill = xpBar:FindFirstChild("Fill") :: Frame
	fill.Size = UDim2.new(math.clamp(frac, 0, 1), 0, 1, 0)
	-- story hint
	local Quests = require(Shared.Config.Quests)
	local step = Quests.story[p.Quests.story]
	if step then
		storyLabel.Text = "📜 " .. string.gsub(Locale.pick(step.text), "{n}", tostring(step.target)) .. string.format(" (%d/%d)", p.Quests.storyProgress or 0, step.target)
		storyLabel.Visible = true
	else
		storyLabel.Visible = false
	end
	for _, b in sideButtons do
		b.Text = Locale.t(b:GetAttribute("Key"))
	end
end

local function tick()
	local w = State.weather
	local now = State.now()
	if w then
		local def = Weather.types[w.id]
		if w.active and def then
			weatherLabel.Text = Locale.pick(def.name) .. " · " .. Locale.duration(w.endsAt - now)
		else
			weatherLabel.Text = Locale.t("ui.clearSky") .. " · " .. Locale.t("ui.nextIn", { t = Locale.duration(w.nextSlotAt - now) })
		end
		local parts = {}
		for _, f in w.forecast or {} do
			local d = Weather.types[f.id]
			table.insert(parts, d and Locale.pick(d.name) or f.id)
		end
		forecastLabel.Text = Locale.t("ui.forecast") .. ": " .. table.concat(parts, " → ")
	end
	local trip = State.trip
	if trip then
		tripLabel.Visible = true
		tripLabel.Text = "🧺 " .. Locale.t("ui.tripLeft", { t = Locale.duration(trip.untilTime - now) })
	else
		tripLabel.Visible = false
	end
	local p = State.profile
	if p and p.NextFox then
		eventLabel.Text = "🦊 " .. Locale.duration(p.NextFox - now) .. "   🌾 " .. Locale.duration(p.NextField - now)
	end
end

function HUD.build(gui: ScreenGui)
	local top = Kit.new("Frame", {
		Name = "TopRight",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(470, 40),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local layout = Kit.list(top, true, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	coinsLabel = stat(top, Kit.colors.gold, 1)
	kindLabel = stat(top, Kit.colors.kind, 2)
	levelLabel = stat(top, Kit.colors.button, 3)

	xpBar = Kit.progress(0, Kit.colors.button, 8)
	xpBar.AnchorPoint = Vector2.new(1, 0)
	xpBar.Position = UDim2.new(1, -10, 0, 54)
	xpBar.Size = UDim2.fromOffset(150, 8)
	xpBar.Parent = gui

	local wbox = Kit.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 70),
		Size = UDim2.fromOffset(310, 64),
		BackgroundColor3 = Color3.fromRGB(235, 245, 255),
		BackgroundTransparency = 0.1,
		Parent = gui,
	})
	Kit.corner(wbox, 10)
	Kit.padding(wbox, 6)
	Kit.list(wbox, false, 2)
	weatherLabel = Kit.label("", { Font = Kit.font, TextSize = 16, LayoutOrder = 1, Parent = wbox })
	forecastLabel = Kit.label("", { TextSize = 13, TextColor3 = Kit.colors.muted, LayoutOrder = 2, Parent = wbox })

	tripLabel = Kit.label("", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(260, 30),
		AutomaticSize = Enum.AutomaticSize.None,
		BackgroundTransparency = 0.2,
		BackgroundColor3 = Color3.fromRGB(255, 240, 200),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Kit.font,
		Visible = false,
		Parent = gui,
	})
	Kit.corner(tripLabel, 8)

	eventLabel = Kit.label("", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 140),
		Size = UDim2.fromOffset(310, 20),
		AutomaticSize = Enum.AutomaticSize.None,
		TextSize = 14,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.4,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = gui,
	})

	storyLabel = Kit.label("", {
		Position = UDim2.fromOffset(10, 60),
		Size = UDim2.fromOffset(330, 26),
		BackgroundColor3 = Color3.fromRGB(255, 250, 235),
		BackgroundTransparency = 0.1,
		TextSize = 14,
		Font = Kit.font,
		Parent = gui,
	})
	Kit.corner(storyLabel, 8)
	Kit.padding(storyLabel, 6)

	local side = Kit.new("Frame", {
		Name = "Side",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 20),
		Size = UDim2.fromOffset(96, 420),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Kit.list(side, false, 6)
	for i, def in SIDE_BUTTONS do
		local b = Kit.button(Locale.t(def.key), function()
			App.toggle(def.panel)
		end, { Size = UDim2.fromOffset(96, 42), BackgroundColor3 = def.color, LayoutOrder = i, TextSize = 14, Parent = side })
		b:SetAttribute("Key", def.key)
		table.insert(sideButtons, b)
	end

	State.ProfileChanged:Connect(update)
	Locale.Changed:Connect(update)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.5 then
			acc = 0
			tick()
		end
	end)
end

return HUD
