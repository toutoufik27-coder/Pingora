-- The screen: HUD, side buttons, hotbar host, toasts and one panel window at
-- a time. Panels live in UI/Panels and are rebuilt whenever the data they
-- listen to changes.

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local Kit = require(script.Parent.Kit)
local Locale = require(script.Parent.Parent.Locale)
local State = require(script.Parent.Parent.State)

local App = {}

App.gui = nil :: ScreenGui?
App.window = nil :: Frame?
App.current = nil :: string?
local currentArg: any = nil
local windowTitle: TextLabel
local windowBody: Frame
local panels: { [string]: any } = {}

export type Panel = {
	title: string, -- string key
	listens: { string }?, -- "Profile" | "Project" | "Trade" | "Weather" | "Trip"
	render: (ctx: any) -> (),
	wide: boolean?,
}

function App.register(name: string, panel: Panel)
	panels[name] = panel
end

local function render()
	local name = App.current
	if not name then
		return
	end
	local panel = panels[name]
	Kit.clear(windowBody)
	local titleText = Locale.t(panel.title)
	if type(currentArg) == "table" and currentArg.title then
		titleText = currentArg.title
	end
	windowTitle.Text = titleText
	local ok, err = pcall(panel.render, {
		body = windowBody,
		arg = currentArg,
		close = App.close,
		refresh = render,
	})
	if not ok then
		warn("[UI] panel " .. name .. " failed: " .. tostring(err))
	end
end
App.refresh = render

function App.open(name: string, arg: any?)
	local panel = panels[name]
	if not panel or not App.window then
		return
	end
	App.current = name
	currentArg = arg
	App.window.Size = if panel.wide then UDim2.fromOffset(640, 440) else UDim2.fromOffset(500, 420)
	App.window.Visible = true
	render()
end

function App.toggle(name: string, arg: any?)
	if App.current == name and App.window and App.window.Visible then
		App.close()
	else
		App.open(name, arg)
	end
end

function App.close()
	App.current = nil
	currentArg = nil
	if App.window then
		App.window.Visible = false
	end
end

local function onSignal(kind: string)
	local name = App.current
	if not name then
		return
	end
	local listens = panels[name].listens
	if listens and table.find(listens, kind) then
		render()
	end
end

function App.build()
	local player = Players.LocalPlayer
	local gui = Kit.new("ScreenGui", {
		Name = "KinfieldUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	App.gui = gui

	-- scale everything down on small screens
	local scale = Kit.new("UIScale", { Parent = gui })
	local function rescale()
		local cam = Workspace.CurrentCamera
		local size = cam and cam.ViewportSize or Vector2.new(1280, 720)
		scale.Scale = math.clamp(math.min(size.X / 1100, size.Y / 650), 0.55, 1.2)
	end
	rescale()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end

	-- window
	local window = Kit.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(500, 420),
		BackgroundColor3 = Kit.colors.panel,
		Visible = false,
		ZIndex = 5,
		Parent = gui,
	})
	Kit.corner(window, 14)
	Kit.stroke(window, Kit.colors.stroke, 3)
	App.window = window
	local header = Kit.new("Frame", {
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Kit.colors.header,
		Parent = window,
	})
	Kit.corner(header, 14)
	windowTitle = Kit.label("", {
		Size = UDim2.new(1, -60, 1, 0),
		Position = UDim2.fromOffset(if Locale.isRtl() then 50 else 14, 0),
		AutomaticSize = Enum.AutomaticSize.None,
		Font = Kit.font,
		TextSize = 20,
		TextColor3 = Color3.new(1, 1, 1),
		Parent = header,
	})
	Kit.button("X", App.close, {
		Size = UDim2.fromOffset(36, 32),
		Position = if Locale.isRtl() then UDim2.fromOffset(6, 6) else UDim2.new(1, -42, 0, 6),
		BackgroundColor3 = Kit.colors.danger,
		Parent = header,
	})
	windowBody = Kit.new("Frame", {
		Name = "Body",
		Size = UDim2.new(1, -16, 1, -56),
		Position = UDim2.fromOffset(8, 50),
		BackgroundTransparency = 1,
		Parent = window,
	})

	GuiService.MenuOpened:Connect(App.close)
	State.ProfileChanged:Connect(function()
		onSignal("Profile")
	end)
	State.ProjectChanged:Connect(function()
		onSignal("Project")
	end)
	State.TradeChanged:Connect(function()
		onSignal("Trade")
	end)
	State.WeatherChanged:Connect(function()
		onSignal("Weather")
	end)
	State.TripChanged:Connect(function()
		onSignal("Trip")
	end)
	Locale.Changed:Connect(function()
		render()
	end)
	return gui
end

return App
