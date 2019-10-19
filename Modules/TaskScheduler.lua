-- An easier to unit test and more consistent scheduler
-- Prevents issues of scripts not running threads after destruction
local RunService = game:GetService("RunService")

local TaskScheduler = {}

TaskScheduler.REMOVE_ME = newproxy(true)

local heartbeats = {}
local spawns, spawnEvent = {}, Instance.new("BindableEvent")

spawnEvent.Event:connect(function()
	local callback = table.remove(spawns)
	callback()
	assert(#spawns == 0)
end)

function TaskScheduler.Heartbeat(step)
	if next(heartbeats) then
		debug.profilebegin("TaskScheduler.Heartbeat")
		for connection in pairs(heartbeats) do
			if connection.__callback(step) == TaskScheduler.REMOVE_ME then
				connection:Destroy()
			end
		end
		debug.profileend()
	end
end

function TaskScheduler.QueueHeartbeat(callback)
	local disconnected = Instance.new("BindableEvent")

	local object do
		object = {
			__callback = callback,

			Disconnected = disconnected.Event,

			Destroy = function()
				if heartbeats[object] then
					heartbeats[object] = nil
					disconnected:Fire()
				end
			end,
		}
	end

	heartbeats[object] = true

	return object
end

function TaskScheduler.QueueHeartbeatSeconds(seconds, callback)
	local total = 0
	local queue do
		queue = TaskScheduler.QueueHeartbeat(function(step)
			callback(step)
			total = total + step
			if total >= seconds then
				queue:Destroy()
			end
		end)
	end

	return queue
end

function TaskScheduler.Interval(interval, callback, max)
	local count = max or math.huge
	local total = 0

	local task do
		task = TaskScheduler.QueueHeartbeat(function(step)
			total = total + step

			while count > 0 and total >= interval do
				if callback() == TaskScheduler.REMOVE_ME then
					return TaskScheduler.REMOVE_ME
				end

				total = total - interval
				count = count - interval
			end

			if count <= 0 then
				task:Destroy()
			end
		end)
	end

	return task
end

function TaskScheduler.FastSpawn(callback)
	spawns[#spawns + 1] = callback
	spawnEvent:Fire()
end

function TaskScheduler.Delay(interval, callback)
	return TaskScheduler.Interval(interval, callback, interval)
end

RunService.Heartbeat:connect(TaskScheduler.Heartbeat)

return TaskScheduler
