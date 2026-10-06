-- Small helpers for building geometry from code.

local Make = {}

function Make.color(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

export type PartProps = {
	Name: string?,
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3?,
	Material: Enum.Material?,
	Shape: Enum.PartType?,
	Transparency: number?,
	CanCollide: boolean?,
	CanQuery: boolean?,
	CanTouch: boolean?,
	Parent: Instance?,
}

function Make.part(props: PartProps): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Name = props.Name or "Part"
	if props.Shape then
		p.Shape = props.Shape
	end
	p.Size = props.Size
	p.CFrame = props.CFrame
	p.Color = props.Color or Color3.new(1, 1, 1)
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Transparency = props.Transparency or 0
	if props.CanCollide ~= nil then
		p.CanCollide = props.CanCollide
	end
	if props.CanQuery ~= nil then
		p.CanQuery = props.CanQuery
	end
	if props.CanTouch ~= nil then
		p.CanTouch = props.CanTouch
	end
	p.Parent = props.Parent
	return p
end

function Make.folder(name: string, parent: Instance): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

function Make.model(name: string, parent: Instance?): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- A ProximityPrompt. The client replaces ActionText with the localised text
-- for `textKey` (see client Localizer).
function Make.prompt(parent: Instance, textKey: string, fallback: string, hold: number?, distance: number?): ProximityPrompt
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = fallback
	pp.ObjectText = ""
	pp.HoldDuration = hold or 0
	pp.MaxActivationDistance = distance or 12
	pp.RequiresLineOfSight = false
	pp:SetAttribute("TextKey", textKey)
	pp.Parent = parent
	return pp
end

-- Marks a part as a sign; the client draws a localised billboard on it.
function Make.sign(part: BasePart, key: string, vars: string?, offsetY: number?)
	part:SetAttribute("SignKey", key)
	if vars then
		part:SetAttribute("SignVars", vars)
	end
	part:SetAttribute("SignOffset", offsetY or 6)
end

-- A simple low-poly tree.
function Make.tree(parent: Instance, at: Vector3, scale: number, leaf: Color3?): Model
	local m = Make.model("Tree", parent)
	Make.part({
		Name = "Trunk",
		Size = Vector3.new(1.2, 6, 1.2) * scale,
		CFrame = CFrame.new(at + Vector3.new(0, 3 * scale, 0)),
		Color = Color3.fromRGB(110, 75, 45),
		Material = Enum.Material.Wood,
		Parent = m,
	})
	Make.part({
		Name = "Leaves",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(6, 6, 6) * scale,
		CFrame = CFrame.new(at + Vector3.new(0, 7 * scale, 0)),
		Color = leaf or Color3.fromRGB(80, 150, 70),
		Material = Enum.Material.Grass,
		Parent = m,
	})
	return m
end

return Make
