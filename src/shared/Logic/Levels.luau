local Economy = require(script.Parent.Parent.Config.Economy)

local Levels = {}

-- Adds xp. Below MAX_LEVEL it raises the level; at MAX_LEVEL it keeps
-- counting into Legacy levels. Returns level, xp, levels gained, legacy,
-- legacy levels gained.
function Levels.addXp(level: number, xp: number, amount: number, legacy: number?): (number, number, number, number, number)
	local gained, legacyGained = 0, 0
	legacy = legacy or 0
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
		while xp >= Economy.LEGACY_XP do
			xp -= Economy.LEGACY_XP
			legacy += 1
			legacyGained += 1
		end
	end
	return level, xp, gained, legacy :: number, legacyGained
end

function Levels.xpNeed(level: number): number
	if level >= Economy.MAX_LEVEL then
		return Economy.LEGACY_XP
	end
	return Economy.xpForLevel(level)
end

-- Permanent sell bonus from Legacy levels.
function Levels.legacyBonus(legacy: number): number
	local total = 0
	for i = 1, math.min(legacy, #Economy.LEGACY_BONUSES) do
		total += Economy.LEGACY_BONUSES[i]
	end
	return total
end

-- Title for a Legacy level (nil before the first one).
function Levels.legacyTitle(legacy: number)
	if legacy <= 0 then
		return nil
	end
	local titles = Economy.LEGACY_TITLES
	return titles[math.min(legacy, #titles)]
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
