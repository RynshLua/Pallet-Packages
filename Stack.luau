local Stack = {}
Stack.__index = Stack

-- Constructor
function Stack.new()
	local self = {
		_items = {},
	}

	setmetatable(self, Stack)
	return self
end

-- Private Methods
function Stack:Peek()
	return self._items[#self._items]
end

function Stack:Push(item)
	table.insert(self._items, item)
end

function Stack:Pop()
	return table.remove(self._items, #self._items)
end

return Stack
