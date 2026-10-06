-- Kinfield server entry point. Builds the world, then initialises and starts
-- every service. DataService starts last so that every service is already
-- listening for profile loads.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local WorldBuilder = require(script.World.WorldBuilder)

Net.startServer()
WorldBuilder.build()

local ORDER = {
	"DataService",
	"ProgressService",
	"MonetizationService",
	"PlotService",
	"FarmService",
	"WeatherService",
	"ShopService",
	"AnimalService",
	"WorkshopService",
	"TradeService",
	"MarketService",
	"ProjectService",
	"ExplorationService",
	"EventService",
	"QuestService",
}

local services = {}
for _, name in ORDER do
	services[name] = require(script.Services[name])
end
for _, name in ORDER do
	local s = services[name]
	if s.init then
		s.init(services)
	end
end
for _, name in ORDER do
	local s = services[name]
	if name ~= "DataService" and s.start then
		s.start()
	end
end
services.DataService.start()

print("[Kinfield] server ready")
