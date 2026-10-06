-- Networking. One RemoteEvent for client actions, one for server pushes and
-- one RemoteFunction for requests that need an answer. Every action goes
-- through a per-player rate limit, and handlers must validate all arguments.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

local FOLDER_NAME = "KinfieldNet"
local IS_SERVER = RunService:IsServer()

local folder: Folder
local actionEvent: RemoteEvent
local pushEvent: RemoteEvent
local requestFunc: RemoteFunction

local function setup()
	if folder then
		return
	end
	if IS_SERVER then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		actionEvent = Instance.new("RemoteEvent")
		actionEvent.Name = "Action"
		actionEvent.Parent = folder
		pushEvent = Instance.new("RemoteEvent")
		pushEvent.Name = "Push"
		pushEvent.Parent = folder
		requestFunc = Instance.new("RemoteFunction")
		requestFunc.Name = "Request"
		requestFunc.Parent = folder
		folder.Parent = ReplicatedStorage
	else
		folder = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
		actionEvent = folder:WaitForChild("Action") :: RemoteEvent
		pushEvent = folder:WaitForChild("Push") :: RemoteEvent
		requestFunc = folder:WaitForChild("Request") :: RemoteFunction
	end
end

---------------------------------------------------------------- server side

local actionHandlers: { [string]: (Player, ...any) -> () } = {}
local requestHandlers: { [string]: (Player, ...any) -> any } = {}
local limits: { [string]: number } = {} -- actions per second allowed per action name
local buckets: { [Player]: { [string]: { tokens: number, last: number } } } = {}

local DEFAULT_RATE = 8

local function allow(player: Player, name: string): boolean
	local rate = limits[name] or DEFAULT_RATE
	local pb = buckets[player]
	if not pb then
		pb = {}
		buckets[player] = pb
	end
	local b = pb[name]
	local now = os.clock()
	if not b then
		b = { tokens = rate, last = now }
		pb[name] = b
	end
	b.tokens = math.min(rate * 2, b.tokens + (now - b.last) * rate)
	b.last = now
	if b.tokens < 1 then
		return false
	end
	b.tokens -= 1
	return true
end

function Net.onAction(name: string, handler: (Player, ...any) -> (), ratePerSecond: number?)
	actionHandlers[name] = handler
	if ratePerSecond then
		limits[name] = ratePerSecond
	end
end

function Net.onRequest(name: string, handler: (Player, ...any) -> any, ratePerSecond: number?)
	requestHandlers[name] = handler
	if ratePerSecond then
		limits["req:" .. name] = ratePerSecond
	end
end

function Net.push(player: Player, topic: string, data: any)
	if player.Parent then
		pushEvent:FireClient(player, topic, data)
	end
end

function Net.pushAll(topic: string, data: any)
	pushEvent:FireAllClients(topic, data)
end

-- Localised notification: the client turns `key` into text.
function Net.notify(player: Player, key: string, vars: { [string]: any }?, kind: string?)
	Net.push(player, "Notify", { key = key, vars = vars, kind = kind or "info" })
end

function Net.notifyAll(key: string, vars: { [string]: any }?, kind: string?)
	Net.pushAll("Notify", { key = key, vars = vars, kind = kind or "info" })
end

function Net.startServer()
	setup()
	actionEvent.OnServerEvent:Connect(function(player: Player, name: any, ...)
		if type(name) ~= "string" then
			return
		end
		local handler = actionHandlers[name]
		if not handler or not allow(player, name) then
			return
		end
		local ok, err = pcall(handler, player, ...)
		if not ok then
			warn(("[Net] action %s from %s failed: %s"):format(name, player.Name, tostring(err)))
		end
	end)
	requestFunc.OnServerInvoke = function(player: Player, name: any, ...)
		if type(name) ~= "string" then
			return nil
		end
		local handler = requestHandlers[name]
		if not handler or not allow(player, "req:" .. name) then
			return nil
		end
		local ok, result = pcall(handler, player, ...)
		if not ok then
			warn(("[Net] request %s from %s failed: %s"):format(name, player.Name, tostring(result)))
			return nil
		end
		return result
	end
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

---------------------------------------------------------------- client side

local pushHandlers: { [string]: { (any) -> () } } = {}

function Net.action(name: string, ...)
	setup()
	actionEvent:FireServer(name, ...)
end

function Net.request(name: string, ...): any
	setup()
	local ok, result = pcall(requestFunc.InvokeServer, requestFunc, name, ...)
	if ok then
		return result
	end
	warn("[Net] request failed", name, result)
	return nil
end

function Net.onPush(topic: string, handler: (any) -> ())
	local list = pushHandlers[topic]
	if not list then
		list = {}
		pushHandlers[topic] = list
	end
	table.insert(list, handler)
end

function Net.startClient()
	setup()
	pushEvent.OnClientEvent:Connect(function(topic: string, data: any)
		local list = pushHandlers[topic]
		if list then
			for _, h in list do
				task.spawn(h, data)
			end
		end
	end)
end

return Net
