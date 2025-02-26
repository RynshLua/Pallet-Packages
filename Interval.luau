local Interval = {}

function Interval.every(seconds)
	local event = Instance.new("BindableEvent")
	local running = true

	coroutine.wrap(function()
		while running do
			event:Fire()
			task.wait(seconds)
		end
	end)()

	return {
		Connect = function(_, callback)
			event.Event:Connect(callback)
		end,
		Stop = function()
			running = false
		end,
	}
end

function Interval.after(seconds)
	local event = Instance.new("BindableEvent")

	coroutine.wrap(function()
		task.wait(seconds)
		event:Fire()
	end)()

	return {
		Connect = function(_, callback)
			event.Event:Connect(callback)
		end,
	}
end

function Interval.wait(seconds)
	local event = Instance.new("BindableEvent")

	coroutine.wrap(function()
		task.wait(seconds)
		event:Fire()
	end)()

	event.Event:Wait()
end

return Interval
