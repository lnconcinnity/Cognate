-- PacketParser.lua, BufferWriter.lua, Channel.lua and Remote.lua were originally of ffrostfall's ByteNet networking system; repurposed for my own uses

local Channel = {}
function Channel.new()
    return setmetatable({_queue = {}}, {__index = Channel})
end

function Channel:add(input: any)
    self._queue[#self._queue+1] = input
end

function Channel:flush()
    if #self._queue <= 0 then return nil end
    local flushedQueue = table.clone(self._queue)
    table.clear(self._queue)
    return flushedQueue
end

function Channel:Destroy()
    table.clear(self._queue)
    self._queue = nil
    setmetatable(self, nil)
end

return Channel