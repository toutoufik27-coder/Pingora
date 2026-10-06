-- Assigns the 8 plots of the valley to players and keeps each farm's
-- visuals (tiles, crops, workshops, animals) in sync with their profile.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Net = require(Shared.Net)
local Lands = require(Shared.Config.Lands)
local Workshops = require(Shared.Config.Workshops)
local Animals = require(Shared.Config.Animals)
local Products = require(Shared.Config.Products)
local Economy = require(Shared.Config.Economy)
local Growth = require(Shared.Logic.Growth)
local Plot = require(Shared.Logic.Plot)
local Make = require(script.Parent.Parent.World.Make)
local CropVisual = require(script.Parent.Parent.World.CropVisual)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local DataService, Progress

local PlotService = {}

local TILE = Economy.TILE_SIZE
local GRID_CENTER_Z = 20 -- local z of the grid centre (toward the plaza)

type PlotState = {
	index: number,
	player: Player?,
	model: Model,
	dynamic: Folder?,
	tileParts: { [string]: BasePart },
	cropModels: { [string]: Model },
	stages: { [string]: string }, -- cache: stage + mutation signature
	buildings: Folder?,
	animals: Folder?,
}

local plots: { PlotState } = {}

-- Workshop pads in plot-local coordinates: 4 behind the field, 4 on the right.
local PADS = {
	Vector3.new(-45, 0, -48),
	Vector3.new(-15, 0, -48),
	Vector3.new(15, 0, -48),
	Vector3.new(45, 0, -48),
	Vector3.new(56, 0, -8),
	Vector3.new(56, 0, 14),
	Vector3.new(56, 0, 36),
	Vector3.new(56, 0, 58),
}
local YARD_ORIGIN = Vector3.new(-56, 0, -14) -- first animal spot (local)

function PlotService.frame(index: number): CFrame
	return WorldBuilder.plotFrames[index]
end

function PlotService.tileLocal(key: string): Vector3?
	local x, y = Plot.parseKey(key)
	if not x then
		return nil
	end
	local half = (Plot.MAX + 1) / 2
	return Vector3.new((x - half) * TILE, 0, GRID_CENTER_Z + (y - half) * TILE)
end

function PlotService.tileCFrame(index: number, key: string): CFrame?
	local lp = PlotService.tileLocal(key)
	if not lp then
		return nil
	end
	return PlotService.frame(index) * CFrame.new(lp + Vector3.new(0, 0.8, 0))
end

function PlotService.ownerOf(index: number): Player?
	local s = plots[index]
	return s and s.player
end

function PlotService.indexOf(player: Player): number?
	for i, s in plots do
		if s.player == player then
			return i
		end
	end
	return nil
end

function PlotService.occupied(): { { index: number, player: Player, profile: any } }
	local out = {}
	for i, s in plots do
		if s.player and s.player.Parent then
			local p = DataService.get(s.player)
			if p then
				table.insert(out, { index = i, player = s.player, profile = p })
			end
		end
	end
	return out
end

function PlotService.neighbourIndices(index: number): { number }
	return WorldBuilder.neighbours[index] or {}
end

function PlotService.workshopPad(index: number, workshopId: string): CFrame?
	for i, w in Workshops.list do
		if w.id == workshopId then
			local pad = PADS[i]
			return pad and PlotService.frame(index) * CFrame.new(pad)
		end
	end
	return nil
end

---------------------------------------------------------------- rendering

local function landColor(p: any): Color3
	local land = p and p.Land and Lands[p.Land]
	if land then
		return Make.color(land.color)
	end
	return Color3.fromRGB(150, 175, 110)
end

local function themeOf(p: any)
	for _, t in Products.themes do
		if t.id == (p and p.Theme) then
			return t
		end
	end
	return Products.themes[1]
end

local function stageSignature(tile: any, now: number): string
	local stage = Growth.stage(tile, now)
	local muts = tile.mutations and table.concat(tile.mutations, ",") or ""
	return stage .. "|" .. muts .. "|" .. (if tile.watered then "w" else "") .. (if tile.shared then "s" else "")
end

function PlotService.refreshTile(index: number, key: string)
	local s = plots[index]
	if not s or not s.player then
		return
	end
	local p = DataService.get(s.player)
	local part = s.tileParts[key]
	if not p or not part then
		return
	end
	local tile = p.Tiles[key]
	local old = s.cropModels[key]
	if old then
		old:Destroy()
		s.cropModels[key] = nil
	end
	s.stages[key] = nil
	if not tile then
		part.Color = Color3.fromRGB(120, 85, 55)
		part:SetAttribute("Crop", nil)
		part:SetAttribute("Ready", nil)
		part:SetAttribute("Shared", nil)
		return
	end
	local now = os.time()
	local stage = Growth.stage(tile, now)
	part.Color = if tile.watered then Color3.fromRGB(85, 60, 40) else Color3.fromRGB(120, 85, 55)
	part:SetAttribute("Crop", tile.crop)
	part:SetAttribute("Ready", tile.ready)
	part:SetAttribute("Start", tile.start)
	part:SetAttribute("Shared", tile.shared == true)
	part:SetAttribute("Mutations", tile.mutations and table.concat(tile.mutations, ",") or "")
	local top = part.CFrame * CFrame.new(0, part.Size.Y / 2, 0)
	s.cropModels[key] = CropVisual.build(s.dynamic :: Folder, top, tile.crop, stage, tile.mutations)
	s.stages[key] = stageSignature(tile, now)
end

local function buildTiles(s: PlotState, p: any)
	local frame = PlotService.frame(s.index)
	local tilesFolder = Make.folder("Tiles", s.dynamic :: Folder)
	for _, key in Plot.unlockedKeys(p.PlotSize) do
		local lp = PlotService.tileLocal(key) :: Vector3
		local part = Make.part({
			Name = "Tile_" .. key,
			Size = Vector3.new(TILE - 0.3, 0.5, TILE - 0.3),
			CFrame = frame * CFrame.new(lp + Vector3.new(0, 0.85, 0)),
			Color = Color3.fromRGB(120, 85, 55),
			Material = Enum.Material.Ground,
			Parent = tilesFolder,
		})
		part:SetAttribute("PlotIndex", s.index)
		part:SetAttribute("TileKey", key)
		s.tileParts[key] = part
	end
	-- the locked ring shows rough, overgrown ground
	local lo, hi = Plot.bounds(p.PlotSize)
	local nlo, nhi = lo - 1, hi + 1
	if nlo >= 1 and nhi <= Plot.MAX then
		for x = nlo, nhi do
			for y = nlo, nhi do
				if x == nlo or x == nhi or y == nlo or y == nhi then
					local lp = PlotService.tileLocal(Plot.key(x, y)) :: Vector3
					if (x + y) % 3 == 0 then
						Make.part({
							Name = "Brush",
							Shape = Enum.PartType.Ball,
							Size = Vector3.new(3, 2, 3),
							CFrame = frame * CFrame.new(lp + Vector3.new(0, 1, 0)),
							Color = Color3.fromRGB(90, 120, 60),
							Material = Enum.Material.Grass,
							CanQuery = false,
							Parent = tilesFolder,
						})
					end
				end
			end
		end
	end
end

local function buildFence(s: PlotState, p: any)
	local frame = PlotService.frame(s.index)
	local theme = themeOf(p)
	local fenceColor = Make.color(theme.fence)
	local half = (p.PlotSize * TILE) / 2 + 1.5
	local cz = GRID_CENTER_Z
	local f = Make.folder("Fence", s.dynamic :: Folder)
	local function rail(cx: number, czz: number, sx: number, sz: number)
		Make.part({
			Name = "Rail",
			Size = Vector3.new(sx, 1.4, sz),
			CFrame = frame * CFrame.new(cx, 1.3, czz),
			Color = fenceColor,
			Material = Enum.Material.Wood,
			CanQuery = false,
			Parent = f,
		})
	end
	local len = half * 2
	rail(0, cz - half, len, 0.4)
	rail(-half, cz, 0.4, len)
	rail(half, cz, 0.4, len)
	-- front side has a gap for the entrance
	rail(-half / 2 - 3, cz + half, half - 6, 0.4)
	rail(half / 2 + 3, cz + half, half - 6, 0.4)
end

function PlotService.refreshBuildings(index: number)
	local s = plots[index]
	if not s or not s.player then
		return
	end
	local p = DataService.get(s.player)
	if s.buildings then
		s.buildings:Destroy()
	end
	local folder = Make.folder("Buildings", s.dynamic :: Folder)
	s.buildings = folder
	for i, w in Workshops.list do
		local pad = PADS[i]
		local cf = PlotService.frame(index) * CFrame.new(pad)
		if p and p.Workshops[w.id] then
			local m = Make.model("Workshop_" .. w.id, folder)
			local body = Make.part({
				Name = "Body",
				Size = Vector3.new(14, 8, 12),
				CFrame = cf * CFrame.new(0, 4.6, 0),
				Color = Make.color(w.color),
				Material = Enum.Material.WoodPlanks,
				Parent = m,
			})
			Make.part({
				Name = "Roof",
				Size = Vector3.new(16, 1.4, 14),
				CFrame = cf * CFrame.new(0, 9.3, 0),
				Color = Color3.fromRGB(150, 70, 55),
				Material = Enum.Material.Slate,
				Parent = m,
			})
			Make.sign(body, "workshop." .. w.id, nil, 7)
			local pp = Make.prompt(body, "prompt.workshop", "Open workshop", 0, 14)
			pp:SetAttribute("Workshop", w.id)
			pp:SetAttribute("PlotIndex", index)
		else
			local pad3 = Make.part({
				Name = "Pad_" .. w.id,
				Size = Vector3.new(14, 0.3, 12),
				CFrame = cf * CFrame.new(0, 0.75, 0),
				Color = Color3.fromRGB(190, 175, 140),
				Material = Enum.Material.Concrete,
				Transparency = 0.3,
				Parent = folder,
			})
			pad3:SetAttribute("PadFor", w.id)
			Make.sign(pad3, "workshop." .. w.id, nil, 3)
			local pp = Make.prompt(pad3, "prompt.build", "Build", 0, 12)
			pp:SetAttribute("BuildWorkshop", w.id)
			pp:SetAttribute("PlotIndex", index)
		end
	end
end

local function animalModel(parent: Instance, a: any, at: CFrame): Model
	local species = Animals.species[a.species]
	local color = Color3.fromRGB(240, 240, 240)
	for _, c in species.colors do
		if c.id == a.color then
			color = Make.color(c.rgb)
		end
	end
	local size = species.size
	local m = Make.model("Animal_" .. a.id, parent)
	if a.species == "Bee" then
		local hive = Make.part({ Name = "Hive", Size = Vector3.new(2.4, 2.6, 2.4), CFrame = at * CFrame.new(0, 1.3, 0), Color = color, Material = Enum.Material.Wood, Parent = m })
		m.PrimaryPart = hive
	else
		local body = Make.part({ Name = "Body", Size = Vector3.new(size * 0.8, size * 0.7, size * 1.3), CFrame = at * CFrame.new(0, size * 0.55, 0), Color = color, Parent = m })
		Make.part({ Name = "Head", Size = Vector3.new(size * 0.55, size * 0.55, size * 0.55), CFrame = body.CFrame * CFrame.new(0, size * 0.3, -size * 0.75), Color = color, Parent = m })
		m.PrimaryPart = body
	end
	return m
end

function PlotService.refreshAnimals(index: number)
	local s = plots[index]
	if not s or not s.player then
		return
	end
	local p = DataService.get(s.player)
	if s.animals then
		s.animals:Destroy()
	end
	local folder = Make.folder("Animals", s.dynamic :: Folder)
	s.animals = folder
	if not p then
		return
	end
	local ids = {}
	for id, a in p.Animals do
		if not a.companion then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	local frame = PlotService.frame(index)
	for i, id in ids do
		local a = p.Animals[id]
		local col = (i - 1) % 4
		local row = math.floor((i - 1) / 4)
		local cf = frame * CFrame.new(YARD_ORIGIN + Vector3.new(col * 6 - 9, 0.6, row * 6))
		local m = animalModel(folder, a, cf)
		local pp = Make.prompt(m.PrimaryPart :: BasePart, "prompt.animal", "Animal", 0, 10)
		pp:SetAttribute("AnimalId", id)
		pp:SetAttribute("PlotIndex", index)
	end
	-- yard sign with collect/feed all
	local sign = Make.part({
		Name = "YardSign",
		Size = Vector3.new(5, 3, 0.4),
		CFrame = frame * CFrame.new(YARD_ORIGIN + Vector3.new(-9, 2.2, -6)),
		Color = Color3.fromRGB(140, 100, 60),
		Material = Enum.Material.Wood,
		Parent = folder,
	})
	Make.sign(sign, "sign.yard", nil, 3)
	local pp = Make.prompt(sign, "prompt.yardCare", "Feed & collect all", 0.4, 12)
	pp:SetAttribute("YardCare", index)
end

local function updateSign(s: PlotState, p: any?)
	local sign = s.model:FindFirstChild("Sign") :: BasePart?
	if not sign then
		return
	end
	if s.player and p then
		sign:SetAttribute("SignKey", "sign.plotOwned")
		sign:SetAttribute("SignVars", HttpService:JSONEncode({ name = s.player.DisplayName, land = p.Land or "" }))
	else
		sign:SetAttribute("SignKey", "sign.plotFree")
		sign:SetAttribute("SignVars", nil)
	end
end

function PlotService.refreshAll(index: number)
	local s = plots[index]
	if not s then
		return
	end
	if s.dynamic then
		s.dynamic:Destroy()
		s.dynamic = nil
	end
	s.tileParts = {}
	s.cropModels = {}
	s.stages = {}
	s.buildings = nil
	s.animals = nil
	local base = s.model.PrimaryPart :: BasePart
	if not s.player then
		base.Color = Color3.fromRGB(150, 175, 110)
		updateSign(s, nil)
		return
	end
	local p = DataService.get(s.player)
	s.dynamic = Make.folder("Dynamic", s.model)
	base.Color = landColor(p)
	base:SetAttribute("Owner", s.player.UserId)
	updateSign(s, p)
	buildTiles(s, p)
	buildFence(s, p)
	for key in p.Tiles do
		if s.tileParts[key] then
			PlotService.refreshTile(index, key)
		end
	end
	PlotService.refreshBuildings(index)
	PlotService.refreshAnimals(index)
end

---------------------------------------------------------------- assignment

local function assign(player: Player, p: any)
	if PlotService.indexOf(player) then
		return
	end
	for i, s in plots do
		if not s.player then
			s.player = player
			p.__plot = i
			PlotService.refreshAll(i)
			Progress.dirty(player)
			-- move the player to their farm entrance
			task.defer(function()
				local char = player.Character or player.CharacterAdded:Wait()
				local root = char:WaitForChild("HumanoidRootPart", 10) :: BasePart?
				if root then
					local cf = PlotService.frame(i) * CFrame.new(0, 4, WorldBuilder.PLOT_DEPTH / 2 - 6)
					root.CFrame = cf * CFrame.Angles(0, math.pi, 0)
				end
			end)
			return
		end
	end
	-- valley is full (should not happen: max players = plots + visitors)
	p.__plot = nil
	Net.notify(player, "note.valleyFull", nil, "warn")
end

local function release(player: Player)
	for i, s in plots do
		if s.player == player then
			s.player = nil
			PlotService.refreshAll(i)
			local base = s.model.PrimaryPart :: BasePart
			base:SetAttribute("Owner", nil)
		end
	end
end

function PlotService.init(services)
	DataService = services.DataService
	Progress = services.ProgressService
end

function PlotService.start()
	local plotsFolder = (WorldBuilder.root :: Folder):WaitForChild("Plots")
	for i = 1, WorldBuilder.PLOT_COUNT do
		plots[i] = {
			index = i,
			player = nil,
			model = plotsFolder:WaitForChild("Plot" .. i) :: Model,
			dynamic = nil,
			tileParts = {},
			cropModels = {},
			stages = {},
		}
	end
	DataService.Loaded:Connect(assign)
	DataService.Releasing:Connect(function(player)
		release(player)
	end)
	Players.PlayerRemoving:Connect(release)

	-- stage updates: only rebuild crops whose stage or mutations changed
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.time()
			for i, s in plots do
				if s.player then
					local p = DataService.get(s.player)
					if p then
						for key, tile in p.Tiles do
							if s.tileParts[key] and s.stages[key] ~= stageSignature(tile, now) then
								PlotService.refreshTile(i, key)
							end
						end
					end
				end
			end
		end
	end)
end

return PlotService
