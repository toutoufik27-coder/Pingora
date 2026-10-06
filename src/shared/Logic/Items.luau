-- Inventory keys.
--   "Wheat"              plain crop
--   "Wheat#Golden+Wet"   crop with mutations (sorted, joined by "+")
--   "Seed:Wheat"         seed
--   "Flour", "Egg"...    any other item id

local Items = require(script.Parent.Parent.Config.Items)

local ItemLogic = {}

function ItemLogic.cropKey(cropId: string, mutations: { string }?): string
	if not mutations or #mutations == 0 then
		return cropId
	end
	local seen = {}
	local list = {}
	for _, m in mutations do
		if not seen[m] then
			seen[m] = true
			table.insert(list, m)
		end
	end
	table.sort(list)
	return cropId .. "#" .. table.concat(list, "+")
end

export type Parsed = { id: string, mutations: { string }, def: any }

function ItemLogic.parse(key: string): Parsed
	local base, muts = string.match(key, "^([^#]+)#(.+)$")
	local mutations = {}
	if base then
		for m in string.gmatch(muts :: string, "[^+]+") do
			table.insert(mutations, m)
		end
	else
		base = key
	end
	return { id = base :: string, mutations = mutations, def = Items.byId[base :: string] }
end

function ItemLogic.def(key: string)
	return ItemLogic.parse(key).def
end

function ItemLogic.exists(key: string): boolean
	local p = ItemLogic.parse(key)
	if not p.def then
		return false
	end
	if #p.mutations > 0 and p.def.kind ~= "crop" then
		return false
	end
	return true
end

function ItemLogic.isTradeable(key: string): boolean
	local p = ItemLogic.parse(key)
	if not p.def then
		return false
	end
	if p.def.kind == "special" then
		return false
	end
	return p.def.trade or #p.mutations > 0
end

function ItemLogic.isMarketable(key: string): boolean
	local p = ItemLogic.parse(key)
	return p.def ~= nil and p.def.market == true
end

function ItemLogic.kind(key: string): string?
	local d = ItemLogic.def(key)
	return d and d.kind
end

return ItemLogic
