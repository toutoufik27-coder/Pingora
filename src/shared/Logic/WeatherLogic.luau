-- The global weather forecast, computed from the clock.

local Weather = require(script.Parent.Parent.Config.Weather)
local Hash = require(script.Parent.Parent.Util.Hash)

local WeatherLogic = {}

function WeatherLogic.slotOf(now: number): number
	return math.floor(now / Weather.SLOT_SECONDS)
end

function WeatherLogic.weatherForSlot(slot: number): string
	local total = 0
	for _, id in Weather.order do
		total += Weather.types[id].weight
	end
	local roll = Hash.unit(slot, 7919) * total
	for _, id in Weather.order do
		roll -= Weather.types[id].weight
		if roll < 0 then
			return id
		end
	end
	return "Clear"
end

export type Info = {
	id: string,
	slot: number,
	active: boolean,
	startsAt: number,
	endsAt: number, -- when the active part ends
	nextSlotAt: number,
}

function WeatherLogic.at(now: number, override: { id: string, untilTime: number }?): Info
	local slot = WeatherLogic.slotOf(now)
	local startsAt = slot * Weather.SLOT_SECONDS
	if override and now < override.untilTime then
		return {
			id = override.id,
			slot = slot,
			active = true,
			startsAt = now,
			endsAt = override.untilTime,
			nextSlotAt = startsAt + Weather.SLOT_SECONDS,
		}
	end
	local id = WeatherLogic.weatherForSlot(slot)
	local endsAt = startsAt + Weather.ACTIVE_SECONDS
	return {
		id = id,
		slot = slot,
		active = id ~= "Clear" and now < endsAt,
		startsAt = startsAt,
		endsAt = endsAt,
		nextSlotAt = startsAt + Weather.SLOT_SECONDS,
	}
end

-- The next `count` slots after the current one: { {id, startsAt}, ... }
function WeatherLogic.forecast(now: number, count: number): { { id: string, startsAt: number } }
	local slot = WeatherLogic.slotOf(now)
	local out = {}
	for i = 1, count do
		local s = slot + i
		table.insert(out, { id = WeatherLogic.weatherForSlot(s), startsAt = s * Weather.SLOT_SECONDS })
	end
	return out
end

return WeatherLogic
