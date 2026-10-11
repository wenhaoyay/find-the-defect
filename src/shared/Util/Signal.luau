-- A plain Luau signal for module-to-module events. Each handler runs in its own
-- thread (task.spawn), so a handler that yields or errors cannot hold up or break
-- the code that fired it.

local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection

function Signal.new()
    return setmetatable({ handlers = {} }, Signal)
end

function Signal:Connect(handler)
    local connection = setmetatable({ Connected = true, handler = handler, signal = self }, Connection)
    table.insert(self.handlers, connection)
    return connection
end

function Signal:Once(handler)
    local connection
    connection = self:Connect(function(...)
        connection:Disconnect()
        handler(...)
    end)
    return connection
end

function Signal:Fire(...)
    for _, connection in ipairs(table.clone(self.handlers)) do
        if connection.Connected then
            task.spawn(connection.handler, ...)
        end
    end
end

function Connection:Disconnect()
    if not self.Connected then
        return
    end
    self.Connected = false
    local index = table.find(self.signal.handlers, self)
    if index then
        table.remove(self.signal.handlers, index)
    end
end

return Signal
