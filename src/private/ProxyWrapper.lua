
local ProxyReflector = require(script.Parent.reflectors.ProxyReflector)
local Connection = require(script.Parent.Connection)

local InstanceWrapperAPI = nil

local function proxyWrapper(object: Instance)
    local existingProxy = ProxyReflector.GetProxyFromCache(object)
    if existingProxy then
        return existingProxy
    end
    local object_type = type(object)
    if object_type == "userdata" then
        local proxy = newproxy(true)
        local proxyMt = getmetatable(proxy)
        for metaKey: string, metaMethod: (...any) -> (...any) in pairs(InstanceWrapperAPI) do
            proxyMt[metaKey] = metaMethod
        end
        ProxyReflector.SaveToCache(object, proxy)
        return proxy
    elseif object_type == "table" then
        ProxyReflector.SaveTable(object)
    end
    return object
end

InstanceWrapperAPI = {
    __index = function(pSelf: {}, key: string): any
        local obj = ProxyReflector.GetFromCache(pSelf)
        local value = obj[key]
        local vtype = typeof(value)
        local otype = typeof(obj)

        if otype == "Instance" and vtype == "RBXScriptSignal" then
            return proxyWrapper(value)
        elseif otype == "RBXScriptSignal" and key == "Connect" then
            return Connection(obj)
        elseif vtype == "function" then
            return function(_proxy: {}, ...: any)
                return obj[key](obj, ...)
            end
        end
        return value
    end,
    __newindex = function(pSelf: {}, key: string, value: any)
        local obj = ProxyReflector.GetFromCache(pSelf)
        obj[key] = value
    end
}

return proxyWrapper