-- Builds the model shown on a tile for a crop at a given stage.
-- Kept to 1-4 parts per crop so full farms stay light.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Crops = require(Shared.Config.Crops)
local Weather = require(Shared.Config.Weather)
local Growth = require(Shared.Logic.Growth)
local Make = require(script.Parent.Make)

local CropVisual = {}

local SPROUT = Color3.fromRGB(110, 190, 80)
local STEM = Color3.fromRGB(80, 140, 60)

local function sparkle(parent: BasePart, color: Color3)
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "Sparkle"
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Rate = 3
	pe.Lifetime = NumberRange.new(0.8, 1.4)
	pe.Speed = NumberRange.new(0.5, 1.5)
	pe.Size = NumberSequence.new(0.4)
	pe.Color = ColorSequence.new(color)
	pe.LightEmission = 1
	pe.Parent = parent
end

-- `origin` is the CFrame at the tile's top centre.
function CropVisual.build(parent: Instance, origin: CFrame, cropId: string, stage: number, mutations: { string }?): Model
	local c = Crops.byId[cropId]
	local m = Make.model("Crop", parent)
	local color = Make.color(c.color)
	local muts = mutations or {}
	local scale = 1
	for _, id in muts do
		if id == "Big" then
			scale = 1.5
		end
	end

	if stage == Growth.STAGE_SEED then
		Make.part({ Name = "Seed", Size = Vector3.new(0.6, 0.3, 0.6), CFrame = origin * CFrame.new(0, 0.15, 0), Color = Color3.fromRGB(120, 90, 60), CanCollide = false, Parent = m })
		return m
	end
	if stage == Growth.STAGE_SPROUT then
		Make.part({ Name = "Sprout", Size = Vector3.new(0.4, 1, 0.4), CFrame = origin * CFrame.new(0, 0.5, 0), Color = SPROUT, CanCollide = false, Parent = m })
		return m
	end

	local s = (if stage == Growth.STAGE_GROWING then 0.6 else 1) * scale
	local main: BasePart
	if c.shape == "stalk" then
		Make.part({ Name = "Stem", Size = Vector3.new(0.4, 2.6 * s, 0.4), CFrame = origin * CFrame.new(0, 1.3 * s, 0), Color = STEM, CanCollide = false, Parent = m })
		main = Make.part({ Name = "Head", Size = Vector3.new(0.9, 1.2, 0.9) * s, CFrame = origin * CFrame.new(0, 2.8 * s, 0), Color = color, CanCollide = false, Parent = m })
	elseif c.shape == "flower" then
		Make.part({ Name = "Stem", Size = Vector3.new(0.3, 2.2 * s, 0.3), CFrame = origin * CFrame.new(0, 1.1 * s, 0), Color = STEM, CanCollide = false, Parent = m })
		main = Make.part({ Name = "Bloom", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 1.6 * s, 1.6 * s), CFrame = origin * CFrame.new(0, 2.3 * s, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = color, CanCollide = false, Parent = m })
	elseif c.shape == "ball" then
		main = Make.part({ Name = "Fruit", Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 1.6, 1.8) * s, CFrame = origin * CFrame.new(0, 0.8 * s, 0), Color = color, CanCollide = false, Parent = m })
	elseif c.shape == "tree" then
		Make.part({ Name = "Trunk", Size = Vector3.new(0.6, 3 * s, 0.6), CFrame = origin * CFrame.new(0, 1.5 * s, 0), Color = Color3.fromRGB(110, 75, 45), CanCollide = false, Parent = m })
		Make.part({ Name = "Canopy", Shape = Enum.PartType.Ball, Size = Vector3.new(3.4, 3, 3.4) * s, CFrame = origin * CFrame.new(0, 3.6 * s, 0), Color = STEM, CanCollide = false, Parent = m })
		main = Make.part({ Name = "Fruit", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.9) * s, CFrame = origin * CFrame.new(0.9 * s, 3.2 * s, 0.9 * s), Color = color, CanCollide = false, Parent = m })
	else -- bush
		Make.part({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(2.2, 1.6, 2.2) * s, CFrame = origin * CFrame.new(0, 0.8 * s, 0), Color = STEM, CanCollide = false, Parent = m })
		main = Make.part({ Name = "Berries", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 0.8) * s, CFrame = origin * CFrame.new(0.5 * s, 1.4 * s, 0.3 * s), Color = color, CanCollide = false, Parent = m })
	end

	if stage == Growth.STAGE_GROWING then
		main.Color = color:Lerp(SPROUT, 0.5)
	end

	-- mutation marker: a small glowing orb in the colour of the first mutation
	local first = muts[1]
	if first and Weather.mutations[first] then
		local mc = Make.color(Weather.mutations[first].color)
		local orb = Make.part({ Name = "Mutation", Shape = Enum.PartType.Ball, Size = Vector3.new(0.6, 0.6, 0.6), CFrame = main.CFrame * CFrame.new(0, 1, 0), Color = mc, Material = Enum.Material.Neon, CanCollide = false, Parent = m })
		if first == "Golden" or first == "Rainbow" or first == "Starry" then
			main.Material = Enum.Material.Neon
			main.Color = mc
		end
		orb.CanQuery = false
	end

	if stage == Growth.STAGE_RIPE then
		sparkle(main, Color3.fromRGB(255, 255, 200))
	elseif stage == Growth.STAGE_OVERRIPE then
		-- gleanable: brighter golden sparkle that neighbours can spot
		sparkle(main, Color3.fromRGB(255, 210, 60))
		local pe = main:FindFirstChild("Sparkle") :: ParticleEmitter
		pe.Rate = 8
	end

	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanQuery = false -- clicks go to the tile under the crop
			d.CanTouch = false
		end
	end
	return m
end

return CropVisual
