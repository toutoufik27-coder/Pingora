-- Draws and animates every animal on this client. The server only places an
-- invisible root part tagged "KinAnimal" (World/Make.animal); here each root
-- gets its block-built look from Shared/Art/AnimalShapes and a procedural
-- animation: legs swing when walking, heads peck or graze, tails wag, wings
-- flap, rabbits hop, bees circle their hive. Farm animals also wander a
-- little around their spot. Nothing here is sent to the server.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Animals = require(Shared.Config.Animals)
local AnimalShapes = require(Shared.Art.AnimalShapes)

local Animator = {}

local TAG = "KinAnimal"
local CULL_DISTANCE = 180 -- no animation updates beyond this
local WANDER_SPEED = 2
local SPOT_COLOR = { 55, 45, 40 }

type Rig = {
	root: BasePart,
	model: Model,
	style: { [string]: any },
	height: number,
	boneNames: { string },
	boneParent: { number },
	boneOffset: { CFrame }, -- pivot relative to the parent's pivot
	parts: { BasePart },
	partBone: { number }, -- 0 = root
	partLocal: { CFrame },
	tinted: { { part: BasePart, key: string } },
	rainbow: boolean,
	seed: number,
	-- motion state
	pos: Vector3,
	yaw: number,
	phase: number,
	move: number,
	home: Vector3?,
	target: Vector3?,
	waitUntil: number,
	lastRoot: Vector3,
	followUntil: number,
	companion: boolean,
}

local rigs: { [BasePart]: Rig } = {}
local folder: Folder

local function rgbOf(species: string, colorId: string?): ({ number }, number)
	if species == "Fox" then
		return AnimalShapes.FOX_COLOR, 1
	end
	local s = Animals.species[species]
	if not s then
		return { 240, 240, 240 }, 1
	end
	for _, c in s.colors do
		if c.id == colorId then
			return c.rgb, c.rarity
		end
	end
	return s.colors[1].rgb, s.colors[1].rarity
end

local function vec(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function color3(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function newPart(model: Model, size: Vector3, color: Color3, opts: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	if opts then
		if opts.shape then
			p.Shape = (Enum.PartType :: any)[opts.shape]
		end
		if opts.mat then
			p.Material = (Enum.Material :: any)[opts.mat]
		end
		if opts.alpha then
			p.Transparency = opts.alpha
		end
	end
	p.Size = size
	p.Color = color
	p.Parent = model
	return p
end

local function yawOf(cf: CFrame): number
	local look = cf.LookVector
	return math.atan2(-look.X, -look.Z)
end

local function build(root: BasePart): Rig?
	local species = root:GetAttribute("Species")
	if type(species) ~= "string" then
		return nil
	end
	local shape = AnimalShapes.get(species)
	if not shape then
		return nil
	end
	local colorId = root:GetAttribute("Color")
	local rgb, rarity = rgbOf(species, colorId)

	local model = Instance.new("Model")
	model.Name = species

	local index: { [string]: number } = { root = 0 }
	local pivots: { Vector3 } = {}
	local rig = {
		root = root,
		model = model,
		style = shape.style,
		height = root.Size.Y,
		boneNames = {},
		boneParent = {},
		boneOffset = {},
		parts = {},
		partBone = {},
		partLocal = {},
		tinted = {},
		rainbow = colorId == "Rainbow",
		seed = math.random() * 100,
		pos = root.Position - Vector3.new(0, root.Size.Y / 2, 0),
		yaw = yawOf(root.CFrame),
		phase = 0,
		move = 0,
		home = nil,
		target = nil,
		waitUntil = os.clock() + math.random() * 3,
		lastRoot = root.Position,
		followUntil = 0,
		companion = root:GetAttribute("Companion") == true,
	} :: Rig

	for i, b in shape.bones do
		index[b.name] = i
		local parentIndex = index[b.parent] or 0
		pivots[i] = vec(b.pivot)
		local parentPivot = if parentIndex == 0 then Vector3.zero else pivots[parentIndex]
		rig.boneNames[i] = b.name
		rig.boneParent[i] = parentIndex
		rig.boneOffset[i] = CFrame.new(pivots[i] - parentPivot)
	end

	local function addPart(boneIndex: number, size: Vector3, rest: CFrame, color: Color3, opts: { [string]: any }?)
		local p = newPart(model, size, color, opts)
		local pivot = if boneIndex == 0 then Vector3.zero else pivots[boneIndex]
		table.insert(rig.parts, p)
		table.insert(rig.partBone, boneIndex)
		table.insert(rig.partLocal, CFrame.new(-pivot) * rest)
		return p
	end

	local sparkleOn: BasePart? = nil
	for _, part in shape.parts do
		local opts = part.opts
		local boneIndex = index[part.bone] or 0
		local size = vec(part.size)
		local rest = CFrame.new(vec(part.pos))
		if opts and opts.rot then
			rest *= CFrame.Angles(math.rad(opts.rot[1]), math.rad(opts.rot[2]), math.rad(opts.rot[3]))
		end
		local p = addPart(boneIndex, size, rest, color3(AnimalShapes.colorOf(part.color, rgb)), opts)
		local key = part.color
		if (key == "main" or key == "dark" or key == "light") and not (opts and opts.tint == false) then
			table.insert(rig.tinted, { part = p, key = key })
			if not sparkleOn and key == "main" then
				sparkleOn = p
			end
		end
		-- patches on spotted animals, two on each side of the body
		if opts and opts.spots and colorId == "Spotted" then
			local spot = color3(SPOT_COLOR)
			for _, side in { -1, 1 } do
				for k, zf in { -0.22, 0.25 } do
					local s = Vector3.new(0.04, size.Y * (if k == 1 then 0.45 else 0.35), size.Z * 0.28)
					local at = rest * CFrame.new(side * (size.X / 2 + 0.01), size.Y * (if k == 1 then 0.08 else -0.1), size.Z * zf * side)
					addPart(boneIndex, s, at, spot, nil)
				end
			end
		end
	end

	-- rare colours sparkle
	if rarity >= 5 and sparkleOn then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = color3(rgb)
		sparkles.Parent = sparkleOn
	end

	model.Parent = folder
	return rig
end

---------------------------------------------------------------- posing

-- 0..1..0 bump lasting `dur` seconds, once every `period` seconds.
local function pulse(t: number, period: number, dur: number): number
	local x = t % period
	if x < dur then
		return math.sin(x / dur * math.pi)
	end
	return 0
end

local function angleLerp(a: number, b: number, k: number): number
	local d = (b - a + math.pi) % (2 * math.pi) - math.pi
	return a + d * k
end

-- Moves the rig's ground position: follow a moving root, or wander.
local function step(rig: Rig, now: number, dt: number): number
	local root = rig.root
	local half = root.Size.Y / 2
	local rootGround = root.Position - Vector3.new(0, half, 0)
	if (root.Position - rig.lastRoot).Magnitude > 0.02 then
		rig.followUntil = now + 0.6
		rig.home = nil
		rig.target = nil
	end
	rig.lastRoot = root.Position

	local before = rig.pos
	local wander = rig.style.wander or 0
	local following = now < rig.followUntil or rig.companion or wander <= 0
	if following then
		if (rig.pos - rootGround).Magnitude > 30 then
			rig.pos = rootGround -- teleported
		else
			rig.pos = rig.pos:Lerp(rootGround, math.clamp(dt * 10, 0, 1))
		end
	else
		rig.home = rig.home or rootGround
		local home = rig.home :: Vector3
		if rig.target then
			local to = (rig.target :: Vector3) - rig.pos
			local flat = Vector3.new(to.X, 0, to.Z)
			if flat.Magnitude < 0.1 then
				rig.target = nil
				rig.waitUntil = now + 2 + math.random() * 5
			else
				rig.pos += flat.Unit * math.min(flat.Magnitude, WANDER_SPEED * dt)
			end
		elseif now >= rig.waitUntil then
			local a = math.random() * math.pi * 2
			local r = math.random() * wander
			rig.target = home + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		end
		rig.pos = Vector3.new(rig.pos.X, rootGround.Y, rig.pos.Z)
	end

	local moved = rig.pos - before
	local flat = Vector3.new(moved.X, 0, moved.Z)
	local speed = if dt > 0 then flat.Magnitude / dt else 0
	if speed > 0.3 then
		rig.yaw = angleLerp(rig.yaw, math.atan2(-flat.X, -flat.Z), math.clamp(dt * 8, 0, 1))
	elseif following then
		rig.yaw = angleLerp(rig.yaw, yawOf(root.CFrame), math.clamp(dt * 4, 0, 1))
	end
	return speed
end

-- The animated offset of each bone, by name.
local function poseBone(rig: Rig, name: string, t: number): CFrame
	local style = rig.style
	local m = rig.move
	if name == "head" then
		local look = CFrame.Angles(math.sin(t * 0.9) * 0.05, math.sin(t * 0.6) * 0.35 * (1 - m), 0)
		if style.head == "peck" then
			local p = pulse(t, 3.2, 0.5) * (1 - m)
			return look * CFrame.Angles(-0.9 * p, 0, 0)
		elseif style.head == "graze" then
			local g = pulse(t, 9, 3.5) * (1 - m)
			return look * CFrame.Angles(-0.7 * math.min(1, g * 1.6) + math.sin(t * 8) * 0.04 * g, 0, 0)
		end
		return look
	elseif name == "tail" then
		if style.tail == "wag" then
			return CFrame.Angles(0, math.sin(t * 14) * 0.5, 0)
		elseif style.tail == "sway" then
			return CFrame.Angles(0, 0, math.sin(t * 1.6) * 0.35)
		elseif style.tail == "swish" then
			return CFrame.Angles(0, 0, math.sin(t * 1.3) * 0.3)
		end
	elseif name == "wingL" or name == "wingR" then
		local f = math.max(pulse(t, 6, 0.7), m * 0.4) * (0.5 + 0.5 * math.sin(t * 25)) * 0.9
		return CFrame.Angles(0, 0, if name == "wingL" then -f else f)
	elseif string.sub(name, 1, 3) == "leg" then
		local front = name == "legFL" or name == "legBR" or name == "legL"
		local swing = math.sin(rig.phase) * (style.legSwing or 0.5) * m
		return CFrame.Angles(if front then swing else -swing, 0, 0)
	elseif string.sub(name, 1, 3) == "bee" then
		local i = tonumber(string.sub(name, 4)) or 1
		local angle = t * 1.4 + i * 2.09
		return CFrame.new(math.cos(angle) * 1.9, 0.7 + math.sin(t * 3 + i) * 0.35, math.sin(angle) * 1.9) * CFrame.Angles(0, -angle, 0)
	end
	return CFrame.identity
end

local function rootPose(rig: Rig, t: number): CFrame
	local style = rig.style
	local m = rig.move
	local h = rig.height
	if style.gait == "hop" then
		local hop = math.abs(math.sin(rig.phase)) * 0.35 * m + pulse(t, 5, 0.45) * 0.25 * (1 - m)
		return CFrame.new(0, hop, 0) * CFrame.Angles(-hop * 0.6, 0, 0)
	elseif style.gait == "walk" then
		local bob = math.abs(math.sin(rig.phase)) * 0.05 * h * m + math.sin(t * 2) * 0.012 * h * (1 - m)
		local roll = if style.waddle then math.sin(rig.phase) * 0.12 * m else 0
		return CFrame.new(0, bob, 0) * CFrame.Angles(0, 0, roll)
	end
	return CFrame.identity
end

local partsBuffer: { BasePart } = {}
local framesBuffer: { CFrame } = {}

local function update(dt: number)
	local now = os.clock()
	local camera = Workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	table.clear(partsBuffer)
	table.clear(framesBuffer)
	local hue = (now * 0.15) % 1
	for root, rig in rigs do
		if not root.Parent then
			continue
		end
		if (root.Position - eye).Magnitude > CULL_DISTANCE then
			-- still keep it under its root so it is in place when we come back
			rig.pos = root.Position - Vector3.new(0, root.Size.Y / 2, 0)
			continue
		end
		local speed = step(rig, now, dt)
		rig.move += (math.clamp(speed / 1.5, 0, 1) - rig.move) * math.clamp(dt * 6, 0, 1)
		rig.phase += dt * speed * (rig.style.stride or 1.5) * math.pi
		local t = now + rig.seed

		local base = CFrame.new(rig.pos) * CFrame.Angles(0, rig.yaw, 0) * rootPose(rig, t)
		local world = { [0] = base }
		for i, name in rig.boneNames do
			world[i] = world[rig.boneParent[i]] * rig.boneOffset[i] * poseBone(rig, name, t)
		end
		for i, part in rig.parts do
			table.insert(partsBuffer, part)
			table.insert(framesBuffer, world[rig.partBone[i]] * rig.partLocal[i])
		end
		if rig.rainbow then
			for k, entry in rig.tinted do
				local v = if entry.key == "dark" then 0.75 elseif entry.key == "light" then 1 else 0.95
				local s = if entry.key == "light" then 0.35 else 0.6
				entry.part.Color = Color3.fromHSV((hue + k * 0.03) % 1, s, v)
			end
		end
	end
	if #partsBuffer > 0 then
		Workspace:BulkMoveTo(partsBuffer, framesBuffer, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

---------------------------------------------------------------- lifecycle

local function added(inst: Instance)
	if not inst:IsA("BasePart") or rigs[inst] then
		return
	end
	-- attributes can arrive a moment after the tag
	if inst:GetAttribute("Species") == nil then
		inst:GetAttributeChangedSignal("Species"):Wait()
	end
	if rigs[inst] or not inst.Parent then
		return
	end
	local rig = build(inst)
	if rig then
		rigs[inst] = rig
	end
end

local function removed(inst: Instance)
	local rig = rigs[inst :: BasePart]
	if rig then
		rigs[inst :: BasePart] = nil
		rig.model:Destroy()
	end
end

function Animator.start()
	folder = Instance.new("Folder")
	folder.Name = "AnimalLooks"
	folder.Parent = Workspace
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(inst)
		task.spawn(added, inst)
	end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(removed)
	for _, inst in CollectionService:GetTagged(TAG) do
		task.spawn(added, inst)
	end
	RunService.RenderStepped:Connect(update)
end

return Animator
