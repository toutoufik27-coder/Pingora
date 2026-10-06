-- Plot grid. Tiles use fixed coordinates 1..MAX on both axes, and the
-- unlocked area is a centred square, so expanding never renames tiles.

local Economy = require(script.Parent.Parent.Config.Economy)

local Plot = {}

Plot.MAX = Economy.MAX_PLOT_SIZE

function Plot.key(x: number, y: number): string
	return x .. "_" .. y
end

function Plot.parseKey(key: string): (number?, number?)
	local x, y = string.match(key, "^(%d+)_(%d+)$")
	if not x then
		return nil, nil
	end
	return tonumber(x), tonumber(y)
end

function Plot.bounds(size: number): (number, number)
	local lo = math.floor((Plot.MAX - size) / 2) + 1
	return lo, lo + size - 1
end

function Plot.isUnlocked(key: string, size: number): boolean
	local x, y = Plot.parseKey(key)
	if not x then
		return false
	end
	local lo, hi = Plot.bounds(size)
	return x >= lo and x <= hi and y >= lo and y <= hi
end

function Plot.unlockedKeys(size: number): { string }
	local lo, hi = Plot.bounds(size)
	local out = {}
	for x = lo, hi do
		for y = lo, hi do
			table.insert(out, Plot.key(x, y))
		end
	end
	return out
end

-- Keys in a square of `radius` around a tile (radius 0 = the tile itself).
function Plot.area(key: string, radius: number, size: number): { string }
	local cx, cy = Plot.parseKey(key)
	local out = {}
	if not cx then
		return out
	end
	for x = cx - radius, cx + radius do
		for y = cy - radius, cy + radius do
			local k = Plot.key(x, y)
			if Plot.isUnlocked(k, size) then
				table.insert(out, k)
			end
		end
	end
	return out
end

return Plot
