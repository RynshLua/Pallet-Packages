local Queue = {}
Queue.__index = Queue

function Queue.new(limit: number)
	local instance = {
		_limit = limit or 10,
		_items = {},
	}
	setmetatable(instance, Queue)

	return instance
end

function Queue:Pop()
	if #self._items == 0 then
		return
	end
	local _toGive = table.remove(self._items, 1)

	return _toGive
end

function Queue:Enqueue(item)
	if #self._items == self._limit then
		warn("Queue limit reached")
		return
	end

	table.insert(self._items, item)
end

function Queue:Peek()
	return self._items[1]
end

return Queue
