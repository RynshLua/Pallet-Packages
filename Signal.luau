-- Types
type Connection = {
	Disconnect: (self: Connection) -> (),
}

type Signal<T...> = {
	new: () -> Signal<T...>,
	Connect: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Disconnect: (self: Signal<T...>) -> (),
}

-- Constructor
local Signal = {} :: Signal<any>

-- Private Methods
function Signal.new<T...>()
	local self = setmetatable({}, { __index = Signal })
	self._connections = {} :: { [(T...) -> ()]: true }
	return self :: Signal<T...>
end

function Signal:Connect(callback)
	self._connections[callback] = true

	local connection = { _signal = self, _callback = callback }
	function connection:Disconnect()
		self._signal._connections[self._callback] = nil
	end

	return connection
end

function Signal:Fire(...)
	for callback in pairs(self._connections) do
		task.spawn(callback, ...)
	end
end

function Signal:Disconnect()
	table.clear(self._connections)
end

return Signal
