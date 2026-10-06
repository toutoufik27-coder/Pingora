-- Kinfield's own animal designs, after the concept sheet (docs/art).
-- Built from rounded parts (ellipsoids) so they read as soft cartoon animals.
-- Pure data so it can be tested outside Roblox: the client turns it into
-- parts (Controllers/Animator) and the server only uses `bounds` to size the
-- invisible root part.
--
-- Coordinates are studs in the animal's own space: ground at y = 0, the
-- animal faces -Z (Roblox LookVector), +X is its right side.
--
-- bones: { name, parent, pivot } — pivot is the joint position at rest.
--   "root" always exists at the origin. The animator rotates bones around
--   their pivot (legs swing, heads nod, tails wag) and moves the root.
-- parts: { bone, size, pos, color, opts? } — pos is the rest position.
--   color is a palette key ("main", "soft", "dark", "light" come from the
--   animal's colour; the others are fixed) or an { r, g, b } table.
--   opts: rot = { x, y, z } degrees, shape = "Ellipsoid" | "Block" |
--   "Cylinder", mat = material name, alpha = transparency,
--   spots = true (only on "Spotted" animals), tint = false (keeps a fixed
--   colour on rainbow animals), detail = true (small crisp pieces such as
--   eyes that the mesh builder keeps separate instead of blending in).
-- style: how the animator moves it.
--   gait: "walk" (legs swing) | "hop" | "none"
--   waddle: body rolls side to side while walking
--   head: "look" | "peck" | "graze"
--   tail: "wag" | "sway" | "swish" | nil
--   wings: flaps now and then
--   stride: steps per stud walked
--   legSwing: leg swing angle in radians
--   wander: idle wander radius around its spot (0 = stays put)

export type Vec = { number }
export type Bone = { name: string, parent: string, pivot: Vec }
export type Part = { bone: string, size: Vec, pos: Vec, color: any, opts: { [string]: any }? }
export type Shape = { style: { [string]: any }, bones: { Bone }, parts: { Part } }

local AnimalShapes = {}

AnimalShapes.palette = {
	eye = { 22, 20, 24 },
	eyeWhite = { 250, 250, 250 },
	irisBrown = { 110, 62, 32 },
	beak = { 250, 160, 35 },
	comb = { 225, 45, 45 },
	pink = { 245, 155, 165 },
	nose = { 40, 32, 32 },
	hoof = { 45, 38, 36 },
	horn = { 238, 222, 185 },
	hornBrown = { 150, 100, 60 },
	white = { 250, 248, 244 },
	cream = { 250, 238, 220 },
	black = { 32, 30, 32 },
	face = { 62, 56, 58 },
	catEye = { 120, 190, 70 },
	foxLeg = { 70, 45, 38 },
	wood = { 125, 85, 55 },
	roof = { 140, 90, 55 },
	hiveYellow = { 245, 200, 70 },
	beeYellow = { 250, 200, 40 },
	wing = { 200, 230, 250 },
	collar = { 205, 40, 50 },
	gold = { 245, 195, 60 },
	tongue = { 235, 100, 115 },
	spot = { 32, 30, 32 },
}

local function B(name: string, parent: string, x: number, y: number, z: number): Bone
	return { name = name, parent = parent, pivot = { x, y, z } }
end

-- An ellipsoid (the default) part.
local function E(bone: string, sx: number, sy: number, sz: number, x: number, y: number, z: number, color: any, opts: { [string]: any }?): Part
	local o = table.clone(opts or {})
	o.shape = o.shape or "Ellipsoid"
	return { bone = bone, size = { sx, sy, sz }, pos = { x, y, z }, color = color, opts = o }
end

-- A block part.
local function K(bone: string, sx: number, sy: number, sz: number, x: number, y: number, z: number, color: any, opts: { [string]: any }?): Part
	local o = table.clone(opts or {})
	o.shape = "Block"
	return { bone = bone, size = { sx, sy, sz }, pos = { x, y, z }, color = color, opts = o }
end

local FIXED = { tint = false }
local function fixed(extra: { [string]: any }?): { [string]: any }
	local o = { tint = false }
	for k, v in extra or {} do
		o[k] = v
	end
	return o
end

-- Calls f(-1) for the left side and f(1) for the right side.
local function both(f: (number) -> ())
	f(-1)
	f(1)
end

-- Rotates (x, z) around the Y axis by `deg` like CFrame.Angles(0, rad, 0).
local function rotY(x: number, z: number, deg: number): (number, number)
	local a = math.rad(deg)
	local c, s = math.cos(a), math.sin(a)
	return x * c + z * s, -x * s + z * c
end

-- A pair of big cartoon eyes: white, iris (optional), pupil and a shine.
-- (x, y, z) is the right eye; `yaw` turns the eyes outward.
local function eyes(parts: { Part }, bone: string, x: number, y: number, z: number, r: number, yaw: number, iris: any?)
	iris = iris or "irisBrown"
	both(function(side)
		local ry = -side * yaw
		local function at(lx: number, ly: number, lz: number): (number, number, number)
			local dx, dz = rotY(lx, lz, ry)
			return side * x + dx, y + ly, z + dz
		end
		-- the white sits half inside the head so the eye is flush with the face
		local ex, ey, ez = at(0, 0, r * 0.2)
		table.insert(parts, E(bone, r * 2, r * 2.2, r * 1.0, ex, ey, ez, "eyeWhite", fixed({ rot = { 0, ry, 0 }, detail = true })))
		if iris then
			local ix, iy, iz = at(0, -r * 0.1, -r * 0.2)
			table.insert(parts, E(bone, r * 1.5, r * 1.7, r * 0.3, ix, iy, iz, iris, fixed({ rot = { 0, ry, 0 }, detail = true })))
		end
		local px, py, pz = at(0, -r * 0.1, if iris then -r * 0.28 else -r * 0.22)
		local pr = if iris then 0.8 else 1.35
		table.insert(parts, E(bone, r * pr, r * pr * 1.15, r * 0.3, px, py, pz, "eye", fixed({ rot = { 0, ry, 0 }, detail = true })))
		local hx, hy, hz = at(side * r * 0.3, r * 0.4, -r * 0.38)
		table.insert(parts, E(bone, r * 0.5, r * 0.5, r * 0.15, hx, hy, hz, "white", fixed({ rot = { 0, ry, 0 }, detail = true })))
	end)
end

-- Four legs on bones legFL, legFR, legBL, legBR, each with a foot.
-- `sock` colours the lower part of each leg.
local function legs4(bones: { Bone }, parts: { Part }, parent: string, x: number, zFront: number, zBack: number, top: number, w: number, color: any, foot: any?, footH: number, sock: any?)
	for _, leg in { { "FL", -x, zFront }, { "FR", x, zFront }, { "BL", -x, zBack }, { "BR", x, zBack } } do
		local name = "leg" .. leg[1]
		table.insert(bones, B(name, parent, leg[2], top, leg[3]))
		table.insert(parts, E(name, top, w, w, leg[2], top / 2, leg[3], color, { shape = "Cylinder", rot = { 0, 0, 90 } }))
		table.insert(parts, E(name, w * 1.1, w * 0.9, w * 1.15, leg[2], top, leg[3], color))
		if foot then
			table.insert(parts, E(name, w * 1.15, footH, w * 1.3, leg[2], footH / 2, leg[3] - w * 0.12, foot, if AnimalShapes.isShade(foot) then nil else FIXED))
		end
		if sock then
			local o = if AnimalShapes.isShade(sock) then {} else fixed()
			o.shape = "Cylinder"
			o.rot = { 0, 0, 90 }
			table.insert(parts, E(name, top * 0.45, w * 1.05, w * 1.05, leg[2], top * 0.225, leg[3], sock, o))
		end
	end
end

-- Patches that sit on an ellipsoid body: each is { u, v, w, size } where
-- (u, v, w) points from the body centre to the patch.
local function spots(parts: { Part }, bone: string, c: Vec, half: Vec, list: { { number } })
	for _, s in list do
		local len = math.sqrt(s[1] * s[1] + s[2] * s[2] + s[3] * s[3])
		local u, v, w = s[1] / len, s[2] / len, s[3] / len
		local size = s[4]
		local sx, sy, sz = size, size * 0.85, size
		-- flatten along the axis the patch faces
		local au, av, aw = math.abs(u), math.abs(v), math.abs(w)
		if au >= av and au >= aw then
			sx = size * 0.3
		elseif av >= aw then
			sy = size * 0.3
		else
			sz = size * 0.3
		end
		table.insert(parts, E(bone, sx, sy, sz, c[1] + half[1] * u * 0.93, c[2] + half[2] * v * 0.93, c[3] + half[3] * w * 0.93, "spot", fixed({ spots = true })))
	end
end

-- Moves every bone and part down by dy (used to give chunky short legs).
local function drop(bones: { Bone }, parts: { Part }, dy: number)
	for _, b in bones do
		b.pivot = { b.pivot[1], b.pivot[2] - dy, b.pivot[3] }
	end
	for _, p in parts do
		p.pos = { p.pos[1], p.pos[2] - dy, p.pos[3] }
	end
end

local shapes: { [string]: () -> Shape } = {}

function shapes.Chicken(): Shape
	local bones = {
		B("body", "root", 0, 0.95, 0),
		B("head", "body", 0, 1.45, -0.35),
		B("wingL", "body", -0.58, 1.25, 0.12),
		B("wingR", "body", 0.58, 1.25, 0.12),
		B("tail", "body", 0, 1.3, 0.62),
		B("legL", "body", -0.22, 0.6, 0.05),
		B("legR", "body", 0.22, 0.6, 0.05),
	}
	local parts = {
		-- an egg-shaped body, back end up, with a full chest
		E("body", 1.15, 1.0, 1.45, 0, 1.0, 0.12, "main", { rot = { -12, 0, 0 } }),
		E("body", 0.95, 0.95, 0.8, 0, 1.15, -0.35, "main"),
		E("head", 0.8, 0.82, 0.8, 0, 1.76, -0.46, "main"),
		E("head", 0.26, 0.2, 0.36, 0, 1.72, -0.92, "beak", FIXED),
		E("head", 0.16, 0.28, 0.18, 0, 1.5, -0.82, "comb", FIXED),
		E("head", 0.16, 0.28, 0.26, 0, 2.2, -0.62, "comb", FIXED),
		E("head", 0.16, 0.34, 0.28, 0, 2.27, -0.45, "comb", FIXED),
		E("head", 0.16, 0.28, 0.26, 0, 2.2, -0.28, "comb", FIXED),
		-- a fan of tail feathers
		E("tail", 0.3, 0.8, 0.45, 0, 1.6, 0.74, "main", { rot = { 25, 0, 0 } }),
		E("tail", 0.26, 0.7, 0.4, -0.17, 1.52, 0.7, "soft", { rot = { 25, 0, 16 } }),
		E("tail", 0.26, 0.7, 0.4, 0.17, 1.52, 0.7, "soft", { rot = { 25, 0, -16 } }),
	}
	both(function(s)
		local wing = if s < 0 then "wingL" else "wingR"
		table.insert(parts, E(wing, 0.16, 0.6, 0.92, s * 0.52, 1.05, 0.15, "soft", { rot = { 15, 0, s * 5 } }))
		table.insert(parts, E(wing, 0.13, 0.34, 0.5, s * 0.5, 1.0, 0.55, "soft", { rot = { 35, 0, s * 5 } }))
		local leg = if s < 0 then "legL" else "legR"
		table.insert(parts, E(leg, 0.55, 0.13, 0.13, s * 0.22, 0.3, 0.05, "beak", fixed({ shape = "Cylinder", rot = { 0, 0, 90 } })))
		for _, yaw in { -30, 0, 30 } do
			local dx, dz = rotY(0, -0.17, yaw)
			table.insert(parts, E(leg, 0.11, 0.07, 0.36, s * 0.22 + dx, 0.035, 0.05 + dz, "beak", fixed({ rot = { 0, yaw, 0 } })))
		end
	end)
	eyes(parts, "head", 0.22, 1.88, -0.76, 0.12, 30)
	return {
		style = { gait = "walk", waddle = true, head = "peck", wings = true, stride = 2.2, legSwing = 0.7, wander = 2 },
		bones = bones,
		parts = parts,
	}
end

function shapes.Duck(): Shape
	local bones = {
		B("body", "root", 0, 0.9, 0),
		B("head", "body", 0, 1.2, -0.45),
		B("wingL", "body", -0.57, 1.2, 0.2),
		B("wingR", "body", 0.57, 1.2, 0.2),
		B("tail", "body", 0, 1.05, 0.85),
		B("legL", "body", -0.25, 0.45, 0.1),
		B("legR", "body", 0.25, 0.45, 0.1),
	}
	local parts = {
		E("body", 1.15, 0.95, 1.7, 0, 0.9, 0.15, "main", { rot = { -8, 0, 0 } }),
		E("tail", 0.5, 0.45, 0.75, 0, 1.22, 0.98, "main", { rot = { -40, 0, 0 } }),
		E("head", 0.56, 0.95, 0.56, 0, 1.45, -0.5, "main", { rot = { -10, 0, 0 } }),
		E("head", 0.82, 0.8, 0.82, 0, 1.95, -0.56, "main"),
		E("head", 0.5, 0.18, 0.64, 0, 1.8, -1.04, "beak", FIXED),
		E("head", 0.44, 0.12, 0.54, 0, 1.72, -1.0, "beak", FIXED),
	}
	both(function(s)
		table.insert(parts, E(if s < 0 then "wingL" else "wingR", 0.15, 0.58, 1.1, s * 0.52, 1.02, 0.22, "soft", { rot = { 12, 0, s * 6 } }))
		local leg = if s < 0 then "legL" else "legR"
		table.insert(parts, E(leg, 0.44, 0.13, 0.13, s * 0.25, 0.24, 0.1, "beak", fixed({ shape = "Cylinder", rot = { 0, 0, 90 } })))
		table.insert(parts, E(leg, 0.44, 0.08, 0.58, s * 0.25, 0.04, -0.06, "beak", FIXED))
	end)
	eyes(parts, "head", 0.22, 2.04, -0.88, 0.11, 30)
	return {
		style = { gait = "walk", waddle = true, head = "look", wings = true, stride = 2.4, legSwing = 0.6, wander = 2 },
		bones = bones,
		parts = parts,
	}
end

function shapes.Dog(): Shape
	local bones = {
		B("body", "root", 0, 1.05, 0),
		B("head", "body", 0, 1.45, -0.55),
		B("tail", "body", 0, 1.3, 0.75),
	}
	local parts = {
		E("body", 1.0, 0.92, 1.55, 0, 1.05, 0.05, "main"),
		E("body", 0.78, 0.85, 0.55, 0, 1.0, -0.55, "white", FIXED),
		E("body", 0.66, 0.36, 1.05, 0, 0.66, 0.05, "white", FIXED),
		E("head", 1.12, 1.0, 1.0, 0, 1.95, -0.8, "main"),
		E("head", 0.68, 0.52, 0.56, 0, 1.74, -1.22, "white", FIXED),
		E("head", 0.24, 0.6, 0.22, 0, 2.2, -1.16, "white", fixed({ rot = { -20, 0, 0 } })),
		E("head", 0.3, 0.2, 0.2, 0, 1.9, -1.5, "nose", fixed({ detail = true })),
		E("tail", 0.3, 0.3, 0.62, 0, 1.5, 0.92, "main", { rot = { -55, 0, 0 } }),
		E("tail", 0.36, 0.38, 0.38, 0, 1.84, 1.08, "white", FIXED),
	}
	both(function(s)
		-- big floppy ears hanging beside the face
		table.insert(parts, E("head", 0.32, 0.8, 0.48, s * 0.58, 1.84, -0.72, "dark", { rot = { 0, 0, s * 12 } }))
	end)
	eyes(parts, "head", 0.26, 2.08, -1.22, 0.13, 18)
	legs4(bones, parts, "body", 0.3, -0.5, 0.5, 0.6, 0.36, "main", "white", 0.2, "white")
	return {
		style = { gait = "walk", head = "look", tail = "wag", stride = 1.4, legSwing = 0.6, wander = 2.5 },
		bones = bones,
		parts = parts,
	}
end

function shapes.Cat(): Shape
	local bones = {
		B("body", "root", 0, 0.85, 0),
		B("head", "body", 0, 1.05, -0.5),
		B("tail", "body", 0, 0.95, 0.65),
	}
	local parts = {
		E("body", 0.85, 0.75, 1.35, 0, 0.85, 0.05, "main"),
		E("body", 0.62, 0.7, 0.45, 0, 0.85, -0.5, "white", FIXED),
		E("head", 1.0, 0.9, 0.85, 0, 1.45, -0.75, "main"),
		E("head", 0.6, 0.36, 0.38, 0, 1.26, -1.06, "white", FIXED),
		E("head", 0.13, 0.08, 0.06, 0, 1.36, -1.19, "pink", fixed({ detail = true })),
		-- a tail that rises and curls forward at the tip
		E("tail", 0.24, 0.24, 0.6, 0, 1.05, 0.88, "main", { rot = { -35, 0, 0 } }),
		E("tail", 0.24, 0.65, 0.24, 0, 1.5, 1.1, "main"),
		E("tail", 0.24, 0.5, 0.24, 0, 1.9, 0.98, "main", { rot = { 40, 0, 0 } }),
		E("tail", 0.27, 0.1, 0.27, 0, 1.4, 1.1, "dark"),
		E("tail", 0.27, 0.1, 0.27, 0, 1.68, 1.09, "dark"),
	}
	-- tabby stripes across the back and the forehead
	for _, z in { -0.2, 0.1, 0.4 } do
		table.insert(parts, E("body", 0.88, 0.5, 0.1, 0, 1.0, z, "dark"))
	end
	both(function(s)
		-- pointed ears: a square turned on its corner, leaning out
		table.insert(parts, K("head", 0.38, 0.38, 0.12, s * 0.3, 1.9, -0.72, "main", { rot = { 0, 0, 45 - s * 15 } }))
		table.insert(parts, K("head", 0.22, 0.22, 0.06, s * 0.3, 1.9, -0.8, "pink", fixed({ rot = { 0, 0, 45 - s * 15 } })))
		table.insert(parts, E("head", 0.1, 0.32, 0.1, s * 0.12, 1.78, -1.12, "dark", { rot = { -20, 0, 0 } }))
	end)
	eyes(parts, "head", 0.24, 1.52, -1.08, 0.15, 15, "catEye")
	legs4(bones, parts, "body", 0.25, -0.42, 0.42, 0.5, 0.27, "main", "white", 0.14)
	return {
		style = { gait = "walk", head = "look", tail = "sway", stride = 1.8, legSwing = 0.6, wander = 2 },
		bones = bones,
		parts = parts,
	}
end

function shapes.Cow(): Shape
	local bones = {
		B("body", "root", 0, 2.0, 0),
		B("head", "body", 0, 2.4, -1.2),
		B("tail", "body", 0, 2.5, 1.3),
	}
	local parts = {
		E("body", 1.7, 1.5, 2.7, 0, 2.0, 0.05, "main"),
		E("body", 0.6, 0.35, 0.55, 0, 1.24, 0.6, "pink", FIXED),
		E("head", 1.2, 1.15, 1.1, 0, 2.75, -1.65, "main"),
		E("head", 1.0, 0.6, 0.55, 0, 2.45, -2.13, "pink", FIXED),
		E("tail", 0.13, 1.1, 0.13, 0, 1.95, 1.38, "main"),
		E("tail", 0.26, 0.42, 0.26, 0, 1.35, 1.4, "black", FIXED),
	}
	spots(parts, "body", { 0, 2.0, 0.05 }, { 0.85, 0.75, 1.35 }, {
		{ 1, 0.35, -0.3, 0.95 },
		{ -1, 0.1, 0.45, 0.9 },
		{ 1, -0.2, 0.75, 0.7 },
		{ -1, 0.5, -0.55, 0.6 },
		{ 0.2, 1, 0.3, 0.9 },
	})
	spots(parts, "head", { 0, 2.75, -1.65 }, { 0.6, 0.575, 0.55 }, { { 1, 0.5, -0.1, 0.6 } })
	both(function(s)
		table.insert(parts, E("head", 0.07, 0.07, 0.04, s * 0.2, 2.52, -2.41, "nose", fixed({ detail = true })))
		table.insert(parts, E("head", 0.2, 0.46, 0.2, s * 0.36, 3.42, -1.55, "horn", fixed({ rot = { 0, 0, -s * 25 } })))
		table.insert(parts, E("head", 0.6, 0.24, 0.36, s * 0.76, 2.96, -1.55, "main", { rot = { 0, 0, s * 20 } }))
		table.insert(parts, E("head", 0.4, 0.1, 0.22, s * 0.78, 2.95, -1.62, "pink", fixed({ rot = { 0, 0, s * 20 } })))
	end)
	eyes(parts, "head", 0.3, 2.92, -2.12, 0.13, 20)
	drop(bones, parts, 0.42)
	legs4(bones, parts, "body", 0.55, -0.9, 0.9, 0.98, 0.56, "main", "hoof", 0.3)
	return {
		style = { gait = "walk", head = "graze", tail = "swish", stride = 0.9, legSwing = 0.4, wander = 2 },
		bones = bones,
		parts = parts,
	}
end

function shapes.Goat(): Shape
	local bones = {
		B("body", "root", 0, 1.2, 0),
		B("head", "body", 0, 1.6, -0.7),
		B("tail", "body", 0, 1.55, 0.8),
	}
	local parts = {
		E("body", 1.1, 1.0, 1.6, 0, 1.2, 0.05, "main"),
		E("body", 0.85, 0.9, 0.65, 0, 1.25, -0.55, "main"),
		E("head", 0.58, 0.85, 0.58, 0, 1.73, -0.8, "main", { rot = { -20, 0, 0 } }),
		E("head", 0.8, 0.82, 0.82, 0, 2.13, -1.0, "main"),
		E("head", 0.54, 0.48, 0.54, 0, 1.92, -1.34, "light"),
		E("head", 0.18, 0.08, 0.06, 0, 1.99, -1.6, "pink", fixed({ detail = true })),
		E("head", 0.22, 0.42, 0.18, 0, 1.6, -1.42, "white", fixed({ rot = { -15, 0, 0 } })),
		E("tail", 0.2, 0.38, 0.18, 0, 1.72, 0.86, "main", { rot = { 30, 0, 0 } }),
	}
	both(function(s)
		-- horns sweep up and back along an arc
		local cy, cz, r = 2.62, -0.7, 0.32
		local steps = { 140, 105, 70, 35, 0, -35 }
		for i, deg in steps do
			local a = math.rad(deg)
			local w = 0.2 - (i - 1) * 0.022
			table.insert(parts, E("head", w, 0.3, w, s * (0.2 + i * 0.012), cy + r * math.cos(a), cz - r * math.sin(a), "hornBrown", fixed({ rot = { 90 - deg, 0, 0 } })))
		end
		-- long ears held out sideways, pink inside
		table.insert(parts, E("head", 0.56, 0.2, 0.3, s * 0.56, 2.15, -0.95, "main", { rot = { 0, 0, -s * 10 } }))
		table.insert(parts, E("head", 0.4, 0.08, 0.18, s * 0.58, 2.14, -1.02, "pink", fixed({ rot = { 0, 0, -s * 10 } })))
	end)
	eyes(parts, "head", 0.23, 2.24, -1.34, 0.12, 25)
	legs4(bones, parts, "body", 0.32, -0.55, 0.55, 0.8, 0.32, "main", "hoof", 0.22)
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
		B("tail", "body", 0, 1.6, 0.9),
	}
	local parts = {
		E("body", 1.4, 1.15, 1.8, 0, 1.5, 0.05, "main", { mat = "Fabric" }),
		E("tail", 0.45, 0.45, 0.4, 0, 1.62, 1.0, "main", { mat = "Fabric" }),
		E("head", 0.7, 0.76, 0.76, 0, 1.75, -1.1, "face", FIXED),
		E("head", 0.42, 0.36, 0.3, 0, 1.6, -1.4, "face", FIXED),
	}
	-- puffy wool: rings of puffs along the body
	for _, z in { -0.62, -0.1, 0.42, 0.85 } do
		for a = 0, 180, 45 do
			local r = math.rad(a)
			local x, y = math.cos(r) * 0.62, 1.55 + math.sin(r) * 0.5
			table.insert(parts, E("body", 0.62, 0.58, 0.62, x, y, z, "main", { mat = "Fabric" }))
		end
		both(function(s)
			table.insert(parts, E("body", 0.55, 0.52, 0.6, s * 0.6, 1.22, z, "main", { mat = "Fabric" }))
		end)
	end
	for _, p in { { -0.18, 2.12, -1.0 }, { 0.18, 2.12, -1.0 }, { 0, 2.18, -1.18 }, { 0, 2.08, -0.82 } } do
		table.insert(parts, E("head", 0.4, 0.36, 0.4, p[1], p[2], p[3], "main", { mat = "Fabric" }))
	end
	both(function(s)
		table.insert(parts, E("head", 0.46, 0.18, 0.26, s * 0.46, 1.86, -1.0, "face", fixed({ rot = { 0, 0, s * 25 } })))
	end)
	eyes(parts, "head", 0.18, 1.86, -1.43, 0.11, 22)
	drop(bones, parts, 0.22)
	legs4(bones, parts, "body", 0.38, -0.5, 0.5, 0.73, 0.3, "face", "hoof", 0.18)
	return {
		style = { gait = "walk", head = "graze", tail = "wag", stride = 1.3, legSwing = 0.5, wander = 2 },
		bones = bones,
		parts = parts,
	}
end

function shapes.Rabbit(): Shape
	local bones = {
		B("body", "root", 0, 0.6, 0),
		B("head", "body", 0, 0.95, -0.3),
	}
	local parts = {
		E("body", 0.88, 0.85, 1.05, 0, 0.6, 0.1, "main"),
		E("body", 0.58, 0.66, 0.38, 0, 0.62, -0.3, "white", FIXED),
		E("body", 0.38, 0.38, 0.32, 0, 0.6, 0.66, "white", FIXED),
		E("head", 0.82, 0.76, 0.74, 0, 1.27, -0.42, "main"),
		E("head", 0.44, 0.32, 0.28, 0, 1.12, -0.73, "white", FIXED),
		E("head", 0.1, 0.07, 0.05, 0, 1.2, -0.86, "pink", fixed({ detail = true })),
	}
	both(function(s)
		-- big haunches, long hind feet, white front paws
		table.insert(parts, E("body", 0.42, 0.62, 0.78, s * 0.37, 0.38, 0.25, "main"))
		table.insert(parts, E("body", 0.24, 0.13, 0.6, s * 0.37, 0.065, 0.1, "main"))
		table.insert(parts, E("body", 0.18, 0.38, 0.2, s * 0.18, 0.19, -0.38, "white", FIXED))
		-- long ears, wide at the base, pink inside
		table.insert(parts, E("head", 0.3, 1.0, 0.16, s * 0.17, 2.0, -0.32, "main", { rot = { -6, 0, -s * 9 } }))
		table.insert(parts, E("head", 0.17, 0.78, 0.06, s * 0.17, 2.0, -0.41, "pink", fixed({ rot = { -6, 0, -s * 9 } })))
	end)
	eyes(parts, "head", 0.22, 1.35, -0.7, 0.11, 28)
	return {
		style = { gait = "hop", head = "look", stride = 1.2, wander = 2.5 },
		bones = bones,
		parts = parts,
	}
end

function shapes.Horse(): Shape
	local bones = {
		B("body", "root", 0, 1.95, 0),
		B("head", "body", 0, 2.4, -1.1),
		B("tail", "body", 0, 2.45, 1.35),
	}
	local parts = {
		E("body", 1.45, 1.35, 2.7, 0, 1.95, 0.05, "main"),
		E("body", 1.25, 1.25, 0.95, 0, 2.05, -0.95, "main"),
		E("body", 1.32, 1.22, 0.95, 0, 2.05, 0.95, "main"),
		-- a thick neck rising to a big head
		E("head", 0.85, 1.6, 0.98, 0, 2.85, -1.45, "main", { rot = { -28, 0, 0 } }),
		E("head", 0.86, 0.86, 1.36, 0, 3.55, -1.95, "main", { rot = { 20, 0, 0 } }),
		E("head", 0.74, 0.62, 0.62, 0, 3.3, -2.5, "light"),
		E("head", 0.26, 0.74, 0.22, 0, 3.66, -2.36, "white", fixed({ rot = { 20, 0, 0 } })),
		E("head", 0.34, 0.42, 0.34, 0, 3.98, -1.85, "dark"),
		E("tail", 0.36, 0.95, 0.38, 0, 2.2, 1.56, "dark", { rot = { -35, 0, 0 } }),
		E("tail", 0.42, 1.15, 0.42, 0, 1.45, 1.8, "dark", { rot = { -12, 0, 0 } }),
		E("tail", 0.32, 0.55, 0.32, 0, 0.85, 1.9, "dark"),
	}
	-- a spiky mane along the back of the neck
	for i = 0, 4 do
		local k = i / 4
		local y, z = 3.75 - k * 1.05, -1.62 + k * 0.72
		table.insert(parts, E("head", 0.24, 0.55, 0.36, 0, y, z, "dark", { rot = { -40 + (i % 2) * 14, 0, 0 } }))
	end
	both(function(s)
		table.insert(parts, E("head", 0.22, 0.44, 0.2, s * 0.22, 4.05, -1.62, "main", { rot = { 0, 0, -s * 10 } }))
		table.insert(parts, E("head", 0.07, 0.07, 0.04, s * 0.18, 3.33, -2.8, "nose", fixed({ detail = true })))
	end)
	eyes(parts, "head", 0.36, 3.68, -2.12, 0.13, 40)
	legs4(bones, parts, "body", 0.42, -1.0, 1.0, 1.45, 0.5, "main", "hoof", 0.28, "white")
	return {
		style = { gait = "walk", head = "graze", tail = "swish", stride = 0.7, legSwing = 0.5, wander = 1.5 },
		bones = bones,
		parts = parts,
	}
end

function shapes.Bee(): Shape
	local bones = {
		B("body", "root", 0, 1, 0),
		B("bee1", "root", 0, 1.8, 0),
		B("bee2", "root", 0, 1.8, 0),
		B("bee3", "root", 0, 1.8, 0),
	}
	local parts = {
		K("body", 2.3, 0.16, 2.3, 0, 0.58, 0, "wood", fixed({ mat = "Wood", detail = true })),
		K("body", 2.0, 0.95, 2.0, 0, 1.13, 0, "main", { mat = "Wood", detail = true }),
		K("body", 2.06, 0.08, 2.06, 0, 1.62, 0, "soft", { mat = "Wood", detail = true }),
		K("body", 2.0, 0.95, 2.0, 0, 2.1, 0, "main", { mat = "Wood", detail = true }),
		K("body", 0.6, 0.08, 0.05, 0, 1.3, -1.01, "dark", { detail = true }),
		K("body", 0.6, 0.08, 0.05, 0, 2.25, -1.01, "dark", { detail = true }),
		K("body", 2.4, 0.18, 2.4, 0, 2.66, 0, "roof", fixed({ mat = "Wood", detail = true })),
		K("body", 1.9, 0.2, 1.9, 0, 2.85, 0, "roof", fixed({ mat = "Wood", detail = true })),
		K("body", 1.3, 0.2, 1.3, 0, 3.03, 0, "roof", fixed({ mat = "Wood", detail = true })),
		E("body", 0.42, 0.42, 0.1, 0, 0.82, -1.0, "black", fixed({ detail = true })),
		K("body", 0.9, 0.06, 0.3, 0, 0.64, -1.14, "wood", fixed({ mat = "Wood", detail = true })),
	}
	for _, x in { -0.85, 0.85 } do
		for _, z in { -0.85, 0.85 } do
			table.insert(parts, K("body", 0.24, 0.52, 0.24, x, 0.26, z, "wood", fixed({ mat = "Wood", detail = true })))
		end
	end
	for i = 1, 3 do
		local bone = "bee" .. i
		table.insert(parts, E(bone, 0.36, 0.34, 0.46, 0, 1.8, 0.04, "beeYellow", FIXED))
		table.insert(parts, E(bone, 0.38, 0.34, 0.09, 0, 1.8, 0.0, "black", FIXED))
		table.insert(parts, E(bone, 0.32, 0.28, 0.09, 0, 1.8, 0.18, "black", FIXED))
		table.insert(parts, E(bone, 0.3, 0.3, 0.26, 0, 1.84, -0.26, "beeYellow", FIXED))
		table.insert(parts, E(bone, 0.08, 0.1, 0.05, -0.07, 1.88, -0.39, "eye", FIXED))
		table.insert(parts, E(bone, 0.08, 0.1, 0.05, 0.07, 1.88, -0.39, "eye", FIXED))
		table.insert(parts, E(bone, 0.3, 0.04, 0.2, -0.16, 2.02, 0.02, "wing", fixed({ alpha = 0.35, rot = { 0, 0, 25 } })))
		table.insert(parts, E(bone, 0.3, 0.04, 0.2, 0.16, 2.02, 0.02, "wing", fixed({ alpha = 0.35, rot = { 0, 0, -25 } })))
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
		B("body", "root", 0, 0.92, 0),
		B("head", "body", 0, 1.15, -0.55),
		B("tail", "body", 0, 1.05, 0.75),
	}
	local parts = {
		E("body", 0.85, 0.75, 1.45, 0, 0.92, 0.05, "main"),
		E("body", 0.62, 0.65, 0.48, 0, 0.9, -0.55, "white", FIXED),
		E("head", 0.9, 0.78, 0.78, 0, 1.42, -0.8, "main"),
		E("head", 0.82, 0.38, 0.44, 0, 1.24, -0.94, "white", FIXED),
		E("head", 0.4, 0.3, 0.58, 0, 1.3, -1.22, "white", FIXED),
		E("head", 0.15, 0.11, 0.09, 0, 1.36, -1.51, "nose", fixed({ detail = true })),
		-- a big bushy tail with a white tip
		E("tail", 0.7, 0.66, 1.25, 0, 1.3, 1.3, "main", { rot = { -28, 0, 0 } }),
		E("tail", 0.6, 0.58, 0.55, 0, 1.64, 1.9, "white", fixed({ rot = { -28, 0, 0 } })),
	}
	both(function(s)
		-- tall pointed ears with dark tips
		table.insert(parts, K("head", 0.46, 0.46, 0.13, s * 0.3, 1.86, -0.72, "main", { rot = { 0, 0, 45 - s * 12 } }))
		table.insert(parts, K("head", 0.26, 0.26, 0.06, s * 0.3, 1.84, -0.8, "white", fixed({ rot = { 0, 0, 45 - s * 12 } })))
		table.insert(parts, E("head", 0.2, 0.2, 0.16, s * 0.37, 2.13, -0.72, "foxLeg", FIXED))
	end)
	eyes(parts, "head", 0.23, 1.52, -1.13, 0.11, 22)
	legs4(bones, parts, "body", 0.24, -0.5, 0.5, 0.58, 0.24, "main", "foxLeg", 0.12, "foxLeg")
	return {
		style = { gait = "walk", head = "look", tail = "sway", stride = 1.6, legSwing = 0.7, wander = 0 },
		bones = bones,
		parts = parts,
	}
end

AnimalShapes.FOX_COLOR = { 235, 115, 35 }

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
	local function scale(k: number): Vec
		return { math.floor(rgb[1] * k), math.floor(rgb[2] * k), math.floor(rgb[3] * k) }
	end
	if key == "dark" then
		return scale(0.72)
	elseif key == "soft" then
		return scale(0.93)
	elseif key == "light" then
		return {
			math.floor(rgb[1] + (255 - rgb[1]) * 0.35),
			math.floor(rgb[2] + (255 - rgb[2]) * 0.35),
			math.floor(rgb[3] + (255 - rgb[3]) * 0.35),
		}
	end
	return rgb
end

function AnimalShapes.isShade(key: any): boolean
	return key == "main" or key == "soft" or key == "dark" or key == "light"
end

-- Resolves a part's colour key to rgb for an animal of colour `rgb`.
function AnimalShapes.colorOf(key: any, rgb: Vec): Vec
	if type(key) == "table" then
		return key
	end
	if AnimalShapes.isShade(key) then
		return AnimalShapes.shade(rgb, key)
	end
	return AnimalShapes.palette[key] or rgb
end

return AnimalShapes
