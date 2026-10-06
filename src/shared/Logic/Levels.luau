local Economy = require(script.Parent.Parent.Config.Economy)

local Levels = {}

-- Adds xp; returns new level, new xp-in-level, and levels gained.
function Levels.addXp(level: number, xp: number, amount: number): (number, number, number)
	local gained = 0
	xp += math.max(0, amount)
	while level < Economy.MAX_LEVEL do
		local need = Economy.xpForLevel(level)
		if xp < need then
			break
		end
		xp -= need
		level += 1
		gained += 1
	end
	if level >= Economy.MAX_LEVEL then
		xp = 0
	end
	return level, xp, gained
end

function Levels.rebirthBonus(rebirths: number): number
	local total = 0
	for i = 1, math.min(rebirths, #Economy.REBIRTH_BONUSES) do
		total += Economy.REBIRTH_BONUSES[i]
	end
	return total
end

function Levels.canRebirth(level: number, coins: number, rebirths: number): boolean
	return level >= Economy.REBIRTH_LEVEL and coins >= Economy.REBIRTH_COINS and rebirths < Economy.REBIRTH_MAX
end

-- Next plot size step, or nil when maxed.
function Levels.nextPlotStep(size: number)
	for _, step in Economy.PLOT_SIZES do
		if step.size > size then
			return step
		end
	end
	return nil
end

return Levels
