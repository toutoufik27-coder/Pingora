-- Crop growth from timestamps. Nothing ticks per crop on the server: the
-- state is computed whenever someone looks at it, which also gives offline
-- growth for free.

local Crops = require(script.Parent.Parent.Config.Crops)
local Economy = require(script.Parent.Parent.Config.Economy)

local Growth = {}

Growth.STAGE_SEED = 0
Growth.STAGE_SPROUT = 1
Growth.STAGE_GROWING = 2
Growth.STAGE_RIPE = 3
Growth.STAGE_OVERRIPE = 4

export type Tile = {
	crop: string,
	start: number, -- when the current growth began
	ready: number, -- when it becomes ripe
	watered: boolean?,
	mutations: { string }?,
	harvests: number?,
	shared: boolean?,
}

function Growth.isNative(cropId: string, lands: { string? }): boolean
	local c = Crops.byId[cropId]
	if not c then
		return false
	end
	if c.land == "Any" then
		return true
	end
	for _, l in lands do
		if l == c.land then
			return true
		end
	end
	return false
end

-- Seconds for one growth cycle. `regrow` uses the crop's regrow time.
-- `growBuff` is a fraction (0.1 = 10% faster).
function Growth.cycleTime(cropId: string, lands: { string? }, regrow: boolean, growBuff: number?): number
	local c = Crops.byId[cropId]
	local base = if regrow and c.regrow then c.regrow else c.grow
	local t = base
	if c.land ~= "Any" and Growth.isNative(cropId, lands) then
		t *= Economy.NATIVE_GROW_MULT
	end
	t *= 1 - math.clamp(growBuff or 0, 0, 0.9)
	return math.max(5, t)
end

function Growth.plant(cropId: string, now: number, lands: { string? }, growBuff: number?): Tile
	local t = Growth.cycleTime(cropId, lands, false, growBuff)
	return { crop = cropId, start = now, ready = now + t, watered = false, mutations = {}, harvests = 0 }
end

-- Watering shortens the remaining time. Returns false if it cannot be watered.
function Growth.water(tile: Tile, now: number): boolean
	if tile.watered or now >= tile.ready then
		return false
	end
	local remaining = tile.ready - now
	tile.ready = now + remaining * Economy.WATER_GROW_MULT
	tile.watered = true
	return true
end

function Growth.freshWindow(tile: Tile): number
	local cycle = tile.ready - tile.start
	return math.max(Economy.FRESH_WINDOW_MIN, cycle * Economy.FRESH_WINDOW_MULT)
end

function Growth.stage(tile: Tile, now: number): number
	if now >= tile.ready then
		if now >= tile.ready + Growth.freshWindow(tile) then
			return Growth.STAGE_OVERRIPE
		end
		return Growth.STAGE_RIPE
	end
	local span = math.max(1, tile.ready - tile.start)
	local p = (now - tile.start) / span
	if p < 0.2 then
		return Growth.STAGE_SEED
	elseif p < 0.6 then
		return Growth.STAGE_SPROUT
	end
	return Growth.STAGE_GROWING
end

function Growth.progress(tile: Tile, now: number): number
	local span = math.max(1, tile.ready - tile.start)
	return math.clamp((now - tile.start) / span, 0, 1)
end

function Growth.isRipe(tile: Tile, now: number): boolean
	return now >= tile.ready
end

-- Units produced by one harvest.
function Growth.yield(cropId: string, lands: { string? }): number
	local c = Crops.byId[cropId]
	if Growth.isNative(cropId, lands) then
		return c.yield
	end
	return math.max(1, math.floor(c.yield * Economy.FOREIGN_YIELD + 0.5))
end

-- After a harvest: regrowing crops restart, others clear the tile.
-- Returns the tile to keep, or nil to clear it.
function Growth.afterHarvest(tile: Tile, now: number, lands: { string? }, growBuff: number?): Tile?
	local c = Crops.byId[tile.crop]
	if not c.regrow then
		return nil
	end
	local t = Growth.cycleTime(tile.crop, lands, true, growBuff)
	tile.start = now
	tile.ready = now + t
	tile.watered = false
	tile.mutations = {}
	tile.harvests = (tile.harvests or 0) + 1
	return tile
end

return Growth
