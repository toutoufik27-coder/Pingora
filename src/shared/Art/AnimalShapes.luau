-- Kinfield's own animal designs, built from blocks. Pure data so it can be
-- tested outside Roblox: the client turns it into parts (Controllers/Animator)
-- and the server only uses `bounds` to size the invisible root part.
--
-- Coordinates are studs in the animal's own space: ground at y = 0, the
-- animal faces -Z (Roblox LookVector), +X is its left-to-right.
--
-- bones: { name, parent, pivot } — pivot is the joint position at rest.
--   "root" always exists at the origin. The animator rotates bones around
--   their pivot (legs swing, heads nod, tails wag) and moves the root.
-- parts: { bone, size, pos, color, opts? } — pos is the rest position.
--   color is a palette key ("main", "dark", "light" come from the animal's
--   colour; the others are fixed) or an { r, g, b } table.
--   opts: rot = { x, y, z } degrees, shape = "Ball" | "Cylinder",
--   mat = material name, alpha = transparency, spots = true (adds patches
--   on "Spotted" animals), tint = false (keeps a fixed colour on rainbow).
-- style: how the animator moves it.
--   gait: "walk" (legs swing) | "hop" | "none"
--   waddle: body rolls side to side while walking
--   head: "look" | "peck" | "graze"
--   tail: "wag" | "sway" | "swish" | nil
--   wings: flaps now and then
--   stride: steps per stud walked
--   legSwing: leg swing angle in radians
--   wander: idle wander radius around its spot (0 = stays put)
--   bees: orbiting bees for the hive

export type Vec = { number }
export type Bone = { name: string, parent: string, pivot: Vec }
export type Part = { bone: string, size: Vec, pos: Vec, color: any, opts: { [string]: any }? }
export type Shape = { style: { [string]: any }, bones: { Bone }, parts: { Part } }

local AnimalShapes = {}

AnimalShapes.palette = {
	eye = { 25, 25, 30 },
	beak = { 250, 165, 40 },
	comb = { 220, 55, 55 },
	pink = { 245, 160, 170 },
	hoof = { 60, 45, 40 },
	horn = { 235, 225, 200 },
	white = { 248, 248, 245 },
	black = { 35, 35, 38 },
	face = { 70, 60, 60 },
	catEye = { 165, 210, 70 },
	wood = { 120, 85, 55 },
	roof = { 170, 105, 60 },
	beeYellow = { 250, 205, 40 },
	saddle = { 140, 60, 40 },
	collar = { 210, 50, 60 },
}

local function B(name: string, parent: string, x: number, y: number, z: number): Bone
	return { name = name, parent = parent, pivot = { x, y, z } }
end

local function P(bone: string, sx: number, sy: number, sz: number, x: number, y: number, z: number, color: any, opts: { [string]: any }?): Part
	return { bone = bone, size = { sx, sy, sz }, pos = { x, y, z }, color = color, opts = opts }
end

-- Adds a left/right pair: x is mirrored, bone names get L/R.
local function pair(parts: { Part }, bone: string, sx: number, sy: number, sz: number, x: number, y: number, z: number, color: any, opts: { [string]: any }?)
	local leftBone = if string.find(bone, "%%s") then string.format(bone, "L") else bone
	local rightBone = if string.find(bone, "%%s") then string.format(bone, "R") else bone
	table.insert(parts, P(leftBone, sx, sy, sz, -x, y, z, color, opts))
	table.insert(parts, P(rightBone, sx, sy, sz, x, y, z, color, opts))
end

-- Four legs with hooves/paws; bones legFL, legFR, legBL, legBR.
local function legs4(bones: { Bone }, parts: { Part }, parent: string, x: number, zFront: number, zBack: number, top: number, w: number, color: any, footColor: any, footH: number)
	for _, leg in { { "FL", -x, zFront }, { "FR", x, zFront }, { "BL", -x, zBack }, { "BR", x, zBack } } do
		local name = "leg" .. leg[1]
		table.insert(bones, B(name, parent, leg[2], top, leg[3]))
		table.insert(parts, P(name, w, top, w, leg[2], top / 2, leg[3], color))
		if footColor then
			table.insert(parts, P(name, w * 1.12, footH, w * 1.12, leg[2], footH / 2, leg[3], footColor))
		end
	end
end

local shapes: { [string]: () -> Shape } = {}

function shapes.Chicken(): Shape
	local bones = {
		B("body", "root", 0, 0.9, 0),
		B("head", "body", 0, 1.3, -0.35),
		B("wingL", "body", -0.5, 1.2, 0.05),
		B("wingR", "body", 0.5, 1.2, 0.05),
		B("tail", "body", 0, 1.15, 0.5),
		B("legL", "body", -0.2, 0.55, 0),
		B("legR", "body", 0.2, 0.55, 0),
	}
	local parts = {
		P("body", 0.9, 0.85, 1.1, 0, 0.95, 0.05, "main"),
		P("body", 0.8, 0.15, 0.9, 0, 0.52, 0.05, "light"),
		P("head", 0.6, 0.6, 0.6, 0, 1.55, -0.45, "main"),
		P("head", 0.22, 0.16, 0.25, 0, 1.5, -0.86, "beak", { tint = false }),
		P("head", 0.12, 0.25, 0.4, 0, 1.97, -0.45, "comb", { tint = false }),
		P("head", 0.12, 0.18, 0.08, 0, 1.33, -0.8, "comb", { tint = false }),
		P("wingL", 0.1, 0.5, 0.75, -0.5, 0.98, 0.05, "dark"),
		P("wingR", 0.1, 0.5, 0.75, 0.5, 0.98, 0.05, "dark"),
		P("tail", 0.55, 0.5, 0.2, 0, 1.35, 0.62, "dark", { rot = { 25, 0, 0 } }),
		P("legL", 0.1, 0.5, 0.1, -0.2, 0.28, 0, "beak", { tint = false }),
		P("legR", 0.1, 0.5, 0.1, 0.2, 0.28, 0, "beak", { tint = false }),
		P("legL", 0.26, 0.06, 0.32, -0.2, 0.03, -0.08, "beak", { tint = false }),
		P("legR", 0.26, 0.06, 0.32, 0.2, 0.03, -0.08, "beak", { tint = false }),
	}
	pair(parts, "head", 0.12, 0.14, 0.04, 0.16, 1.65, -0.77, "eye", { tint = false })
	return {
		style = { gait = "walk", waddle = true, head = "peck", wings = true, stride = 2.2, legSwing = 0.7, wander = 2 },
		bones = bones,
		parts = parts,
	}
end

function shapes.Duck(): Shape
	local bones = {
		B("body", "root", 0, 0.8, 0),
		B("head", "body", 0, 1.15, -0.5),
		B("wingL", "body", -0.52, 1.05, 0.1),
		B("wingR", "body", 0.52, 1.05, 0.1),
		B("tail", "body", 0, 0.95, 0.65),
		B("legL", "body", -0.22, 0.4, 0.05),
		B("legR", "body", 0.22, 0.4, 0.05),
	}
	local parts = {
		P("body", 0.95, 0.75, 1.3, 0, 0.8, 0.05, "main"),
		P("body", 0.85, 0.12, 1.1, 0, 0.42, 0.05, "light"),
		P("head", 0.35, 0.4, 0.35, 0, 1.15, -0.5, "main"),
		P("head", 0.55, 0.55, 0.55, 0, 1.45, -0.55, "main"),
		P("head", 0.36, 0.12, 0.38, 0, 1.38, -0.98, "beak", { tint = false }),
		P("wingL", 0.1, 0.45, 0.85, -0.52, 0.85, 0.1, "dark"),
		P("wingR", 0.1, 0.45, 0.85, 0.52, 0.85, 0.1, "dark"),
		P("tail", 0.4, 0.2, 0.3, 0, 1.02, 0.78, "dark", { rot = { -30, 0, 0 } }),
		P("legL", 0.1, 0.35, 0.1, -0.22, 0.2, 0.05, "beak", { tint = false }),
		P("legR", 0.1, 0.35, 0.1, 0.22, 0.2, 0.05, "beak", { tint = false }),
		P("legL", 0.3, 0.05, 0.35, -0.22, 0.025, -0.05, "beak", { tint = false }),
		P("legR", 0.3, 0.05, 0.35, 0.22, 0.025, -0.05, "beak", { tint = false }),
	}
	pair(parts, "head", 0.12, 0.14, 0.04, 0.15, 1.55, -0.835, "eye", { tint = false })
	return {
		style = { gait = "walk", waddle = true, head = "look", wings = true, stride = 2.4, legSwing = 0.6, wander = 2 },
		bones = bones,
		parts = parts,
	}
end

function shapes.Dog(): Shape
	local bones = {
		B("body", "root", 0, 1.2, 0),
		B("head", "body", 0, 1.5, -0.75),
		B("tail", "body", 0, 1.45, 0.8),
	}
	local parts = {
		P("body", 0.9, 0.8, 1.6, 0, 1.2, 0, "main", { spots = true }),
		P("body", 0.7, 0.12, 1.2, 0, 0.79, 0, "light"),
		P("head", 0.8, 0.75, 0.75, 0, 1.75, -0.95, "main"),
		P("head", 0.45, 0.35, 0.4, 0, 1.58, -1.5, "light"),
		P("head", 0.2, 0.12, 0.08, 0, 1.7, -1.72, "black", { tint = false }),
		P("head", 0.85, 0.14, 0.22, 0, 1.42, -0.68, "collar", { tint = false }),
		P("tail", 0.15, 0.15, 0.65, 0, 1.63, 1.07, "main", { rot = { -35, 0, 0 } }),
	}
	pair(parts, "head", 0.12, 0.14, 0.04, 0.2, 1.9, -1.335, "eye", { tint = false })
	pair(parts, "head", 0.18, 0.45, 0.32, 0.47, 1.75, -0.92, "dark")
	legs4(bones, parts, "body", 0.3, -0.55, 0.55, 0.85, 0.25, "main", "light", 0.12)
	return {
		style = { gait = "walk", head = "look", tail = "wag", stride = 1.4, legSwing = 0.6, wander = 2.5 },
		bones = bones,
		parts = parts,
	}
end

function shapes.Cat(): Shape
	local bones = {
		B("body", "root", 0, 0.85, 0),
		B("head", "body", 0, 1.05, -0.55),
		B("tail", "body", 0, 1.0, 0.6),
	}
	local parts = {
		P("body", 0.7, 0.6, 1.2, 0, 0.85, 0, "main"),
		P("body", 0.55, 0.1, 0.9, 0, 0.55, 0, "light"),
		P("head", 0.7, 0.6, 0.6, 0, 1.3, -0.8, "main"),
		P("head", 0.12, 0.08, 0.05, 0, 1.24, -1.115, "pink", { tint = false }),
		P("tail", 0.12, 0.12, 0.9, 0, 1.345, 0.89, "main", { rot = { -50, 0, 0 } }),
	}
	pair(parts, "head", 0.2, 0.26, 0.12, 0.22, 1.71, -0.78, "main")
	pair(parts, "head", 0.12, 0.16, 0.04, 0.22, 1.7, -0.85, "pink", { tint = false })
	pair(parts, "head", 0.14, 0.12, 0.04, 0.17, 1.38, -1.115, "catEye", { tint = false })
	legs4(bones, parts, "body", 0.22, -0.42, 0.42, 0.55, 0.18, "main", nil, 0)
	return {
		style = { gait = "walk", head = "look", tail = "sway", stride = 1.8, legSwing = 0.6, wander = 2 },
		bones = bones,
		parts = parts,
	}
end

function shapes.Cow(): Shape
	local bones = {
		B("body", "root", 0, 2.1, 0),
		B("head", "body", 0, 2.5, -1.3),
		B("tail", "body", 0, 2.6, 1.3),
	}
	local parts = {
		P("body", 1.6, 1.4, 2.6, 0, 2.1, 0, "main", { spots = true }),
		P("body", 0.6, 0.3, 0.5, 0, 1.25, 0.6, "pink", { tint = false }),
		P("head", 1.1, 1.0, 1.0, 0, 2.75, -1.75, "main"),
		P("head", 0.95, 0.5, 0.4, 0, 2.45, -2.4, "pink", { tint = false }),
		P("tail", 0.12, 1.1, 0.12, 0, 2.05, 1.33, "main"),
		P("tail", 0.22, 0.25, 0.22, 0, 1.45, 1.33, "dark"),
	}
	pair(parts, "head", 0.16, 0.4, 0.16, 0.35, 3.4, -1.6, "horn", { tint = false })
	pair(parts, "head", 0.45, 0.15, 0.28, 0.75, 3.0, -1.6, "main")
	pair(parts, "head", 0.14, 0.16, 0.04, 0.3, 2.95, -2.265, "eye", { tint = false })
	legs4(bones, parts, "body", 0.55, -0.9, 0.9, 1.4, 0.42, "main", "hoof", 0.2)
	return {
		style = { gait = "walk", head = "graze", tail = "swish", stride = 0.9, legSwing = 0.4, wander = 2 },
		bones = bones,
		parts = parts,
	}
end

function shapes.Goat(): Shape
	local bones = {
		B("body", "root", 0, 1.45, 0),
		B("head", "body", 0, 1.8, -0.75),
		B("tail", "body", 0, 1.8, 0.8),
	}
	local parts = {
		P("body", 1.0, 0.9, 1.6, 0, 1.45, 0, "main"),
		P("head", 0.65, 0.65, 0.8, 0, 2.1, -1.05, "main"),
		P("head", 0.14, 0.35, 0.1, 0, 1.68, -1.38, "light"),
		P("tail", 0.14, 0.3, 0.12, 0, 1.95, 0.85, "main", { rot = { 20, 0, 0 } }),
	}
	pair(parts, "head", 0.14, 0.55, 0.14, 0.18, 2.6, -0.9, "horn", { tint = false, rot = { 25, 0, 0 } })
	pair(parts, "head", 0.38, 0.12, 0.2, 0.5, 2.2, -1.0, "main")
	pair(parts, "head", 0.12, 0.14, 0.04, 0.2, 2.22, -1.465, "eye", { tint = false })
	legs4(bones, parts, "body", 0.32, -0.55, 0.55, 1.0, 0.22, "main", "hoof", 0.15)
	return {
		style = { gait = "walk", head = "graze", tail = "wag", stride = 1.3, legSwing = 0.5, wander = 2.5 },
		bones = bones,
		parts = parts,
	}
end

function shapes.Sheep(): Shape
	local bones = {
		B("body", "root", 0, 1.5, 0),
		B("head", "body", 0, 1.75, -0.85),
		B("tail", "body", 0, 1.6, 0.85),
	}
	local parts = {
		P("body", 1.3, 1.1, 1.7, 0, 1.5, 0, "main", { mat = "Fabric" }),
		P("body", 1.0, 0.25, 1.3, 0, 2.15, 0, "main", { mat = "Fabric" }),
		P("head", 0.6, 0.65, 0.7, 0, 1.8, -1.15, "face", { tint = false }),
		P("head", 0.7, 0.25, 0.5, 0, 2.2, -1.05, "main", { mat = "Fabric" }),
		P("tail", 0.35, 0.35, 0.25, 0, 1.65, 0.95, "main", { mat = "Fabric" }),
	}
	pair(parts, "head", 0.38, 0.12, 0.18, 0.45, 1.95, -1.05, "face", { tint = false })
	pair(parts, "head", 0.14, 0.14, 0.04, 0.17, 1.9, -1.515, "white", { tint = false })
	pair(parts, "head", 0.07, 0.08, 0.03, 0.17, 1.88, -1.54, "eye", { tint = false })
	legs4(bones, parts, "body", 0.38, -0.5, 0.5, 0.95, 0.22, "face", nil, 0)
	return {
		style = { gait = "walk", head = "graze", tail = "wag", stride = 1.3, legSwing = 0.5, wander = 2 },
		bones = bones,
		parts = parts,
	}
end

function shapes.Rabbit(): Shape
	local bones = {
		B("body", "root", 0, 0.55, 0),
		B("head", "body", 0, 0.8, -0.35),
	}
	local parts = {
		P("body", 0.7, 0.65, 0.9, 0, 0.55, 0.05, "main", { spots = true }),
		P("body", 0.5, 0.4, 0.1, 0, 0.5, -0.42, "light"),
		P("body", 0.3, 0.3, 0.25, 0, 0.65, 0.6, "white", { tint = false }),
		P("head", 0.6, 0.55, 0.55, 0, 0.98, -0.42, "main"),
		P("head", 0.1, 0.08, 0.05, 0, 0.94, -0.715, "pink", { tint = false }),
	}
	pair(parts, "head", 0.16, 0.6, 0.08, 0.15, 1.52, -0.38, "main")
	pair(parts, "head", 0.08, 0.45, 0.03, 0.15, 1.5, -0.43, "pink", { tint = false })
	pair(parts, "head", 0.12, 0.14, 0.04, 0.15, 1.05, -0.71, "eye", { tint = false })
	pair(parts, "body", 0.14, 0.3, 0.14, 0.18, 0.15, -0.25, "light")
	pair(parts, "body", 0.22, 0.22, 0.5, 0.3, 0.11, 0.25, "main")
	return {
		style = { gait = "hop", head = "look", stride = 1.2, wander = 2.5 },
		bones = bones,
		parts = parts,
	}
end

function shapes.Horse(): Shape
	local bones = {
		B("body", "root", 0, 2.8, 0),
		B("head", "body", 0, 3.2, -1.2),
		B("tail", "body", 0, 3.25, 1.4),
	}
	local parts = {
		P("body", 1.3, 1.3, 2.8, 0, 2.8, 0, "main", { spots = true }),
		P("body", 1.35, 0.15, 0.9, 0, 3.5, 0, "saddle", { tint = false }),
		P("head", 0.7, 1.5, 0.75, 0, 3.75, -1.55, "main", { rot = { -25, 0, 0 } }),
		P("head", 0.22, 1.5, 0.35, 0, 3.88, -1.28, "dark", { rot = { -25, 0, 0 } }),
		P("head", 0.65, 0.65, 1.15, 0, 4.4, -2.1, "main"),
		P("head", 0.6, 0.45, 0.3, 0, 4.25, -2.75, "light"),
		P("tail", 0.28, 1.5, 0.28, 0, 2.55, 1.66, "dark", { rot = { -20, 0, 0 } }),
	}
	pair(parts, "head", 0.16, 0.32, 0.12, 0.2, 4.85, -1.75, "main")
	pair(parts, "head", 0.04, 0.16, 0.16, 0.335, 4.5, -2.3, "eye", { tint = false })
	legs4(bones, parts, "body", 0.42, -1.0, 1.0, 2.15, 0.35, "main", "hoof", 0.25)
	return {
		style = { gait = "walk", head = "graze", tail = "swish", stride = 0.7, legSwing = 0.5, wander = 1.5 },
		bones = bones,
		parts = parts,
	}
end

function shapes.Bee(): Shape
	local bones = {
		B("body", "root", 0, 1, 0),
		B("bee1", "root", 0, 1.6, 0),
		B("bee2", "root", 0, 1.6, 0),
		B("bee3", "root", 0, 1.6, 0),
	}
	local parts = {
		P("body", 1.8, 0.4, 1.8, 0, 0.2, 0, "wood", { tint = false, mat = "Wood" }),
		P("body", 2.2, 0.9, 2.2, 0, 0.85, 0, "main", { mat = "Wood" }),
		P("body", 2.2, 0.9, 2.2, 0, 1.8, 0, "light", { mat = "Wood" }),
		P("body", 2.6, 0.3, 2.6, 0, 2.4, 0, "roof", { tint = false, mat = "Wood" }),
		P("body", 0.9, 0.15, 0.06, 0, 0.55, -1.11, "black", { tint = false }),
	}
	for i = 1, 3 do
		local bone = "bee" .. i
		table.insert(parts, P(bone, 0.32, 0.26, 0.42, 0, 1.6, 0, "beeYellow", { tint = false }))
		table.insert(parts, P(bone, 0.34, 0.28, 0.1, 0, 1.6, 0.04, "black", { tint = false }))
		table.insert(parts, P(bone, 0.4, 0.04, 0.18, 0, 1.76, 0.02, "white", { tint = false, alpha = 0.4 }))
	end
	return {
		style = { gait = "none", bees = 3, wander = 0 },
		bones = bones,
		parts = parts,
	}
end

-- The fox that runs off with harvests during the Fox Chase event.
function shapes.Fox(): Shape
	local bones = {
		B("body", "root", 0, 1.0, 0),
		B("head", "body", 0, 1.25, -0.6),
		B("tail", "body", 0, 1.15, 0.75),
	}
	local parts = {
		P("body", 0.75, 0.65, 1.4, 0, 1.0, 0, "main"),
		P("body", 0.55, 0.1, 1.0, 0, 0.66, 0, "white", { tint = false }),
		P("head", 0.7, 0.6, 0.6, 0, 1.4, -0.85, "main"),
		P("head", 0.4, 0.3, 0.4, 0, 1.28, -1.3, "white", { tint = false }),
		P("head", 0.14, 0.1, 0.06, 0, 1.38, -1.52, "black", { tint = false }),
		P("tail", 0.4, 0.4, 1.0, 0, 1.3, 1.2, "main", { rot = { -20, 0, 0 } }),
		P("tail", 0.42, 0.42, 0.3, 0, 1.47, 1.68, "white", { tint = false, rot = { -20, 0, 0 } }),
	}
	pair(parts, "head", 0.2, 0.3, 0.12, 0.22, 1.85, -0.8, "main")
	pair(parts, "head", 0.12, 0.14, 0.04, 0.17, 1.5, -1.155, "eye", { tint = false })
	legs4(bones, parts, "body", 0.24, -0.5, 0.5, 0.7, 0.18, "black", nil, 0)
	return {
		style = { gait = "walk", head = "look", tail = "sway", stride = 1.6, legSwing = 0.7, wander = 0 },
		bones = bones,
		parts = parts,
	}
end

AnimalShapes.FOX_COLOR = { 230, 120, 40 }

local cache: { [string]: Shape } = {}

function AnimalShapes.get(species: string): Shape?
	local cached = cache[species]
	if cached then
		return cached
	end
	local make = shapes[species]
	if not make then
		return nil
	end
	local shape = make()
	cache[species] = shape
	return shape
end

function AnimalShapes.has(species: string): boolean
	return shapes[species] ~= nil
end

-- Width, height and depth that cover the animal at rest.
function AnimalShapes.bounds(species: string): (number, number, number)
	local shape = AnimalShapes.get(species)
	if not shape then
		return 2, 2, 2
	end
	local w, h, d = 0, 0, 0
	for _, part in shape.parts do
		local s, p = part.size, part.pos
		-- rotated parts can reach a little further; their longest side is a safe cover
		local r = if part.opts and part.opts.rot then math.max(s[1], s[2], s[3]) / 2 else 0
		w = math.max(w, math.abs(p[1]) + math.max(s[1] / 2, r))
		h = math.max(h, p[2] + math.max(s[2] / 2, r))
		d = math.max(d, math.abs(p[3]) + math.max(s[3] / 2, r))
	end
	return w * 2, h, d * 2
end

-- Shades of the animal's colour.
function AnimalShapes.shade(rgb: Vec, key: string): Vec
	if key == "dark" then
		return { math.floor(rgb[1] * 0.75), math.floor(rgb[2] * 0.75), math.floor(rgb[3] * 0.75) }
	elseif key == "light" then
		return {
			math.floor(rgb[1] + (255 - rgb[1]) * 0.35),
			math.floor(rgb[2] + (255 - rgb[2]) * 0.35),
			math.floor(rgb[3] + (255 - rgb[3]) * 0.35),
		}
	end
	return rgb
end

-- Resolves a part's colour key to rgb for an animal of colour `rgb`.
function AnimalShapes.colorOf(key: any, rgb: Vec): Vec
	if type(key) == "table" then
		return key
	end
	if key == "main" or key == "dark" or key == "light" then
		return AnimalShapes.shade(rgb, key)
	end
	return AnimalShapes.palette[key] or rgb
end

return AnimalShapes
