--queue, by me (boyned)
local QueueTemplate = {}

function QueueTemplate:Enqueue(value)
	table.insert(self.queue, 1, value)
end

function QueueTemplate:Dequeue()
	return table.remove(self.queue)
end

function QueueTemplate:Front()
	return self.queue[#self.queue]
end

function QueueTemplate:Back()
	return self.queue[1]
end

function QueueTemplate:Length()
	return #self.queue
end

local QueueMetatable = {}
QueueMetatable.__index = QueueTemplate

local Queue = {}

Queue.new = function(list)
	return setmetatable({
		queue = list or {}
	}, QueueMetatable)
end

return Queue
