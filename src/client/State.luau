-- Client-side copy of what the server pushes, with change signals.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)

local State = {
	profile = nil :: any,
	weather = nil :: any,
	project = nil :: any,
	trade = nil :: any,
	trip = nil :: any,
	clockOffset = 0, -- server time - local time
}

State.ProfileChanged = Signal.new()
State.WeatherChanged = Signal.new()
State.ProjectChanged = Signal.new()
State.TradeChanged = Signal.new()
State.TripChanged = Signal.new()

function State.now(): number
	return os.time() + State.clockOffset
end

function State.start()
	Net.onPush("Profile", function(data)
		State.profile = data
		if data.ServerTime then
			State.clockOffset = data.ServerTime - os.time()
		end
		State.ProfileChanged:Fire(data)
	end)
	Net.onPush("Weather", function(data)
		State.weather = data
		State.WeatherChanged:Fire(data)
	end)
	Net.onPush("Project", function(data)
		State.project = data
		State.ProjectChanged:Fire(data)
	end)
	Net.onPush("Trade", function(data)
		if data.closed then
			State.trade = nil
		else
			State.trade = data
		end
		State.TradeChanged:Fire(data)
	end)
	Net.onPush("Trip", function(data)
		State.trip = if data.ended then nil else data
		State.TripChanged:Fire(State.trip)
	end)
end

return State
