local src = __readfile("src/shared/Art/AnimalShapes.luau")
local A = __compile("local script, require = ...; " .. src, "AnimalShapes")(nil, nil)
local names = { "Chicken", "Duck", "Dog", "Cat", "Cow", "Goat", "Sheep", "Rabbit", "Horse", "Bee", "Fox" }
local colors = { Chicken = {245,245,240}, Duck = {250,250,250}, Dog = {220,170,90}, Cat = {230,140,60}, Cow = {240,240,240}, Goat = {240,235,225}, Sheep = {245,245,240}, Rabbit = {150,110,75}, Horse = {120,70,40}, Bee = {240,180,40}, Fox = A.FOX_COLOR }
local spotted = { Cow = true }
for _, n in names do
	for _, p in A.get(n).parts do
		local o = p.opts or {}
		if not o.spots or spotted[n] then
			local rgb = A.colorOf(p.color, colors[n])
			local rot = o.rot or {0,0,0}
			print(string.format("%s %s %s %g %g %g %g %g %g %d %d %d %g %g %g %g", n, p.bone, o.shape or "Block", p.size[1], p.size[2], p.size[3], p.pos[1], p.pos[2], p.pos[3], rgb[1], rgb[2], rgb[3], rot[1], rot[2], rot[3], o.alpha or 0))
		end
	end
end
