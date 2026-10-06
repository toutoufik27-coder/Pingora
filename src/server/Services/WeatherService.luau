-- Global weather. Every server computes the same forecast from the clock.
-- During weather, growing crops on farms in this server may mutate. Wind
-- carries pollen between neighbours' farms and can create hybrid seeds.

local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Net = require(Shared.Net)
local Weather = require(Shared.Config.Weather)
local Lands = require(Shared.Config.Lands)
local Crops = require(Shared.Config.Crops)
local Growth = require(Shared.Logic.Growth)
local Mutations = require(Shared.Logic.Mutations)
local WeatherLogic = require(Shared.Logic.WeatherLogic)

local DataService, Progress, PlotService

local WeatherService = {}

local override: { id: string, untilTime: number }? = nil
local lastSignature = ""
local rng = Random.new()
local hybridGiven: { [Player]: number } = {} -- slot in which the player last got a hybrid

function WeatherService.current()
	return WeatherLogic.at(os.time(), override)
end

-- Starts a special weather (e.g. Meteor) for `seconds`.
function WeatherService.setOverride(id: string, seconds: number)
	override = { id = id, untilTime = os.time() + seconds }
	WeatherService.broadcast(true)
end

local function payload()
	local now = os.time()
	local info = WeatherLogic.at(now, override)
	return {
		id = info.id,
		active = info.active,
		endsAt = info.endsAt,
		nextSlotAt = info.nextSlotAt,
		forecast = WeatherLogic.forecast(now, 3),
		serverTime = now,
	}
end

function WeatherService.broadcast(force: boolean?)
	local data = payload()
	local sig = data.id .. tostring(data.active) .. data.nextSlotAt
	if force or sig ~= lastSignature then
		lastSignature = sig
		Net.pushAll("Weather", data)
	end
end

local function mutationTick(info)
	local w = Weather.types[info.id]
	if not w or not w.mutation then
		return
	end
	local now = os.time()
	for _, entry in PlotService.occupied() do
		local p = entry.profile
		local land = p.Land and Lands[p.Land]
		local chance = Mutations.chanceFor(info.id, land and land.weatherBonus, Progress.luck(p))
		local added = 0
		for key, tile in p.Tiles do
			if Growth.stage(tile, now) >= Growth.STAGE_SPROUT then
				tile.mutations = tile.mutations or {}
				-- almanac mastery: 5+ discoveries of a crop give it +25% chance
				local entry = p.Almanac.crops[tile.crop]
				local found = 0
				if entry then
					for _ in entry do
						found += 1
					end
				end
				local tileChance = if found >= 5 then chance * 1.25 else chance
				if Mutations.weatherRoll(tile.mutations, w.mutation, tileChance, function()
					return rng:NextNumber()
				end) then
					added += 1
					PlotService.refreshTile(entry.index, key)
				end
			end
		end
		if added > 0 then
			Net.notify(entry.player, "note.mutated", { n = added, mutation = w.mutation }, "discover")
		end
	end
end

local function windTick(info)
	local occupied = PlotService.occupied()
	-- who grows what in this valley right now
	local growers: { [string]: { Player } } = {}
	for _, entry in occupied do
		local seen = {}
		for _, tile in entry.profile.Tiles do
			if not seen[tile.crop] then
				seen[tile.crop] = true
				growers[tile.crop] = growers[tile.crop] or {}
				table.insert(growers[tile.crop], entry.player)
			end
		end
	end
	local function hasOther(list: { Player }?, me: Player): boolean
		if not list then
			return false
		end
		for _, pl in list do
			if pl ~= me then
				return true
			end
		end
		return false
	end
	for _, h in Crops.hybrids do
		for _, pair in { { h.a, h.b }, { h.b, h.a } } do
			for _, pl in growers[pair[1]] or {} do
				if hybridGiven[pl] ~= info.slot and hasOther(growers[pair[2]], pl) and rng:NextNumber() < Weather.HYBRID_CHANCE then
					hybridGiven[pl] = info.slot
					Progress.give(pl, "Seed:" .. h.result, 1)
					Net.notify(pl, "note.hybrid", { crop = h.result }, "celebrate")
				end
			end
		end
	end
end

function WeatherService.init(services)
	DataService = services.DataService
	Progress = services.ProgressService
	PlotService = services.PlotService
end

function WeatherService.start()
	Players.PlayerAdded:Connect(function(player)
		task.wait(2)
		Net.push(player, "Weather", payload())
	end)
	Players.PlayerRemoving:Connect(function(player)
		hybridGiven[player] = nil
	end)
	task.spawn(function()
		local lastTick = 0
		while true do
			task.wait(1)
			if override and os.time() >= override.untilTime then
				override = nil
			end
			WeatherService.broadcast(false)
			local info = WeatherLogic.at(os.time(), override)
			if info.active and os.clock() - lastTick >= Weather.TICK_SECONDS then
				lastTick = os.clock()
				local w = Weather.types[info.id]
				if w and w.special == "crosspollinate" then
					windTick(info)
				else
					mutationTick(info)
				end
			end
		end
	end)
end

return WeatherService
