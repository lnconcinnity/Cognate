type signal = RBXScriptSignal&{Connect:(self:{})->()}

local CachedProxies = {
    Nest = {},
    Index = {},
}
local SavedTables = setmetatable({},{__mode="v"})
local SavedConnections = setmetatable({}, {__mode="k"})

local ProxyReflector = {}
function ProxyReflector.SaveTable(table: {})
    SavedTables[#SavedTables+1] = table
end

function ProxyReflector.ClearTable(srcTbl: {})
    local at = table.find(SavedTables, srcTbl)
    if at then
        return table.remove(SavedTables, at)
    end
end

function ProxyReflector.GetTables()
    return SavedTables
end

function ProxyReflector.BindConnection(connHook: {}, sig: signal)
    if not SavedConnections[sig] then
        SavedConnections[sig] = {}
    end
    SavedConnections[sig][connHook] = true
end

function ProxyReflector.UnbindConnection(connHook: {}, sig: signal)
    if SavedConnections[sig] then
        SavedConnections[sig][connHook] = nil
    end
end

function ProxyReflector.GetConnections(sig: signal): {any}
    if SavedConnections[sig] then
        local conns = {}
        for connHook in pairs(SavedConnections[sig]) do
            conns[#conns+1] = connHook
        end
        return conns
    end
end

function ProxyReflector.GetFromCache(of: any): any
    local at = CachedProxies.Nest[of]
    return assert(CachedProxies.Index[at], "Proxy caching fault")
end

function ProxyReflector.GetProxyFromCache(from: any): any
    local at = table.find(CachedProxies.Index, from)
    if at then
        for proxy: any, sameAt: number in pairs(CachedProxies.Nest) do
            if sameAt == at then
                return proxy
            end
        end
    end
end

function ProxyReflector.SaveToCache(of: any, from: any)
    local index = #CachedProxies.Index+1
    CachedProxies.Nest[from] = index
    CachedProxies.Index[index] = of
end

function ProxyReflector.RemoveFromCache(of: any)
    local at = CachedProxies.Nest[of]
    if at then
        CachedProxies.Nest[of] = nil
        for proxyAsKey: any, oldIndex: number in pairs(CachedProxies.Nest) do
            if oldIndex < at then
                continue
            end
            CachedProxies.Nest[proxyAsKey] = oldIndex-1
        end
        return table.remove(CachedProxies.Index, at)
    end
end

return ProxyReflector