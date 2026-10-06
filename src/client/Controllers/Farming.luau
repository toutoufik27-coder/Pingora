-- The hotbar and clicking/tapping on farm tiles. Holding the button and
-- dragging works too, so a whole row can be harvested in one stroke.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Net = require(Shared.Net)
local Crops = require(Shared.Config.Crops)
local Economy = require(Shared.Config.Economy)
local Weather = require(Shared.Config.Weather)
local Kit = require(script.Parent.Parent.UI.Kit)
local App = require(script.Parent.Parent.UI.App)
local Locale = require(script.Parent.Parent.Locale)
local State = require(script.Parent.Parent.State)

local Farming = {}

Farming.tool = "Basket"
Farming.seed = nil :: string?

local TOOLS = {
	{ id = "Basket", key = "tool.basket", hotkey = Enum.KeyCode.One, color = Color3.fromRGB(220, 170, 90) },
	{ id = "Seeds", key = "tool.seeds", hotkey = Enum.KeyCode.Two, color = Color3.fromRGB(120, 180, 80) },
	{ id = "Can", key = "tool.can", hotkey = Enum.KeyCode.Three, color = Color3.fromRGB(90, 160, 220) },
	{ id = "Shovel", key = "tool.shovel", hotkey = Enum.KeyCode.Four, color = Color3.fromRGB(150, 120, 90) },
	{ id = "Sign", key = "tool.share", hotkey = Enum.KeyCode.Five, color = Color3.fromRGB(240, 140, 170) },
}

local buttons: { [string]: TextButton } = {}
local tooltip: TextLabel
local selection: SelectionBox
local holding = false
local lastTileKey = ""
local lastActAt = 0

local function refreshButtons()
	for id, b in buttons do
		local def
		for _, t in TOOLS do
			if t.id == id then
				def = t
			end
		end
		local text = Locale.t(def.key)
		if id == "Seeds" and Farming.seed then
			local p = State.profile
			local n = p and p.Inventory["Seed:" .. Farming.seed] or 0
			text = Locale.pick(Crops.byId[Farming.seed].name) .. " ×" .. n
		end
		b.Text = text
		local stroke = b:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = if Farming.tool == id then 0 else 1
		end
	end
end

function Farming.selectTool(id: string)
	Farming.tool = id
	if id == "Seeds" and not Farming.seed then
		App.open("Seeds")
	end
	refreshButtons()
end

function Farming.selectSeed(cropId: string)
	Farming.seed = cropId
	Farming.tool = "Seeds"
	refreshButtons()
end

local function raycast(screenPos: Vector2): RaycastResult?
	local cam = Workspace.CurrentCamera
	if not cam then
		return nil
	end
	local ray = cam:ScreenPointToRay(screenPos.X, screenPos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local char = Players.LocalPlayer.Character
	params.FilterDescendantsInstances = if char then { char } else {}
	return Workspace:Raycast(ray.Origin, ray.Direction * 400, params)
end

local function tileFrom(result: RaycastResult?): (BasePart?, number?, string?)
	if not result then
		return nil
	end
	local part = result.Instance
	local plot = part:GetAttribute("PlotIndex")
	local key = part:GetAttribute("TileKey")
	if plot and key then
		return part, plot, key
	end
	return nil
end

local function isMine(plotIndex: number): boolean
	local p = State.profile
	return p ~= nil and p.PlotIndex == plotIndex
end

local function tileInfo(part: BasePart, plotIndex: number): string
	local crop = part:GetAttribute("Crop")
	if not crop then
		return if isMine(plotIndex) then Locale.t("tile.empty") else ""
	end
	local c = Crops.byId[crop]
	local now = State.now()
	local ready = part:GetAttribute("Ready") or now
	local start = part:GetAttribute("Start") or now
	local lines = { Locale.pick(c.name) }
	if now < ready then
		table.insert(lines, Locale.t("tile.growing", { t = Locale.duration(ready - now) }))
	else
		local window = math.max(Economy.FRESH_WINDOW_MIN, (ready - start) * Economy.FRESH_WINDOW_MULT)
		if now >= ready + window then
			table.insert(lines, Locale.t("tile.overripe"))
		else
			table.insert(lines, Locale.t("tile.ready"))
		end
	end
	local muts = part:GetAttribute("Mutations")
	if muts and muts ~= "" then
		local names = {}
		for m in string.gmatch(muts, "[^,]+") do
			local def = Weather.mutations[m]
			table.insert(names, def and Locale.pick(def.name) or m)
		end
		table.insert(lines, "✨ " .. table.concat(names, ", "))
	end
	if part:GetAttribute("Shared") then
		table.insert(lines, Locale.t("tile.shared"))
	end
	if not isMine(plotIndex) and now >= ready then
		table.insert(lines, Locale.t("tile.canGlean"))
	end
	return table.concat(lines, "\n")
end

local function act(part: BasePart, plotIndex: number, key: string)
	local now = os.clock()
	if key == lastTileKey and now - lastActAt < 0.6 then
		return
	end
	if now - lastActAt < 0.12 then
		return
	end
	lastTileKey = key
	lastActAt = now
	local tool = Farming.tool
	if tool == "Basket" then
		Net.action("Harvest", plotIndex, key)
	elseif tool == "Seeds" then
		if not Farming.seed then
			App.open("Seeds")
			return
		end
		if isMine(plotIndex) and not part:GetAttribute("Crop") then
			Net.action("Plant", plotIndex, key, Farming.seed)
		end
	elseif tool == "Can" then
		Net.action("Water", plotIndex, key)
	elseif tool == "Shovel" then
		if isMine(plotIndex) then
			Net.action("Dig", plotIndex, key)
		end
	elseif tool == "Sign" then
		if isMine(plotIndex) then
			Net.action("Share", plotIndex, key)
		end
	end
end

local function hover(screenPos: Vector2)
	local part, plot, key = tileFrom(raycast(screenPos))
	if part and plot and key then
		selection.Adornee = part
		local text = tileInfo(part, plot)
		tooltip.Text = text
		tooltip.Visible = text ~= ""
		tooltip.Position = UDim2.fromOffset(screenPos.X + 18, screenPos.Y - 10)
		if holding then
			act(part, plot, key)
		end
	else
		selection.Adornee = nil
		tooltip.Visible = false
	end
end

function Farming.build(gui: ScreenGui)
	local bar = Kit.new("Frame", {
		Name = "Hotbar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(5 * 108, 58),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local layout = Kit.list(bar, true, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	for i, t in TOOLS do
		local b = Kit.button(Locale.t(t.key), function()
			if t.id == "Seeds" and Farming.tool == "Seeds" then
				App.open("Seeds")
			end
			Farming.selectTool(t.id)
		end, { Size = UDim2.fromOffset(100, 54), BackgroundColor3 = t.color, LayoutOrder = i, TextSize = 14, Parent = bar })
		local stroke = Kit.stroke(b, Color3.new(1, 1, 1), 3)
		stroke.Transparency = 1
		buttons[t.id] = b
	end

	tooltip = Kit.label("", {
		Size = UDim2.fromOffset(220, 20),
		BackgroundColor3 = Color3.fromRGB(255, 252, 240),
		BackgroundTransparency = 0.05,
		TextSize = 14,
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	})
	Kit.corner(tooltip, 6)
	Kit.padding(tooltip, 6)

	selection = Instance.new("SelectionBox")
	selection.LineThickness = 0.08
	selection.Color3 = Color3.fromRGB(255, 255, 255)
	selection.SurfaceTransparency = 0.85
	selection.SurfaceColor3 = Color3.fromRGB(255, 255, 200)
	selection.Parent = gui

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			holding = true
			lastTileKey = ""
			local pos = Vector2.new(input.Position.X, input.Position.Y)
			local part, plot, key = tileFrom(raycast(pos))
			if part and plot and key then
				act(part, plot, key)
			end
		elseif input.UserInputType == Enum.UserInputType.Keyboard then
			for _, t in TOOLS do
				if input.KeyCode == t.hotkey then
					Farming.selectTool(t.id)
				end
			end
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			hover(Vector2.new(input.Position.X, input.Position.Y))
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			holding = false
			if input.UserInputType == Enum.UserInputType.Touch then
				tooltip.Visible = false
				selection.Adornee = nil
			end
		end
	end)

	State.ProfileChanged:Connect(refreshButtons)
	Locale.Changed:Connect(refreshButtons)
	refreshButtons()
	-- keep the tooltip's countdown fresh while hovering still
	RunService.Heartbeat:Connect(function()
		if tooltip.Visible and selection.Adornee then
			local part = selection.Adornee :: BasePart
			local plot = part:GetAttribute("PlotIndex")
			if plot then
				tooltip.Text = tileInfo(part, plot)
			end
		end
	end)
end

return Farming
