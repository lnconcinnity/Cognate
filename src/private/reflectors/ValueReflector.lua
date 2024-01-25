
local C = require(script.Parent.Parent.Parent.lib.C)
local Symbol = require(script.Parent.Parent.Parent.lib.Symbol)
local CognateFunction = require(script.Parent.Parent.Parent.static.Function)
local Value = require(script.Parent.Parent.Parent.lib.Value)
local FunctionReflector = require(script.Parent.FunctionReflector)
local ProxyWrapper = require(script.Parent.Parent.ProxyWrapper)

local VALUES_CONTAINER_MARKER = Symbol("CachedClosureValues")
local VALUES_LINE_COUNT = Symbol("ClosureLineValueCount")
local TARGET_STACK_READ_LEVEL = 3
local REFLECTION_TEMPLATE = {[VALUES_CONTAINER_MARKER] = {}, [VALUES_LINE_COUNT] = {}}

local ReflectedCognateValues = {}

local function getClosureReflection(srcReflection: {}, curId: string)
    local cognateFn = CognateFunction.get(curId)
    local realId = curId
    if cognateFn then
        local fromCClosureFn = FunctionReflector.GetLuaClosureIdFromC(cognateFn.ClosureAddress)
        realId = fromCClosureFn or cognateFn.ClosureAddress
    end
    return srcReflection[realId]
end

local function getClosureReflectionFor(srcReflection: {}, curId: string)
    if srcReflection[curId] then return srcReflection[curId] end
    srcReflection[curId] = table.clone(REFLECTION_TEMPLATE)
    return srcReflection[curId]
end

local function getSourceReflection(sourceName: string)
    if ReflectedCognateValues[sourceName] then return ReflectedCognateValues[sourceName] end
    ReflectedCognateValues[sourceName] = table.clone(REFLECTION_TEMPLATE)
    return ReflectedCognateValues[sourceName]
end

local ValueReflector = {}
function ValueReflector.SetValue(index: number, newValue: any, forceValue: boolean?)
    local info = C.getStackInfo(TARGET_STACK_READ_LEVEL)
    local reflection = getSourceReflection(info.source)
    if reflection then
        local closureReflection = getClosureReflection(reflection, info.closure_address)
        if closureReflection then
            local foundReflection = closureReflection[index]
            if foundReflection then
                foundReflection:set(newValue, forceValue)
            else
                error("Index is out of bounds", 2)
            end
        elseif reflection[index] then
            reflection[index]:set(newValue, forceValue)
        else
            error("Index is out of bounds", 2)
        end
    else
        error("No upvalues were found", 2)
    end
end

function ValueReflector.GetValue(index: number): any
    local info = C.getStackInfo(TARGET_STACK_READ_LEVEL)
    local reflection = ReflectedCognateValues[info.source]
    if reflection then
        local closureReflection = getClosureReflection(reflection, info.closure_address)
        if closureReflection then
            if closureReflection[index] then
                return closureReflection[index]:get()
            else
                error("Index is out of bounds", 2)
            end
        elseif reflection[index] then
            return reflection[index]:get()
        else
            error("Index is out of bounds", 2)
        end
    end
    error("No upvalues were found", 2)
end

function ValueReflector.RetrieveValue(sourceScript: string, callingClosureId: string, callingLine: number, initialValue: any) -- get the value that was located under the function, create one if not
    local reflection = getSourceReflection(sourceScript)
    local closureReflection = nil
    if callingClosureId ~= "n/a" then
        closureReflection = getClosureReflectionFor(reflection, callingClosureId)
    end
    reflection = closureReflection or reflection
    local boundClosureId = FunctionReflector.GetCClosureFromLua(callingClosureId) or callingClosureId
    local container = if closureReflection then closureReflection[VALUES_CONTAINER_MARKER] else reflection[VALUES_CONTAINER_MARKER]
    if not container[callingLine] then
        container[callingLine] = {
            values = {},
            inlineCursor = 1,
        }
        local boundCognateFn = CognateFunction.get(boundClosureId)
        if boundCognateFn then
            boundCognateFn:BindSnapshot(function()
                container.inlineCursor = 1
            end)
        end
    end
    container = container[callingLine]
    local value = container.values[container.inlineCursor]
    if not value then
        if container.inlineCursor > 1 and boundClosureId == "n/a" then
            warn("Please do not use inline variables on non-cognate functions/threads; please separate them on to different lines instead. (Bound cursor overflow)")
            container.inlineCursor = 1 -- force reset the cursor, this feature cannot be supported sadly
        end
        value = Value.new(ProxyWrapper(initialValue))
        container.values[#container.values+1] = value
        reflection[#reflection+1] = value
    end
    container.inlineCursor+=1
    return value
end

function ValueReflector.GetValues(): ({[number]: any}, number)
    local info = C.getStackInfo(TARGET_STACK_READ_LEVEL)
    local reflection = ReflectedCognateValues[info.source]
    local closureReflection = getClosureReflection(reflection, info.closure_address)
    local upvalues = {}
    reflection = closureReflection or reflection
    if reflection then
        for k,v in next, reflection do
            if type(k) == "number" then
                upvalues[#upvalues+1] = v:get()
            end
        end
    end
    return upvalues
end

return ValueReflector