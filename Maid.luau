local Maid = {}
Maid.ClassName = "Maid"

function Maid.new()
	return setmetatable({
		_tasks = {},
	}, Maid)
end

function Maid.isMaid(value)
	return type(value) == "table" and value.ClassName == "Maid"
end

function Maid:__index(index)
	if Maid[index] then
		return Maid[index]
	else
		return self._tasks[index]
	end
end

function Maid:__newindex(index, newTask)
	if Maid[index] ~= nil then
		rawset(self, index, newTask)
	else
		local oldTask = self._tasks[index]
		if oldTask then
			self:_cleanupTask(oldTask)
		end
		if newTask then
			self._tasks[index] = newTask
		else
			self._tasks[index] = nil
		end
	end
end

function Maid:GiveTask(task)
	if task then
		table.insert(self._tasks, task)
	end
end

function Maid:_cleanupTask(task)
	if typeof(task) == "RBXScriptConnection" then
		task:Disconnect()
	elseif typeof(task) == "Instance" then
		task:Destroy()
	elseif type(task) == "function" then
		task()
	end
end

function Maid:DoCleaning()
	for _, task in ipairs(self._tasks) do
		self:_cleanupTask(task)
	end
	table.clear(self._tasks)
end

function Maid:Destroy()
	self:DoCleaning()
end

return Maid
