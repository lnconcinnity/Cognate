local ProxyReflector = require(script.Parent.reflectors.ProxyReflector)

local ConnectionHook = {}
ConnectionHook.__index = ConnectionHook
function ConnectionHook.new(connection: {}, sig: RBXScriptSignal&{Connect: (self:{})->()}, fn: (...any) -> ()): ({Function: (...any) -> (), Fire: (self: {}, ...any) -> (), Enable: (self: {}) -> (), Disable: (self: {}) -> ()})
    local hook = {}
    hook._conn = connection
    hook._parentSig = sig
    hook.Function = fn
    setmetatable(hook, ConnectionHook)
    return hook
end

function ConnectionHook:Fire(...)
    self.Function(...)
end

function ConnectionHook:Disable()
    self._conn._disabled = true
end

function ConnectionHook:Enable()
    self._conn._disabled = false
end

function ConnectionHook:Destroy()
    ProxyReflector.UnbindConnection(self, self._parentSig)
    self._conn = nil
    self._parentSig = nil
    self.Function = nil
    setmetatable(self, nil)
end

local ConnectionAPI = {}
function ConnectionAPI:__index(key: string): any
    return ConnectionAPI[key] or self._conn[key]
end
function ConnectionAPI:Disconnect()
    local connHook = self._connHook
    if connHook then
        connHook:Destroy()
    end
    self._conn:Disconnect()
    self._conn = nil
    self._connHook = nil
    setmetatable(self, nil)
end

return function(realSignal: RBXScriptSignal): ((fn: (...any)->())->(RBXScriptConnection))
    return function(selfSignal: {}, fn: (...any) -> ()): RBXScriptConnection
        local connection = {}
        connection._disabled = false
        local conn = realSignal:Connect(function(...: any)
            if not connection._disabled then
                fn(...)
            end
        end)
        connection._conn = conn
        local connectionHook = ConnectionHook.new(connection, selfSignal, fn)
        connection._hook = connectionHook
        setmetatable(connection, ConnectionAPI)
        ProxyReflector.BindConnection(connectionHook, selfSignal)
        return connection
    end
end