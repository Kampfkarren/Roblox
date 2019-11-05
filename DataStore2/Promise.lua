--[[
	An implementation of Promises similar to Promise/A+.
]]

local ERROR_YIELD_NEW = "Yielding inside Promise.new is not allowed! Use Promise.async or create a new thread in the Promise executor!"
local ERROR_YIELD_THEN = "Yielding inside andThen/catch is not allowed! Instead, return a new Promise from andThen/catch."
local ERROR_NON_PROMISE_IN_LIST = "Non-promise value passed into %s at index %s"
local ERROR_NON_LIST = "Please pass a list of promises to %s"
local ERROR_NON_FUNCTION = "Please pass a handler function to %s!"

local RunService = game:GetService("RunService")

--[[
	Packs a number of arguments into a table and returns its length.

	Used to cajole varargs without dropping sparse values.
]]
local function pack(...)
	local len = select("#", ...)

	return len, { ... }
end

--[[
	Returns first value (success), and packs all following values.
]]
local function packResult(...)
	local result = (...)

	return result, pack(select(2, ...))
end

--[[
	Calls a non-yielding function in a new coroutine.

	Handles errors if they happen.
]]
local function ppcall(yieldError, callback, ...)
	-- Wrapped because C functions can't be passed to coroutine.create!
	local co = coroutine.create(function(...)
		return callback(...)
	end)

	local ok, len, result = packResult(coroutine.resume(co, ...))

	if ok and coroutine.status(co) ~= "dead" then
		error(yieldError, 2)
	end

	return ok, len, result
end

--[[
	Creates a function that invokes a callback with correct error handling and
	resolution mechanisms.
]]
local function createAdvancer(traceback, callback, resolve, reject)
	return function(...)
		local ok, resultLength, result = ppcall(ERROR_YIELD_THEN, callback, ...)

		if ok then
			resolve(unpack(result, 1, resultLength))
		else
			reject(result[1], traceback)
		end
	end
end

local function isEmpty(t)
	return next(t) == nil
end

local Promise = {}
Promise.prototype = {}
Promise.__index = Promise.prototype

Promise.Status = setmetatable({
	Started = "Started",
	Resolved = "Resolved",
	Rejected = "Rejected",
	Cancelled = "Cancelled",
}, {
	__index = function(_, k)
		error(("%s is not in Promise.Status!"):format(k), 2)
	end
})

--[[
	Constructs a new Promise with the given initializing callback.

	This is generally only called when directly wrapping a non-promise API into
	a promise-based version.

	The callback will receive 'resolve' and 'reject' methods, used to start
	invoking the promise chain.

	Second parameter, parent, is used internally for tracking the "parent" in a
	promise chain. External code shouldn't need to worry about this.
]]
function Promise.new(callback, parent)
	if parent ~= nil and not Promise.is(parent) then
		error("Argument #2 to Promise.new must be a promise or nil", 2)
	end

	local self = {
		-- Used to locate where a promise was created
		_source = debug.traceback(),

		_status = Promise.Status.Started,

		-- Will be set to the Lua error string if it occurs while executing.
		_error = nil,

		-- A table containing a list of all results, whether success or failure.
		-- Only valid if _status is set to something besides Started
		_values = nil,

		-- Lua doesn't like sparse arrays very much, so we explicitly store the
		-- length of _values to handle middle nils.
		_valuesLength = -1,

		-- Tracks if this Promise has no error observers..
		_unhandledRejection = true,

		-- Queues representing functions we should invoke when we update!
		_queuedResolve = {},
		_queuedReject = {},
		_queuedFinally = {},

		-- The function to run when/if this promise is cancelled.
		_cancellationHook = nil,

		-- The "parent" of this promise in a promise chain. Required for
		-- cancellation propagation.
		_parent = parent,

		_consumers = setmetatable({}, {
			__mode = "k";
		}),
	}

	if parent and parent._status == Promise.Status.Started then
		parent._consumers[self] = true
	end

	setmetatable(self, Promise)

	local function resolve(...)
		self:_resolve(...)
	end

	local function reject(...)
		self:_reject(...)
	end

	local function onCancel(cancellationHook)
		if cancellationHook then
			if self._status == Promise.Status.Cancelled then
				cancellationHook()
			else
				self._cancellationHook = cancellationHook
			end
		end

		return self._status == Promise.Status.Cancelled
	end

	local ok, _, result = ppcall(
		ERROR_YIELD_NEW,
		callback,
		resolve,
		reject,
		onCancel
	)

	if not ok then
		self._error = result[1] or "error"
		reject((result[1] or "error") .. "\n" .. self._source)
	end

	return self
end

function Promise._newWithSelf(executor, ...)
	local args
	local promise = Promise.new(function(...)
		args = {...}
	end, ...)

	executor(promise, unpack(args))

	return promise
end

function Promise._new(traceback, executor, ...)
	return Promise._newWithSelf(function(self, resolve, reject)
		self._source = traceback

		executor(resolve, function(err, traceback)
			err = err or "error"
			traceback = traceback or ""
			self._error = err
			reject(err .. "\n" .. traceback)
		end)
	end, ...)
end

--[[
	Promise.new, except pcall on a new thread is automatic.
]]
function Promise.async(callback)
	local traceback = debug.traceback()
	local promise
	promise = Promise.new(function(resolve, reject, onCancel)
		local connection
		connection = RunService.Heartbeat:Connect(function()
			connection:Disconnect()
			local ok, err = pcall(callback, resolve, reject, onCancel)

			if not ok then
				promise._error = err or "error"
				reject(err .. "\n" .. traceback)
			end
		end)
	end)

	return promise
end

--[[
	Create a promise that represents the immediately resolved value.
]]
function Promise.resolve(...)
	local length, values = pack(...)
	return Promise.new(function(resolve)
		resolve(unpack(values, 1, length))
	end)
end

--[[
	Create a promise that represents the immediately rejected value.
]]
function Promise.reject(...)
	local length, values = pack(...)
	return Promise.new(function(_, reject)
		reject(unpack(values, 1, length))
	end)
end

--[[
	Begins a Promise chain, turning synchronous errors into rejections.
]]
function Promise.try(...)
	return Promise.resolve():andThenCall(...)
end

--[[
	Returns a new promise that:
		* is resolved when all input promises resolve
		* is rejected if ANY input promises reject
]]
function Promise._all(traceback, promises, amount)
	if type(promises) ~= "table" then
		error(ERROR_NON_LIST:format("Promise.all"), 3)
	end

	-- We need to check that each value is a promise here so that we can produce
	-- a proper error rather than a rejected promise with our error.
	for i, promise in pairs(promises) do
		if not Promise.is(promise) then
			error((ERROR_NON_PROMISE_IN_LIST):format("Promise.all", tostring(i)), 3)
		end
	end

	-- If there are no values then return an already resolved promise.
	if #promises == 0 or amount == 0 then
		return Promise.resolve({})
	end

	return Promise._newWithSelf(function(self, resolve, reject, onCancel)
		self._source = traceback

		-- An array to contain our resolved values from the given promises.
		local resolvedValues = {}
		local newPromises = {}

		-- Keep a count of resolved promises because just checking the resolved
		-- values length wouldn't account for promises that resolve with nil.
		local resolvedCount = 0
		local rejectedCount = 0
		local done = false

		local function cancel()
			for _, promise in ipairs(newPromises) do
				promise:cancel()
			end
		end

		-- Called when a single value is resolved and resolves if all are done.
		local function resolveOne(i, ...)
			if done then
				return
			end

			resolvedCount = resolvedCount + 1

			if amount == nil then
				resolvedValues[i] = ...
			else
				resolvedValues[resolvedCount] = ...
			end

			if resolvedCount >= (amount or #promises) then
				done = true
				resolve(resolvedValues)
				cancel()
			end
		end

		onCancel(cancel)

		-- We can assume the values inside `promises` are all promises since we
		-- checked above.
		for i = 1, #promises do
			table.insert(
				newPromises,
				promises[i]:andThen(
					function(...)
						resolveOne(i, ...)
					end,
					function(...)
						rejectedCount = rejectedCount + 1

						if amount == nil or #promises - rejectedCount < amount then
							cancel()
							done = true

							reject(...)
						end
					end
				)
			)
		end

		if done then
			cancel()
		end
	end)
end

function Promise.all(promises)
	return Promise._all(debug.traceback(), promises)
end

function Promise.some(promises, amount)
	assert(type(amount) == "number", "Bad argument #2 to Promise.some: must be a number")

	return Promise._all(debug.traceback(), promises, amount)
end

function Promise.any(promises)
	return Promise._all(debug.traceback(), promises, 1):andThen(function(values)
		return values[1]
	end)
end

function Promise.allSettled(promises)
	if type(promises) ~= "table" then
		error(ERROR_NON_LIST:format("Promise.allSettled"), 2)
	end

	-- We need to check that each value is a promise here so that we can produce
	-- a proper error rather than a rejected promise with our error.
	for i, promise in pairs(promises) do
		if not Promise.is(promise) then
			error((ERROR_NON_PROMISE_IN_LIST):format("Promise.allSettled", tostring(i)), 2)
		end
	end

	-- If there are no values then return an already resolved promise.
	if #promises == 0 then
		return Promise.resolve({})
	end

	return Promise.new(function(resolve, _, onCancel)
		-- An array to contain our resolved values from the given promises.
		local fates = {}
		local newPromises = {}

		-- Keep a count of resolved promises because just checking the resolved
		-- values length wouldn't account for promises that resolve with nil.
		local finishedCount = 0

		-- Called when a single value is resolved and resolves if all are done.
		local function resolveOne(i, ...)
			finishedCount = finishedCount + 1

			fates[i] = ...

			if finishedCount >= #promises then
				resolve(fates)
			end
		end

		onCancel(function()
			for _, promise in ipairs(newPromises) do
				promise:cancel()
			end
		end)

		-- We can assume the values inside `promises` are all promises since we
		-- checked above.
		for i = 1, #promises do
			table.insert(
				newPromises,
				promises[i]:finally(
					function(...)
						resolveOne(i, ...)
					end
				)
			)
		end
	end)
end

--[[
	Races a set of Promises and returns the first one that resolves,
	cancelling the others.
]]
function Promise.race(promises)
	assert(type(promises) == "table", ERROR_NON_LIST:format("Promise.race"))

	for i, promise in pairs(promises) do
		assert(Promise.is(promise), (ERROR_NON_PROMISE_IN_LIST):format("Promise.race", tostring(i)))
	end

	return Promise.new(function(resolve, reject, onCancel)
		local newPromises = {}
		local finished = false

		local function cancel()
			for _, promise in ipairs(newPromises) do
				promise:cancel()
			end
		end

		local function finalize(callback)
			return function (...)
				cancel()
				finished = true
				return callback(...)
			end
		end

		if onCancel(finalize(reject)) then
			return
		end

		for _, promise in ipairs(promises) do
			table.insert(
				newPromises,
				promise:andThen(finalize(resolve), finalize(reject))
			)
		end

		if finished then
			cancel()
		end
	end)
end

--[[
	Is the given object a Promise instance?
]]
function Promise.is(object)
	if type(object) ~= "table" then
		return false
	end

	return type(object.andThen) == "function"
end

--[[
	Converts a yielding function into a Promise-returning one.
]]
function Promise.promisify(callback)
	return function(...)
		local traceback = debug.traceback()
		local length, values = pack(...)
		return Promise.new(function(resolve, reject)
			coroutine.wrap(function()
				local ok, resultLength, resultValues = packResult(pcall(callback, unpack(values, 1, length)))
				if ok then
					resolve(unpack(resultValues, 1, resultLength))
				else
					reject((resultValues[1] or "error") .. "\n" .. traceback)
				end
			end)()
		end)
	end
end

--[[
	Creates a Promise that resolves after given number of seconds.
]]
do
	local connection
	local queue = {}

	local function enqueue(callback, seconds)
		table.insert(queue, {
			callback = callback,
			startTime = tick(),
			endTime = tick() + math.max(seconds, 1/60)
		})

		table.sort(queue, function(a, b)
			return a.endTime < b.endTime
		end)

		if not connection then
			connection = RunService.Heartbeat:Connect(function()
				while #queue > 0 and queue[1].endTime <= tick() do
					local item = table.remove(queue, 1)

					item.callback(tick() - item.startTime)
				end

				if #queue == 0 then
					connection:Disconnect()
					connection = nil
				end
			end)
		end
	end

	local function dequeue(callback)
		for i, item in ipairs(queue) do
			if item.callback == callback then
				table.remove(queue, i)
				break
			end
		end
	end

	function Promise.delay(seconds)
		assert(type(seconds) == "number", "Bad argument #1 to Promise.delay, must be a number.")
		-- If seconds is -INF, INF, or NaN, assume seconds is 0.
		-- This mirrors the behavior of wait()
		if seconds < 0 or seconds == math.huge or seconds ~= seconds then
			seconds = 0
		end

		return Promise.new(function(resolve, _, onCancel)
			enqueue(resolve, seconds)

			onCancel(function()
				dequeue(resolve)
			end)
		end)
	end
end

--[[
	Rejects the promise after `seconds` seconds.
]]
function Promise.prototype:timeout(seconds, timeoutValue)
	return Promise.race({
		Promise.delay(seconds):andThen(function()
			return Promise.reject(timeoutValue == nil and "Timed out" or timeoutValue)
		end),
		self
	})
end

function Promise.prototype:getStatus()
	return self._status
end

--[[
	Creates a new promise that receives the result of this promise.

	The given callbacks are invoked depending on that result.
]]
function Promise.prototype:_andThen(traceback, successHandler, failureHandler)
	self._unhandledRejection = false

	-- Create a new promise to follow this part of the chain
	return Promise._new(traceback, function(resolve, reject)
		-- Our default callbacks just pass values onto the next promise.
		-- This lets success and failure cascade correctly!

		local successCallback = resolve
		if successHandler then
			successCallback = createAdvancer(
				traceback,
				successHandler,
				resolve,
				reject
			)
		end

		local failureCallback = reject
		if failureHandler then
			failureCallback = createAdvancer(
				traceback,
				failureHandler,
				resolve,
				reject
			)
		end

		if self._status == Promise.Status.Started then
			-- If we haven't resolved yet, put ourselves into the queue
			table.insert(self._queuedResolve, successCallback)
			table.insert(self._queuedReject, failureCallback)
		elseif self._status == Promise.Status.Resolved then
			-- This promise has already resolved! Trigger success immediately.
			successCallback(unpack(self._values, 1, self._valuesLength))
		elseif self._status == Promise.Status.Rejected then
			-- This promise died a terrible death! Trigger failure immediately.
			failureCallback(unpack(self._values, 1, self._valuesLength))
		elseif self._status == Promise.Status.Cancelled then
			-- We don't want to call the success handler or the failure handler,
			-- we just reject this promise outright.
			reject("Promise is cancelled")
		end
	end, self)
end

function Promise.prototype:andThen(successHandler, failureHandler)
	assert(
		successHandler == nil or type(successHandler) == "function",
		ERROR_NON_FUNCTION:format("Promise:andThen")
	)
	assert(
		failureHandler == nil or type(failureHandler) == "function",
		ERROR_NON_FUNCTION:format("Promise:andThen")
	)

	return self:_andThen(debug.traceback(), successHandler, failureHandler)
end

--[[
	Used to catch any errors that may have occurred in the promise.
]]
function Promise.prototype:catch(failureCallback)
	assert(
		failureCallback == nil or type(failureCallback) == "function",
		ERROR_NON_FUNCTION:format("Promise:catch")
	)
	return self:_andThen(debug.traceback(), nil, failureCallback)
end

--[[
	Like andThen, but the value passed into the handler is also the
	value returned from the handler.
]]
function Promise.prototype:tap(tapCallback)
	assert(type(tapCallback) == "function", ERROR_NON_FUNCTION:format("Promise:tap"))
	return self:_andThen(debug.traceback(), function(...)
		local callbackReturn = tapCallback(...)

		if Promise.is(callbackReturn) then
			local length, values = pack(...)
			return callbackReturn:andThen(function()
				return unpack(values, 1, length)
			end)
		end

		return ...
	end)
end

--[[
	Calls a callback on `andThen` with specific arguments.
]]
function Promise.prototype:andThenCall(callback, ...)
	assert(type(callback) == "function", ERROR_NON_FUNCTION:format("Promise:andThenCall"))
	local length, values = pack(...)
	return self:_andThen(debug.traceback(), function()
		return callback(unpack(values, 1, length))
	end)
end

--[[
	Shorthand for an andThen handler that returns the given value.
]]
function Promise.prototype:andThenReturn(...)
	local length, values = pack(...)
	return self:_andThen(debug.traceback(), function()
		return unpack(values, 1, length)
	end)
end

--[[
	Cancels the promise, disallowing it from rejecting or resolving, and calls
	the cancellation hook if provided.
]]
function Promise.prototype:cancel()
	if self._status ~= Promise.Status.Started then
		return
	end

	self._status = Promise.Status.Cancelled

	if self._cancellationHook then
		self._cancellationHook()
	end

	if self._parent then
		self._parent:_consumerCancelled(self)
	end

	for child in pairs(self._consumers) do
		child:cancel()
	end

	self:_finalize()
end

--[[
	Used to decrease the number of consumers by 1, and if there are no more,
	cancel this promise.
]]
function Promise.prototype:_consumerCancelled(consumer)
	if self._status ~= Promise.Status.Started then
		return
	end

	self._consumers[consumer] = nil

	if next(self._consumers) == nil then
		self:cancel()
	end
end

--[[
	Used to set a handler for when the promise resolves, rejects, or is
	cancelled. Returns a new promise chained from this promise.
]]
function Promise.prototype:_finally(traceback, finallyHandler, onlyOk)
	if not onlyOk then
		self._unhandledRejection = false
	end

	-- Return a promise chained off of this promise
	return Promise._new(traceback, function(resolve, reject)
		local finallyCallback = resolve
		if finallyHandler then
			finallyCallback = createAdvancer(
				traceback,
				finallyHandler,
				resolve,
				reject
			)
		end

		if onlyOk then
			local callback = finallyCallback
			finallyCallback = function(...)
				if self._status == Promise.Status.Rejected then
					return resolve(self)
				end

				return callback(...)
			end
		end

		if self._status == Promise.Status.Started then
			-- The promise is not settled, so queue this.
			table.insert(self._queuedFinally, finallyCallback)
		else
			-- The promise already settled or was cancelled, run the callback now.
			finallyCallback(self._status)
		end
	end, self)
end

function Promise.prototype:finally(finallyHandler)
	assert(
		finallyHandler == nil or type(finallyHandler) == "function",
		ERROR_NON_FUNCTION:format("Promise:finally")
	)
	return self:_finally(debug.traceback(), finallyHandler)
end

--[[
	Calls a callback on `finally` with specific arguments.
]]
function Promise.prototype:finallyCall(callback, ...)
	assert(type(callback) == "function", ERROR_NON_FUNCTION:format("Promise:finallyCall"))
	local length, values = pack(...)
	return self:_finally(debug.traceback(), function()
		return callback(unpack(values, 1, length))
	end)
end

--[[
	Shorthand for a finally handler that returns the given value.
]]
function Promise.prototype:finallyReturn(...)
	local length, values = pack(...)
	return self:_finally(debug.traceback(), function()
		return unpack(values, 1, length)
	end)
end

--[[
	Similar to finally, except rejections are propagated through it.
]]
function Promise.prototype:done(finallyHandler)
	assert(
		finallyHandler == nil or type(finallyHandler) == "function",
		ERROR_NON_FUNCTION:format("Promise:finallyO")
	)
	return self:_finally(debug.traceback(), finallyHandler, true)
end

--[[
	Calls a callback on `done` with specific arguments.
]]
function Promise.prototype:doneCall(callback, ...)
	assert(type(callback) == "function", ERROR_NON_FUNCTION:format("Promise:doneCall"))
	local length, values = pack(...)
	return self:_finally(debug.traceback(), function()
		return callback(unpack(values, 1, length))
	end, true)
end

--[[
	Shorthand for a done handler that returns the given value.
]]
function Promise.prototype:doneReturn(...)
	local length, values = pack(...)
	return self:_finally(debug.traceback(), function()
		return unpack(values, 1, length)
	end, true)
end

--[[
	Yield until the promise is completed.

	This matches the execution model of normal Roblox functions.
]]
function Promise.prototype:awaitStatus()
	self._unhandledRejection = false

	if self._status == Promise.Status.Started then
		local bindable = Instance.new("BindableEvent")

		self:finally(function()
			bindable:Fire()
		end)

		bindable.Event:Wait()
		bindable:Destroy()
	end

	if self._status == Promise.Status.Resolved then
		return self._status, unpack(self._values, 1, self._valuesLength)
	elseif self._status == Promise.Status.Rejected then
		return self._status, unpack(self._values, 1, self._valuesLength)
	end

	return self._status
end

--[[
	Calls awaitStatus internally, returns (isResolved, values...)
]]
function Promise.prototype:await(...)
	local length, result = pack(self:awaitStatus(...))
	local status = table.remove(result, 1)

	return status == Promise.Status.Resolved, unpack(result, 1, length - 1)
end

--[[
	Calls await and only returns if the Promise resolves.
	Throws if the Promise rejects or gets cancelled.
]]
function Promise.prototype:awaitValue(...)
	local length, result = pack(self:awaitStatus(...))
	local status = table.remove(result, 1)

	assert(
		status == Promise.Status.Resolved,
		tostring(result[1] == nil and "" or result[1])
	)

	return unpack(result, 1, length - 1)
end

--[[
	Intended for use in tests.

	Similar to await(), but instead of yielding if the promise is unresolved,
	_unwrap will throw. This indicates an assumption that a promise has
	resolved.
]]
function Promise.prototype:_unwrap()
	if self._status == Promise.Status.Started then
		error("Promise has not resolved or rejected.", 2)
	end

	local success = self._status == Promise.Status.Resolved

	return success, unpack(self._values, 1, self._valuesLength)
end

function Promise.prototype:_resolve(...)
	if self._status ~= Promise.Status.Started then
		if Promise.is((...)) then
			(...):_consumerCancelled(self)
		end
		return
	end

	-- If the resolved value was a Promise, we chain onto it!
	if Promise.is((...)) then
		-- Without this warning, arguments sometimes mysteriously disappear
		if select("#", ...) > 1 then
			local message = (
				"When returning a Promise from andThen, extra arguments are " ..
				"discarded! See:\n\n%s"
			):format(
				self._source
			)
			warn(message)
		end

		local chainedPromise = ...

		local promise = chainedPromise:andThen(
			function(...)
				self:_resolve(...)
			end,
			function(...)
				-- The handler errored. Replace the inner stack trace with our outer stack trace.
				if chainedPromise._error then
					return self:_reject((chainedPromise._error or "") .. "\n" .. self._source)
				end
				self:_reject(...)
			end
		)

		if promise._status == Promise.Status.Cancelled then
			self:cancel()
		elseif promise._status == Promise.Status.Started then
			-- Adopt ourselves into promise for cancellation propagation.
			self._parent = promise
			promise._consumers[self] = true
		end

		return
	end

	self._status = Promise.Status.Resolved
	self._valuesLength, self._values = pack(...)

	-- We assume that these callbacks will not throw errors.
	for _, callback in ipairs(self._queuedResolve) do
		callback(...)
	end

	self:_finalize()
end

function Promise.prototype:_reject(...)
	if self._status ~= Promise.Status.Started then
		return
	end

	self._status = Promise.Status.Rejected
	self._valuesLength, self._values = pack(...)

	-- If there are any rejection handlers, call those!
	if not isEmpty(self._queuedReject) then
		-- We assume that these callbacks will not throw errors.
		for _, callback in ipairs(self._queuedReject) do
			callback(...)
		end
	else
		-- At this point, no one was able to observe the error.
		-- An error handler might still be attached if the error occurred
		-- synchronously. We'll wait one tick, and if there are still no
		-- observers, then we should put a message in the console.

		local err = tostring((...))

		coroutine.wrap(function()
			RunService.Heartbeat:Wait()

			-- Someone observed the error, hooray!
			if not self._unhandledRejection then
				return
			end

			-- Build a reasonable message
			local message
			if self._error then
				message = ("Unhandled promise rejection:\n\n%s"):format(err)
			else
				message = ("Unhandled promise rejection:\n\n%s\n\n%s"):format(
					err,
					self._source
				)
			end
			warn(message)
		end)()
	end

	self:_finalize()
end

--[[
	Calls any :finally handlers. We need this to be a separate method and
	queue because we must call all of the finally callbacks upon a success,
	failure, *and* cancellation.
]]
function Promise.prototype:_finalize()
	for _, callback in ipairs(self._queuedFinally) do
		-- Purposefully not passing values to callbacks here, as it could be the
		-- resolved values, or rejected errors. If the developer needs the values,
		-- they should use :andThen or :catch explicitly.
		callback(self._status)
	end

	if self._parent and self._error == nil then
		self._error = self._parent._error
	end

	-- Allow family to be buried
	if not Promise.TEST then
		self._parent = nil
		self._consumers = nil
	end
end

return Promise