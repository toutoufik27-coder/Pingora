-- Toast notifications, "Open panel" requests from the server, the trade
-- invite popup, and visual effects (weather, fireworks).

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Net = require(Shared.Net)
local Crops = require(Shared.Config.Crops)
local Weather = require(Shared.Config.Weather)
local Lands = require(Shared.Config.Lands)
local Projects = require(Shared.Config.Projects)
local Animals = require(Shared.Config.Animals)
local Workshops = require(Shared.Config.Workshops)
local Kit = require(script.Parent.Parent.UI.Kit)
local App = require(script.Parent.Parent.UI.App)
local Locale = require(script.Parent.Parent.Locale)
local State = require(script.Parent.Parent.State)

local Feedback = {}

local toastHost: Frame
local KIND_COLORS = {
	info = Color3.fromRGB(255, 250, 235),
	warn = Color3.fromRGB(255, 225, 200),
	celebrate = Color3.fromRGB(255, 240, 170),
	social = Color3.fromRGB(230, 245, 255),
	discover = Color3.fromRGB(240, 225, 255),
	event = Color3.fromRGB(255, 220, 240),
}

-- Turns ids inside notification variables into localised names.
local function localiseVars(vars: { [string]: any }?): { [string]: any }?
	if not vars then
		return nil
	end
	local out = table.clone(vars)
	if out.crop and Crops.byId[out.crop] then
		out.crop = Locale.pick(Crops.byId[out.crop].name)
	end
	if out.mutation and Weather.mutations[out.mutation] then
		out.mutation = Locale.pick(Weather.mutations[out.mutation].name)
	end
	if out.land and Lands[out.land] then
		out.land = Locale.pick(Lands[out.land].name)
	end
	if out.project and Projects.byId[out.project] then
		out.project = Locale.pick(Projects.byId[out.project].name)
	end
	if out.species and Animals.species[out.species] then
		out.species = Locale.pick(Animals.species[out.species].name)
	end
	if out.workshop and Workshops.byId[out.workshop] then
		out.workshop = Locale.pick(Workshops.byId[out.workshop].name)
	end
	if out.item then
		out.item = Locale.itemName(out.item)
	end
	if out.tool then
		out.tool = Locale.t("tool." .. string.lower(out.tool))
	end
	return out
end

function Feedback.toast(text: string, kind: string?)
	local l = Kit.label(text, {
		Size = UDim2.fromOffset(380, 30),
		BackgroundColor3 = KIND_COLORS[kind or "info"] or KIND_COLORS.info,
		BackgroundTransparency = 0,
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Kit.font,
		TextSize = 16,
		Parent = toastHost,
	})
	Kit.corner(l, 10)
	Kit.stroke(l, Kit.colors.stroke, 1)
	Kit.padding(l, 6)
	task.delay(4, function()
		l:Destroy()
	end)
	-- keep at most 5
	local children = {}
	for _, c in toastHost:GetChildren() do
		if c:IsA("TextLabel") then
			table.insert(children, c)
		end
	end
	if #children > 5 then
		children[1]:Destroy()
	end
end

---------------------------------------------------------------- effects

local rainPart: Part?
local rainEmitter: ParticleEmitter?
local atmosphere: Atmosphere

local function setupWeatherFx()
	atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.25
	atmosphere.Parent = Lighting
	rainPart = Instance.new("Part")
	rainPart.Anchored = true
	rainPart.CanCollide = false
	rainPart.CanQuery = false
	rainPart.CanTouch = false
	rainPart.Transparency = 1
	rainPart.Size = Vector3.new(80, 1, 80)
	rainPart.Parent = Workspace
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Rate = 0
	pe.Lifetime = NumberRange.new(1.2)
	pe.Speed = NumberRange.new(45)
	pe.EmissionDirection = Enum.NormalId.Bottom
	pe.Size = NumberSequence.new(0.15)
	pe.Parent = rainPart
	rainEmitter = pe
	RunService.RenderStepped:Connect(function()
		local cam = Workspace.CurrentCamera
		if cam and rainPart then
			rainPart.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, 30, 0))
		end
	end)
end

local function applyWeather(w)
	if not rainEmitter then
		return
	end
	local id = if w and w.active then w.id else "Clear"
	local def = Weather.types[id]
	local sky = def and def.sky or { 170, 210, 255 }
	atmosphere.Color = Color3.fromRGB(sky[1], sky[2], sky[3])
	atmosphere.Density = if id == "Fog" then 0.55 elseif id == "Thunder" then 0.45 elseif id == "Rain" then 0.38 else 0.25
	rainEmitter.Rate = if id == "Rain" or id == "Thunder" then 400 elseif id == "Frost" then 120 else 0
	rainEmitter.Color = ColorSequence.new(if id == "Frost" then Color3.new(1, 1, 1) else Color3.fromRGB(170, 200, 255))
	rainEmitter.Speed = NumberRange.new(if id == "Frost" then 8 else 45)
	Lighting.ClockTime = if id == "Fog" or id == "Meteor" then 22 else 14
end

local function fireworks(at: Vector3?)
	local cam = Workspace.CurrentCamera
	local pos = at or (cam and cam.CFrame.Position + cam.CFrame.LookVector * 40) or Vector3.zero
	for i = 1, 5 do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Transparency = 1
		p.Size = Vector3.one
		p.CFrame = CFrame.new(pos + Vector3.new(math.random(-20, 20), 30 + math.random(0, 15), math.random(-20, 20)))
		p.Parent = Workspace
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Lifetime = NumberRange.new(1, 1.6)
		pe.Speed = NumberRange.new(20, 30)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Size = NumberSequence.new(0.8)
		pe.LightEmission = 1
		pe.Color = ColorSequence.new(Color3.fromHSV(math.random(), 0.8, 1))
		pe.Rate = 0
		pe.Parent = p
		task.delay(i * 0.25, function()
			pe:Emit(80)
		end)
		Debris:AddItem(p, 4)
	end
end

---------------------------------------------------------------- start

function Feedback.build(gui: ScreenGui)
	toastHost = Kit.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 50),
		Size = UDim2.fromOffset(380, 220),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local layout = Kit.list(toastHost, false, 4)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	Net.onPush("Notify", function(data)
		Feedback.toast(Locale.t(data.key, localiseVars(data.vars)), data.kind)
	end)
	Net.onPush("Sold", function(total)
		Feedback.toast(Locale.t("note.sold", { coins = Locale.num(total) }), "celebrate")
	end)
	Net.onPush("Gathered", function(list)
		if #list == 0 then
			Feedback.toast(Locale.t("note.gatheredNothing"), "info")
			return
		end
		local parts = {}
		for _, g in list do
			table.insert(parts, "+" .. g.n .. " " .. Locale.itemName(g.item))
		end
		Feedback.toast(table.concat(parts, "  "), "discover")
	end)
	Net.onPush("Discovered", function(key)
		Feedback.toast(Locale.t("note.almanacNew", { name = Locale.itemName(key) }), "discover")
	end)
	Net.onPush("Open", function(what)
		if type(what) == "table" then
			App.open(what.panel, what)
		else
			App.open(what)
		end
	end)
	Net.onPush("TradeInvite", function(data)
		App.open("TradeInvite", data)
	end)
	Net.onPush("Effect", function(data)
		if data.kind == "fireworks" then
			fireworks(data.at)
		end
	end)

	setupWeatherFx()
	State.WeatherChanged:Connect(applyWeather)
	State.TradeChanged:Connect(function(data)
		if data.closed then
			if data.reason then
				Feedback.toast(Locale.t(data.reason), "info")
			end
			if App.current == "Trade" then
				App.close()
			end
		elseif App.current ~= "Trade" then
			App.open("Trade")
		end
	end)
end

return Feedback
