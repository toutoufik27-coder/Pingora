-- Client-side world text: localised signs (billboards), localised prompt
-- texts and the live weather board in the plaza.

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Lands = require(Shared.Config.Lands)
local Zones = require(Shared.Config.Zones)
local Workshops = require(Shared.Config.Workshops)
local Projects = require(Shared.Config.Projects)
local Weather = require(Shared.Config.Weather)
local Kit = require(script.Parent.Parent.UI.Kit)
local Locale = require(script.Parent.Parent.Locale)
local State = require(script.Parent.Parent.State)

local World = {}

local signs: { [BasePart]: TextLabel } = {}
local prompts: { ProximityPrompt } = {}

local function signText(key: string, varsJson: string?): string
	if string.sub(key, 1, 5) == "zone." then
		local z = Zones.byId[string.sub(key, 6)]
		return if z then Locale.pick(z.name) else key
	end
	if string.sub(key, 1, 9) == "workshop." then
		local w = Workshops.byId[string.sub(key, 10)]
		return if w then Locale.pick(w.name) else key
	end
	local vars = nil
	if varsJson then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, varsJson)
		if ok then
			vars = decoded
		end
	end
	if vars then
		if vars.land and Lands[vars.land] then
			vars.land = Locale.pick(Lands[vars.land].name)
		elseif vars.land == "" then
			vars.land = Locale.t("ui.noLand")
		end
		if vars.project and Projects.byId[vars.project] then
			vars.project = Locale.pick(Projects.byId[vars.project].name)
		end
	end
	return Locale.t(key, vars)
end

local function updateSign(part: BasePart)
	local label = signs[part]
	local key = part:GetAttribute("SignKey")
	if not key then
		if label then
			local bb = label.Parent
			if bb then
				bb:Destroy()
			end
			signs[part] = nil
		end
		return
	end
	if not label then
		local bb = Kit.new("BillboardGui", {
			Name = "Sign",
			Size = UDim2.fromOffset(220, 54),
			StudsOffset = Vector3.new(0, part:GetAttribute("SignOffset") or 6, 0),
			MaxDistance = 140,
			AlwaysOnTop = false,
			LightInfluence = 0,
			Adornee = part,
			Parent = part,
		})
		label = Kit.label("", {
			Size = UDim2.fromScale(1, 1),
			AutomaticSize = Enum.AutomaticSize.None,
			BackgroundColor3 = Color3.fromRGB(255, 248, 230),
			BackgroundTransparency = 0.15,
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = Kit.font,
			TextSize = 17,
			Parent = bb,
		})
		Kit.corner(label, 8)
		signs[part] = label
	end
	label.Text = signText(key, part:GetAttribute("SignVars"))
	local bb = label.Parent :: BillboardGui
	bb.StudsOffset = Vector3.new(0, part:GetAttribute("SignOffset") or 6, 0)
end

local function promptText(pp: ProximityPrompt)
	local key = pp:GetAttribute("TextKey")
	if not key then
		return
	end
	pp.ActionText = Locale.t(key)
	local zone = pp:GetAttribute("Zone")
	local ws = pp:GetAttribute("Workshop") or pp:GetAttribute("BuildWorkshop")
	if zone and Zones.byId[zone] then
		pp.ObjectText = Locale.pick(Zones.byId[zone].name)
	elseif ws and Workshops.byId[ws] then
		pp.ObjectText = Locale.pick(Workshops.byId[ws].name)
	end
end

local function watch(inst: Instance)
	if inst:IsA("BasePart") then
		if inst:GetAttribute("SignKey") ~= nil then
			updateSign(inst)
		end
		inst:GetAttributeChangedSignal("SignKey"):Connect(function()
			updateSign(inst)
		end)
		inst:GetAttributeChangedSignal("SignVars"):Connect(function()
			if signs[inst] then
				updateSign(inst)
			end
		end)
	elseif inst:IsA("ProximityPrompt") then
		table.insert(prompts, inst)
		promptText(inst)
	end
end

local boardLabel: TextLabel?

local function buildBoard()
	for _, inst in Workspace:GetDescendants() do
		if inst:IsA("BasePart") and inst:GetAttribute("WeatherBoard") then
			local sg = Kit.new("SurfaceGui", {
				Face = Enum.NormalId.Back,
				SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
				PixelsPerStud = 40,
				LightInfluence = 0,
				Adornee = inst,
				Parent = inst,
			})
			boardLabel = Kit.label("", {
				Size = UDim2.fromScale(1, 1),
				AutomaticSize = Enum.AutomaticSize.None,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextColor3 = Color3.fromRGB(255, 245, 220),
				Font = Kit.font,
				TextSize = 34,
				Parent = sg,
			})
			-- the same board readable from both sides
			local sg2 = sg:Clone()
			sg2.Face = Enum.NormalId.Front
			sg2.Parent = inst
			sg2:SetAttribute("Mirror", true)
			return
		end
	end
end

local function updateBoard()
	local w = State.weather
	if not boardLabel or not w then
		return
	end
	local now = State.now()
	local lines = {}
	local def = Weather.types[w.id]
	if w.active and def then
		table.insert(lines, "☁ " .. Locale.pick(def.name) .. " (" .. Locale.duration(w.endsAt - now) .. ")")
	else
		table.insert(lines, Locale.t("ui.clearSky"))
	end
	table.insert(lines, Locale.t("ui.forecast") .. ":")
	for _, f in w.forecast or {} do
		local d = Weather.types[f.id]
		table.insert(lines, (d and Locale.pick(d.name) or f.id) .. " — " .. Locale.duration(f.startsAt - now))
	end
	local text = table.concat(lines, "\n")
	boardLabel.Text = text
	local parent = boardLabel.Parent and boardLabel.Parent.Parent
	if parent then
		for _, sg in parent:GetChildren() do
			if sg:IsA("SurfaceGui") and sg:GetAttribute("Mirror") then
				local l = sg:FindFirstChildOfClass("TextLabel")
				if l then
					l.Text = text
				end
			end
		end
	end
end

function World.start()
	for _, inst in Workspace:GetDescendants() do
		watch(inst)
	end
	Workspace.DescendantAdded:Connect(watch)
	Workspace.DescendantRemoving:Connect(function(inst)
		if inst:IsA("BasePart") then
			signs[inst] = nil
		end
	end)
	Locale.Changed:Connect(function()
		for part in signs do
			updateSign(part)
		end
		for i = #prompts, 1, -1 do
			local pp = prompts[i]
			if pp.Parent then
				promptText(pp)
			else
				table.remove(prompts, i)
			end
		end
	end)
	task.spawn(function()
		task.wait(2)
		buildBoard()
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 1 then
			acc = 0
			updateBoard()
		end
	end)
end

return World
