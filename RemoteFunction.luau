-- Types
export type RemoteFunction = {
	Name: string,
	Event: ((...any) -> any)?,
	Fire: (self: RemoteFunction, Player, ...any) -> any,
	Destroy: (self: RemoteFunction) -> (),
	_Threads: {[Player]: {_task : thread}},
	_Server: RemoteEvent?,
	_Client: RemoteEvent?
}

-- Private Variables
timeout = 10

-- Module
local RemoteFunction, RemoteFunctions = {}, {}
RemoteFunction.__index = RemoteFunction

local function createThreadTable(self, player)
	self._Threads[player] = self._Threads[player] or {}
	return self._Threads[player]
end

if game:GetService("RunService"):IsServer() then
	function RemoteFunction:Invoke(player, ...)
		assert(typeof(player) == "Instance" and player:IsA("Player"), "Expected player to be a Player instance")
		local threads = createThreadTable(self, player)
		local taskHandle = task.delay(timeout, function()
			local thread = table.remove(threads)
			if thread then coroutine.resume(thread[2]) end
		end)
		table.insert(threads, {taskHandle, coroutine.running()})
		assert(self._Server, "_Server RemoteEvent is nil")
		self._Server:FireClient(player, ...)
		return coroutine.yield()
	end

	function RemoteFunction.new(name: string, event: ((...any) -> any)?)
		assert(typeof(name) == "string" and name ~= "", "Expected name to be a non-empty string")
		local self = setmetatable({
			Name = name,
			Event = event,
			_Threads = {},
			_Server = Instance.new("RemoteEvent"),
			_Client = Instance.new("RemoteEvent")
		}, RemoteFunction)

		self._Server.Name = name .. "Server"
		self._Server.Parent = script
		self._Client.Name = name .. "Client"
		self._Client.Parent = script

		self._Server.OnServerEvent:Connect(function(player, ...)
			assert(player, "Player argument missing in OnServerEvent")
			local result = self.Event and self.Event(player, ...) or nil
			if result then self._Client:FireClient(player, result) end
		end)

		self._Client.OnServerEvent:Connect(function(player, ...)
			assert(player, "Player argument missing in OnServerEvent (client)")
			local threads = self._Threads[player]
			if threads then
				local thread = table.remove(threads)
				if thread then
					task.cancel(thread[1])
					coroutine.resume(thread[2], ...)
				end
			end
		end)

		RemoteFunctions[name] = self
		return self
	end
else
	function RemoteFunction:Invoke(...)
		local taskHandle = task.delay(timeout, function()
			local thread = table.remove(self._Threads)
			if thread then coroutine.resume(thread[2]) end
		end)
		table.insert(self._Threads, {taskHandle, coroutine.running()})
		assert(self._Client, "_Client RemoteEvent is nil")
		self._Client:FireServer(...)
		return coroutine.yield()
	end

	function RemoteFunction.new(name: string, event: ((...any) -> any)?)
		assert(typeof(name) == "string" and name ~= "", "Expected name to be a non-empty string")
		local self = setmetatable({
			Name = name,
			Event = event,
			_Threads = {},
			_Server = script:WaitForChild(name .. "Server"),
			_Client = script:WaitForChild(name .. "Client")
		}, RemoteFunction)

		self._Server.OnClientEvent:Connect(function(...)
			if self.Event then
				local result = self.Event(...)
				if result then self._Client:FireServer(result) end
			end
		end)

		self._Client.OnClientEvent:Connect(function(...)
			local thread = table.remove(self._Threads)
			if thread then
				task.cancel(thread[1])
				coroutine.resume(thread[2], ...)
			end
		end)

		RemoteFunctions[name] = self
		return self
	end
end

function RemoteFunction:Destroy()
	assert(self.Name, "RemoteFunction has no name and cannot be destroyed")
	RemoteFunctions[self.Name] = nil

	if self._Server then self._Server:Destroy() end
	if self._Client then self._Client:Destroy() end

	for _, threads in pairs(self._Threads) do
		for _, thread in ipairs(threads) do
			task.cancel(thread[1])
			task.defer(thread[2])
		end
	end
end

return table.freeze(RemoteFunction)
