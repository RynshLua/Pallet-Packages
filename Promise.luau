local Promise = {}
Promise.ClassName = "Promise"
Promise.__index = Promise

local PACKED = table.freeze({ i = 0 })
local _emptyRejectedPromise = nil
local _emptyFulfilledPromise = nil

local HttpService = game:GetService("HttpService")

local warn = function(...)
	warn("[Promise] -", ...)
end

function Promise.isPromise(value)
	return type(value) == "table" and value.ClassName == "Promise"
end

function Promise.new(func)
	local self = setmetatable({
		_pendingList = {},
		_uncaughtException = true,
	}, Promise)

	if type(func) == "function" then
		func(self:_getResolveReject())
	end

	return self
end

function Promise.spawn(func)
	local self = Promise.new()

	task.spawn(func, self:_getResolveReject())

	return self
end

function Promise.delay(secs, func)
	assert(typeof(secs) == "number", "Seconds isn't a number.")
	assert(typeof(func) == "function", "Function isn't a function")

	local self = Promise.new()

	task.delay(secs, func, self:_getResolveReject())

	return self
end

function Promise.defer(func)
	assert(typeof(func) == "function", "Function isn't a function")

	local self = Promise.new()

	task.defer(func, self:_getResolveReject())

	return self
end

function Promise.resolved(...)
	local i = select("#", ...)

	if i == 0 then
		return _emptyFulfilledPromise
	elseif i == 1 and Promise.isPromise(...) then
		local promise = (...)

		if not promise._pendingList then
			return promise
		end
	end

	local promise = Promise.new()
	promise:Resolve(...)
	return promise
end

function Promise.rejected(...)
	local i = select("#", ...)

	if i == 0 then
		return _emptyRejectedPromise
	end

	local promise = Promise.new()

	promise:_reject(table.pack(...))

	return promise
end

function Promise:QueryPending()
	return self._pendingList ~= nil
end

function Promise:QueryFulfilled()
	return self._fulfilled ~= nil
end

function Promise:QueryRejected()
	return self._rejected ~= nil
end

function Promise:Wait()
	if self._fulfilled then
		return table.unpack(self._fulfilled, 1, self._fulfilled.n)
	elseif self._rejected then
		return error(tostring(self._rejected[1], 2))
	else
		local _waitCoroutine = coroutine.running()

		self:Then(function()
			task.spawn(_waitCoroutine)
		end, function()
			task.spawn(_waitCoroutine)
		end)

		coroutine.yield()

		if self._rejected then
			return error(tostring(self._rejected[1]), 2)
		else
			return table.unpack(self._fulfilled, 1, self._fulfilled.n)
		end
	end
end

function Promise:Yield()
	if self._fulfilled then
		return table.unpack(self._fulfilled, 1, self._fulfilled.n)
	elseif self._rejected then
		return error(tostring(self._rejected[1], 2))
	else
		local _waitCoroutine = coroutine.running()

		self:Then(function()
			task.spawn(_waitCoroutine)
		end, function()
			task.spawn(_waitCoroutine)
		end)

		coroutine.yield()

		if self._rejected then
			return false, table.unpack(self._rejected, 1, self._rejected.n)
		else
			return true, table.unpack(self._fulfilled, 1, self._fulfilled.n)
		end
	end
end

function Promise:Resolve(...)
	if not self._pendingList then
		return
	end

	local len = select("#", ...)

	if len == 0 then
		self:_fulfill(PACKED)
	elseif self == (...) then
		self:Reject("Promise resolved to self?")
	elseif Promise.isPromise(...) then
		local promise = (...)
		if promise._pendingList then
			Promise._uncaughtException = false
			promise._pendingList[#promise._pendingList + 1] = {
				function(...)
					self:Resolve(...)
				end,
				function(...)
					if self._pendingList then
						self:_reject(table.pack(...))
					end
				end,
				nil,
			}
		elseif promise._rejected then
			promise._uncaughtException = false
			self:_reject(promise._rejected)
		elseif promise._fulfilled then
			self:_fulfill(promise._fulfilled)
		else
			error("Resolve - Promise is in a broken state!")
		end
	elseif type(...) == "function" then
		local func = ...
		func(self:_getResolveReject())
	else
		self:_fulfill(table.pack(...))
	end
end

function Promise:_fulfill(value)
	if not self._pendingList then
		return
	end

	self._fulfilled = value

	local list = self._pendingList
	self._pendingList = nil

	for _, data in pairs(list) do
		self:_executeThen(unpack(data))
	end
end

function Promise:Reject(...)
	self:_reject(table.pack(...))
end

function Promise:_reject(value)
	if not self._pendingList then
		return
	end

	self._rejected = value

	local list = self._pendingList

	self._pendingList = nil

	for _, data in pairs(list) do
		self:_executeThen(unpack(data))
	end

	if self._uncaughtException and type(self._rejected) == "table" and self._rejected.n and self._rejected.n > 0 then
		task.defer(function()
			if self._uncaughtException then
				self._uncaughtException = false
				local err = tostring(self._rejected[1])
				warn(string.format("Uncaught exception in promise: %q", err))
			end
		end)
	end
end

function Promise:__tostring(data)
	if type(data) == "table" then
		local err
		local success = pcall(function()
			err = HttpService:JSONEncode(data)
		end)

		if not success then
			err = tostring(data)
		end

		return err
	else
		return tostring(data)
	end
end

function Promise:Then(fulfilled, rejected)
	if type(rejected) == "function" then
		self._uncaughtException = false
	end

	if self._pendingList then
		local promise = Promise.new()
		self._pendingList[#self._pendingList + 1] = { fulfilled, rejected, promise }
		return promise
	else
		return self:_executeThen(fulfilled, rejected, nil)
	end
end

function Promise:Finally(func)
	return self:Then(func, func)
end

function Promise:Catch(rejected)
	return self:Then(nil, rejected)
end

function Promise:Destroy()
	self:_reject(PACKED)
end

function Promise:QueryResults()
	if self._rejected then
		return false, table.unpack(self._rejected, 1, self._rejected.n)
	elseif self._fulfilled then
		return true, table.unpack(self._fulfilled, 1, self._fulfilled.n)
	else
		error("QueryResults - Promise is still pending.")
	end
end

function Promise:_getResolveReject()
	return function(...)
		self:Resolve(...)
	end, function(...)
		self:_reject(table.pack(...))
	end
end

function Promise:_executeThen(fulfilled, rejected, promise)
	if self._fulfilled then
		if type(fulfilled) == "function" then
			if promise then
				promise:Resolve(fulfilled(table.unpack(self._fulfilled, 1, self._fulfilled.n)))
				return promise
			else
				local result = table.pack(fulfilled(table.unpack(self._fulfilled, 1, self._fulfilled.n)))
				if result.n == 0 then
					return _emptyFulfilledPromise
				elseif result.n == 1 and Promise.isPromise(result[1]) then
					return result[1]
				else
					local promise2 = Promise.new()
					promise2:Resolve(table.unpack(result, 1, result.n))
					return promise2
				end
			end
		else
			if promise then
				promise:_fulfill(self._fulfilled)
				return promise
			else
				return self
			end
		end
	elseif self._rejected then
		if type(rejected) == "function" then
			if promise then
				promise:Resolve(rejected(table.unpack(self._rejected, 1, self._rejected.n)))
				return promise
			else
				local result = table.pack(rejected(table.unpack(self._rejected, 1, self._rejected.n)))
				if result.n == 0 then
					return _emptyFulfilledPromise
				elseif result.n == 1 and Promise.isPromise(result[1]) then
					return result[1]
				else
					local promise2 = Promise.new()
					promise2:Resolve(table.unpack(result, 1, result.n))
					return promise2
				end
			end
		else
			if promise then
				promise:_reject(self._rejected)
				return promise
			else
				return self
			end
		end
	end
end

_emptyFulfilledPromise = Promise.new()
_emptyFulfilledPromise:_fulfill(PACKED)

_emptyRejectedPromise = Promise.new()
_emptyRejectedPromise:_reject(PACKED)

return Promise
