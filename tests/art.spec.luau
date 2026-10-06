local Animals = require(Shared.Config.Animals)
local AnimalShapes = require(Shared.Art.AnimalShapes)

T.suite("art")

T.test("every animal has a shape", function()
	for _, id in Animals.order do
		T.truthy(AnimalShapes.has(id), "no shape for " .. id)
	end
	T.truthy(AnimalShapes.has("Fox"), "no fox shape")
end)

T.test("shapes are well formed", function()
	local species = table.clone(Animals.order)
	table.insert(species, "Fox")
	for _, id in species do
		local shape = AnimalShapes.get(id)
		local known = { root = true }
		for _, b in shape.bones do
			T.truthy(known[b.parent], id .. ": bone " .. b.name .. " has its parent after it")
			T.truthy(not known[b.name], id .. ": duplicate bone " .. b.name)
			known[b.name] = true
		end
		T.truthy(#shape.parts > 0, id .. " has no parts")
		for _, p in shape.parts do
			T.truthy(known[p.bone], id .. ": unknown bone " .. p.bone)
			for k = 1, 3 do
				T.truthy(p.size[k] > 0, id .. ": empty part size")
			end
			T.truthy(p.pos[2] - p.size[2] / 2 >= -0.01 or (p.opts and p.opts.rot), id .. ": part below ground")
			local rgb = AnimalShapes.colorOf(p.color, { 200, 100, 50 })
			T.truthy(type(rgb) == "table" and #rgb == 3, id .. ": unknown colour " .. tostring(p.color))
		end
		local w, h, d = AnimalShapes.bounds(id)
		T.truthy(w > 0.5 and h > 0.5 and d > 0.5, id .. ": tiny bounds")
		T.truthy(w < 8 and h < 8 and d < 8, id .. ": huge bounds")
	end
end)

T.test("shades stay in range", function()
	local light = AnimalShapes.shade({ 255, 0, 128 }, "light")
	local dark = AnimalShapes.shade({ 255, 0, 128 }, "dark")
	for k = 1, 3 do
		T.truthy(light[k] >= 0 and light[k] <= 255)
		T.truthy(dark[k] >= 0 and dark[k] <= 255)
	end
end)
