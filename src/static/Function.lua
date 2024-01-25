type closure = (...any) -> (...any) | thread
type fenv = {[string]: any}

local C = require(script.Parent.Parent.lib.C)

local CognateFunctions = {}

local CognateFunctionAPI = {}
CognateFunctionAPI.__index = CognateFunctionAPI
function CognateFunctionAPI:__call(...: any): any
    local results = {self._closures[#self._closures](...)}
    local snapshots = #self._functionSnapshots
    if snapshots > 0 then
        local index = 1
        while index < snapshots do
            index += 1
            task.spawn(self._functionSnapshots[index])
        end
    end
    return table.unpack(results)
end

function CognateFunctionAPI:Hook(newClosure: closure): closure
    local nextStack = #self._closures+1
    self._closures[nextStack] = newClosure
    CognateFunctions[tostring(newClosure)] = self
    return self._closures[nextStack-1] -- return the previous stacked closure as our oldHook
end

function CognateFunctionAPI:Reset()
    local baseClosure = self._closures[1]
    table.clear(self._closures) do
        local realClosureKey = tostring(baseClosure)
        for at: string, reflection: any in pairs(CognateFunctions) do
            if at == realClosureKey then continue end
            if reflection == self then
                CognateFunctions[at] = nil
            end
        end
    end
    self._closures[1] = baseClosure
end

function CognateFunctionAPI:GetClosureAddress()
    local closureNames = {}
    for i = 1, #self._closures do
        closureNames[#closureNames+1] = tostring(self._closures[i])
    end
    return closureNames
end

function CognateFunctionAPI:BindSnapshot(snapshot: closure)
    self._functionSnapshots[#self._functionSnapshots+1] = snapshot
end

function CognateFunctionAPI:GetRealClosure()
    return self._closures[1]
end

local CognateFunction = {}
-- Explicitly returns as a function type, though it is actually a table
function CognateFunction.new(closure: closure): closure
    local self = {}
    self.ClosureAddress = tostring(closure)
    self._functionSnapshots = {}
    self._closures = {closure}--{modifyEnvironment(closure, self._sourceEnv)}
    setmetatable(self, CognateFunctionAPI)
    CognateFunctions[tostring(closure)] = self
    return self
end
type CognateFunction = typeof(CognateFunction.new(function() end))

function CognateFunction.is(closure: any)
    return type(closure) == "table" and getmetatable(closure) == CognateFunctionAPI
end

function CognateFunction.get(closureName: string): CognateFunction?
    return CognateFunctions[closureName]
end

-- the result may not be truthful, so it's best to check whether the function exists or not
function CognateFunction.snatch(level: number?): CognateFunction?
    local closure = C.getStackInfo(level or 2).closure
    if closure then
        return CognateFunctions[tostring(closure)]
    end
    warn("No closure entity was found")
end

return CognateFunction