-- Builds the static world from code: the plaza, river, buildings, plot
-- frames, portals and exploration zones. Nothing needs to be placed by hand
-- in Studio.
--
-- Layout (top view, +Z = south):
--   row A plots 1..4  (z = -130)
--   plaza             (z = -60 .. 60)
--   row B plots 5..8  (z = +130)

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Zones = require(Shared.Config.Zones)
local Make = require(script.Parent.Make)

local WorldBuilder = {}

WorldBuilder.PLOT_COUNT = 8
WorldBuilder.PLOT_WIDTH = 140
WorldBuilder.PLOT_DEPTH = 130
WorldBuilder.points = {} :: { [string]: Vector3 }
WorldBuilder.prompts = {} :: { [string]: ProximityPrompt }
WorldBuilder.plotFrames = {} :: { CFrame }
WorldBuilder.zoneFolders = {} :: { [string]: Folder }
WorldBuilder.root = nil :: Folder?

local GRASS = Color3.fromRGB(110, 170, 85)
local PAVING = Color3.fromRGB(205, 190, 160)
local WATER = Color3.fromRGB(70, 140, 210)

-- Plot frames: local +Z of every plot points toward the plaza.
local COLUMNS = { -225, -75, 75, 225 }
for i, x in COLUMNS do
	WorldBuilder.plotFrames[i] = CFrame.new(x, 0, -130)
end
for i, x in COLUMNS do
	WorldBuilder.plotFrames[i + 4] = CFrame.new(x, 0, 130) * CFrame.Angles(0, math.pi, 0)
end

-- Farms that count as "next to" each other (for bees, wind and honey).
WorldBuilder.neighbours = {
	[1] = { 2, 5 },
	[2] = { 1, 3, 6 },
	[3] = { 2, 4, 7 },
	[4] = { 3, 8 },
	[5] = { 6, 1 },
	[6] = { 5, 7, 2 },
	[7] = { 6, 8, 3 },
	[8] = { 7, 4 },
}

local function building(parent: Instance, name: string, at: Vector3, size: Vector3, color: Color3, roof: Color3, signKey: string)
	local m = Make.model(name, parent)
	local body = Make.part({
		Name = "Body",
		Size = size,
		CFrame = CFrame.new(at + Vector3.new(0, size.Y / 2, 0)),
		Color = color,
		Material = Enum.Material.WoodPlanks,
		Parent = m,
	})
	Make.part({
		Name = "Roof",
		Size = Vector3.new(size.X + 2, 1.5, size.Z + 2),
		CFrame = CFrame.new(at + Vector3.new(0, size.Y + 0.75, 0)),
		Color = roof,
		Material = Enum.Material.Slate,
		Parent = m,
	})
	Make.sign(body, signKey, nil, size.Y / 2 + 4)
	m.PrimaryPart = body
	return m, body
end

local function buildPlaza(root: Folder)
	local plaza = Make.folder("Plaza", root)
	-- ground for the whole valley
	Make.part({
		Name = "ValleyGround",
		Size = Vector3.new(760, 2, 520),
		CFrame = CFrame.new(0, -1, 0),
		Color = GRASS,
		Material = Enum.Material.Grass,
		Parent = plaza,
	})
	Make.part({
		Name = "PlazaPaving",
		Size = Vector3.new(600, 0.4, 110),
		CFrame = CFrame.new(0, 0.2, 0),
		Color = PAVING,
		Material = Enum.Material.Cobblestone,
		Parent = plaza,
	})
	-- river along the west edge with a small bridge
	Make.part({
		Name = "River",
		Size = Vector3.new(40, 1, 520),
		CFrame = CFrame.new(-350, -0.3, 0),
		Color = WATER,
		Material = Enum.Material.Glass,
		Transparency = 0.15,
		CanCollide = false,
		Parent = plaza,
	})
	Make.part({
		Name = "RiverBed",
		Size = Vector3.new(40, 1, 520),
		CFrame = CFrame.new(-350, -2.2, 0),
		Color = Color3.fromRGB(90, 80, 60),
		Parent = plaza,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "ValleySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(0, 0.5, 0)
	spawn.Color = Color3.fromRGB(240, 220, 170)
	spawn.Material = Enum.Material.Cobblestone
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = plaza
	WorldBuilder.points.Spawn = Vector3.new(0, 3, 0)

	-- buildings
	local _, kiosk = building(plaza, "SellKiosk", Vector3.new(-40, 0.4, -20), Vector3.new(14, 9, 10), Color3.fromRGB(230, 170, 90), Color3.fromRGB(180, 60, 50), "sign.kiosk")
	WorldBuilder.points.Kiosk = kiosk.Position
	WorldBuilder.prompts.Sell = Make.prompt(kiosk, "prompt.sellAll", "Sell crops", 0.3, 14)
	WorldBuilder.prompts.SellMenu = Make.prompt(kiosk, "prompt.sellMenu", "Choose what to sell", 0, 14)
	WorldBuilder.prompts.SellMenu.KeyboardKeyCode = Enum.KeyCode.F
	WorldBuilder.prompts.SellMenu.UIOffset = Vector2.new(0, 70)

	local _, seedShop = building(plaza, "SeedShop", Vector3.new(40, 0.4, -20), Vector3.new(14, 9, 10), Color3.fromRGB(140, 190, 110), Color3.fromRGB(70, 120, 60), "sign.seedShop")
	WorldBuilder.points.SeedShop = seedShop.Position
	WorldBuilder.prompts.SeedShop = Make.prompt(seedShop, "prompt.seedShop", "Seed shop", 0, 14)

	local _, animalShop = building(plaza, "AnimalShop", Vector3.new(110, 0.4, -20), Vector3.new(16, 9, 12), Color3.fromRGB(200, 160, 120), Color3.fromRGB(120, 80, 50), "sign.animalShop")
	WorldBuilder.points.AnimalShop = animalShop.Position
	WorldBuilder.prompts.AnimalShop = Make.prompt(animalShop, "prompt.animalShop", "Animal barn", 0, 14)

	local _, toolShop = building(plaza, "ToolShed", Vector3.new(-110, 0.4, -20), Vector3.new(14, 8, 10), Color3.fromRGB(150, 150, 160), Color3.fromRGB(80, 80, 90), "sign.toolShed")
	WorldBuilder.points.ToolShed = toolShop.Position
	WorldBuilder.prompts.ToolShed = Make.prompt(toolShop, "prompt.toolShed", "Tools", 0, 14)

	-- weather board
	local board = Make.part({
		Name = "WeatherBoard",
		Size = Vector3.new(12, 8, 1),
		CFrame = CFrame.new(0, 6, -40),
		Color = Color3.fromRGB(90, 70, 50),
		Material = Enum.Material.Wood,
		Parent = plaza,
	})
	board:SetAttribute("WeatherBoard", true)
	WorldBuilder.points.WeatherBoard = board.Position

	-- market board
	local market = Make.part({
		Name = "MarketBoard",
		Size = Vector3.new(14, 9, 1),
		CFrame = CFrame.new(-180, 6.5, -30),
		Color = Color3.fromRGB(70, 60, 90),
		Material = Enum.Material.Wood,
		Parent = plaza,
	})
	Make.sign(market, "sign.market", nil, 7)
	WorldBuilder.points.Market = market.Position
	WorldBuilder.prompts.Market = Make.prompt(market, "prompt.market", "Kinfield Market", 0, 14)

	-- valley project site
	local site = Make.part({
		Name = "ProjectSite",
		Size = Vector3.new(24, 1, 24),
		CFrame = CFrame.new(0, 0.9, 30),
		Color = Color3.fromRGB(170, 150, 120),
		Material = Enum.Material.Ground,
		Parent = plaza,
	})
	site:SetAttribute("ProjectSite", true)
	WorldBuilder.points.Project = site.Position
	WorldBuilder.prompts.Project = Make.prompt(site, "prompt.project", "Valley project", 0, 18)

	-- plaza field: free-for-all harvest race during events
	local field = Make.part({
		Name = "PlazaField",
		Size = Vector3.new(40, 0.6, 40),
		CFrame = CFrame.new(-260, 0.3, 0),
		Color = Color3.fromRGB(120, 90, 60),
		Material = Enum.Material.Ground,
		Parent = plaza,
	})
	Make.sign(field, "sign.plazaField", nil, 5)
	WorldBuilder.points.PlazaField = field.Position

	-- portals to zones at the east end
	local portals = Make.folder("Portals", plaza)
	local z = -36
	for _, zone in Zones.list do
		local pad = Make.part({
			Name = "Portal_" .. zone.id,
			Size = Vector3.new(10, 0.6, 10),
			CFrame = CFrame.new(260, 0.5, z),
			Color = Make.color(zone.ground),
			Material = Enum.Material.Neon,
			Transparency = if zone.locked then 0.6 else 0.2,
			Parent = portals,
		})
		Make.part({
			Name = "Arch",
			Size = Vector3.new(1, 12, 10),
			CFrame = CFrame.new(265.5, 6, z),
			Color = Color3.fromRGB(120, 100, 80),
			Material = Enum.Material.Wood,
			Parent = portals,
		})
		Make.sign(pad, "zone." .. zone.id, nil, 9)
		local pp = Make.prompt(pad, "prompt.travel", "Travel", 0.5, 10)
		pp:SetAttribute("Zone", zone.id)
		WorldBuilder.prompts["Portal_" .. zone.id] = pp
		z += 24
	end

	-- decoration trees around the valley edge
	local deco = Make.folder("Decor", plaza)
	local rng = Random.new(42)
	for _ = 1, 60 do
		local side = rng:NextInteger(1, 4)
		local pos
		if side == 1 then
			pos = Vector3.new(rng:NextNumber(-370, 370), 0, -250 + rng:NextNumber(-8, 8))
		elseif side == 2 then
			pos = Vector3.new(rng:NextNumber(-370, 370), 0, 250 + rng:NextNumber(-8, 8))
		elseif side == 3 then
			pos = Vector3.new(370 + rng:NextNumber(-6, 6), 0, rng:NextNumber(-240, 240))
		else
			pos = Vector3.new(-300 + rng:NextNumber(-6, 6), 0, rng:NextNumber(-240, 240))
		end
		Make.tree(deco, pos, rng:NextNumber(0.9, 1.6))
	end
end

local function buildPlotFrames(root: Folder)
	local plots = Make.folder("Plots", root)
	for i, frame in WorldBuilder.plotFrames do
		local m = Make.model("Plot" .. i, plots)
		local base = Make.part({
			Name = "Base",
			Size = Vector3.new(WorldBuilder.PLOT_WIDTH, 0.6, WorldBuilder.PLOT_DEPTH),
			CFrame = frame * CFrame.new(0, 0.3, 0),
			Color = Color3.fromRGB(150, 175, 110),
			Material = Enum.Material.Grass,
			Parent = m,
		})
		base:SetAttribute("PlotIndex", i)
		m.PrimaryPart = base
		-- path from the plaza into the plot
		Make.part({
			Name = "Path",
			Size = Vector3.new(8, 0.2, 14),
			CFrame = frame * CFrame.new(0, 0.65, WorldBuilder.PLOT_DEPTH / 2 + 4),
			Color = PAVING,
			Material = Enum.Material.Cobblestone,
			Parent = m,
		})
		local sign = Make.part({
			Name = "Sign",
			Size = Vector3.new(6, 4, 0.5),
			CFrame = frame * CFrame.new(10, 3, WorldBuilder.PLOT_DEPTH / 2 - 2),
			Color = Color3.fromRGB(140, 100, 60),
			Material = Enum.Material.Wood,
			Parent = m,
		})
		Make.sign(sign, "sign.plotFree", nil, 4)
		local claim = Make.prompt(sign, "prompt.plotMenu", "Farm", 0, 10)
		claim:SetAttribute("PlotIndex", i)
		WorldBuilder.prompts["Plot" .. i] = claim
	end
end

local function buildZones(root: Folder)
	local zonesFolder = Make.folder("Zones", root)
	for zi, zone in Zones.list do
		local origin = Vector3.new(zone.origin[1], zone.origin[2], zone.origin[3])
		local f = Make.folder(zone.id, zonesFolder)
		WorldBuilder.zoneFolders[zone.id] = f
		Make.part({
			Name = "Ground",
			Size = Vector3.new(320, 2, 320),
			CFrame = CFrame.new(origin + Vector3.new(0, -1, 0)),
			Color = Make.color(zone.ground),
			Material = if zone.id == "Mountain" or zone.id == "Caves" then Enum.Material.Rock else Enum.Material.Grass,
			Parent = f,
		})
		WorldBuilder.points["Zone_" .. zone.id] = origin + Vector3.new(0, 3, 120)
		-- return pad
		local back = Make.part({
			Name = "ReturnPad",
			Size = Vector3.new(10, 0.6, 10),
			CFrame = CFrame.new(origin + Vector3.new(0, 0.3, 140)),
			Color = Color3.fromRGB(240, 220, 170),
			Material = Enum.Material.Neon,
			Transparency = 0.2,
			Parent = f,
		})
		Make.sign(back, "sign.returnHome", nil, 5)
		local pp = Make.prompt(back, "prompt.returnHome", "Go home", 0.3, 10)
		pp:SetAttribute("ReturnFrom", zone.id)
		WorldBuilder.prompts["Return_" .. zone.id] = pp

		if zone.id == "River" then
			Make.part({
				Name = "Stream",
				Size = Vector3.new(30, 0.8, 320),
				CFrame = CFrame.new(origin + Vector3.new(-60, 0.1, 0)),
				Color = WATER,
				Material = Enum.Material.Glass,
				Transparency = 0.2,
				CanCollide = false,
				Parent = f,
			})
		elseif zone.id == "Mountain" then
			-- terraces to climb
			for step = 1, 6 do
				Make.part({
					Name = "Terrace",
					Size = Vector3.new(200 - step * 22, 6, 40),
					CFrame = CFrame.new(origin + Vector3.new(0, step * 6 - 3, -step * 22)),
					Color = Color3.fromRGB(130 + step * 5, 125 + step * 5, 115 + step * 5),
					Material = Enum.Material.Rock,
					Parent = f,
				})
			end
		end

		-- resource nodes (positions are deterministic per zone)
		local rng = Random.new(1000 + zi)
		local nodes = Make.folder("Nodes", f)
		local n = 0
		for typeId, count in zone.nodes do
			for _ = 1, count do
				n += 1
				local pos
				if typeId == "FishingSpot" then
					pos = origin + Vector3.new(-45, 0.6, rng:NextNumber(-140, 120))
				elseif zone.id == "Mountain" and typeId ~= "Tree" then
					local step = rng:NextInteger(0, 6)
					local half = math.max(10, (200 - step * 22) / 2 - 6)
					pos = origin + Vector3.new(rng:NextNumber(-half, half), step * 6, -step * 22 + rng:NextNumber(-12, 12))
				else
					pos = origin + Vector3.new(rng:NextNumber(-140, 140), 0, rng:NextNumber(-140, 110))
				end
				WorldBuilder.buildNode(nodes, typeId, zone.id .. "_" .. n, pos)
			end
		end
		if zone.locked then
			local wall = Make.part({
				Name = "ComingSoon",
				Size = Vector3.new(12, 10, 1),
				CFrame = CFrame.new(origin + Vector3.new(0, 5, 100)),
				Color = Color3.fromRGB(80, 80, 100),
				Parent = f,
			})
			Make.sign(wall, "sign.comingSoon", nil, 7)
		end
	end
end

function WorldBuilder.buildNode(parent: Instance, typeId: string, nodeId: string, pos: Vector3): Model
	local nt = Zones.nodeTypes[typeId]
	local m = Make.model("Node_" .. nodeId, parent)
	local color = Make.color(nt.color)
	local main: BasePart
	if nt.shape == "tree" then
		local t = Make.tree(m, pos, 1.3)
		main = t:FindFirstChild("Trunk") :: BasePart
	elseif nt.shape == "rock" then
		main = Make.part({ Name = "Main", Size = Vector3.new(5, 4, 5), CFrame = CFrame.new(pos + Vector3.new(0, 2, 0)) * CFrame.Angles(0, math.rad(pos.X % 90), 0), Color = color, Material = Enum.Material.Rock, Parent = m })
	elseif nt.shape == "water" then
		main = Make.part({ Name = "Main", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 7, 7), CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(140, 200, 255), Material = Enum.Material.Neon, Transparency = 0.4, Parent = m })
	elseif nt.shape == "mound" then
		main = Make.part({ Name = "Main", Shape = Enum.PartType.Ball, Size = Vector3.new(4, 2.5, 4), CFrame = CFrame.new(pos + Vector3.new(0, 0.8, 0)), Color = color, Material = Enum.Material.Ground, Parent = m })
	else
		main = Make.part({ Name = "Main", Shape = Enum.PartType.Ball, Size = Vector3.new(4, 3.5, 4), CFrame = CFrame.new(pos + Vector3.new(0, 1.6, 0)), Color = color, Material = Enum.Material.Grass, Parent = m })
	end
	m.PrimaryPart = main
	m:SetAttribute("NodeType", typeId)
	m:SetAttribute("NodeId", nodeId)
	local pp = Make.prompt(main, "prompt.gather", "Gather", 0.6, 10)
	pp:SetAttribute("NodeId", nodeId)
	pp:SetAttribute("NodeType", typeId)
	return m
end

function WorldBuilder.build(): Folder
	local workspace = game:GetService("Workspace")
	local root = Make.folder("Kinfield", workspace)
	WorldBuilder.root = root
	buildPlaza(root)
	buildPlotFrames(root)
	buildZones(root)
	return root
end

return WorldBuilder
