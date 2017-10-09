local QueueTemplate = {}

function QueueTemplate:Enqueue(value)
	table.insert(self.queue, 1, value)
end

function QueueTemplate:Dequeue(value)
	return table.remove(self.queue)
end

function QueueTemplate:Front()
	return self.queue[#self.queue]
end

function QueueTemplate:Back()
	return self.queue[1]
end

local QueueMetatable = {}
QueueMetatable.__index = QueueTemplate

local Queue = {}

Queue.new = function(tabl)
	local queue = tabl or {}
	
	queue.queue = {}
	
	setmetatable(queue, QueueMetatable)
	
	return queue
end

return Queue
