type fenv = {[string]: any}
type closure = (...any) -> (...any) | thread
type signal = RBXScriptSignal&{Connect:(self:{})->()}

local CognateGlobals = require(script.CognateGlobals)
local CognateFunction = require(script.Parent.static.Function)
local ValueReflector = require(script.Parent.private.reflectors.ValueReflector)
local EnvironmentReflector = require(script.Parent.private.reflectors.EnvironmentReflector)
local FunctionReflector = require(script.Parent.private.reflectors.FunctionReflector)
local ProxyReflector = require(script.Parent.private.reflectors.ProxyReflector)

local TARGET_CLOSURE_ENVIRONMENT = 3
local COGNATE_CLOSURE_IDENTIFIER = CognateGlobals.Libraries.Symbol("CognateClosure")
local EMPTY_TABLE_TEMPLATE = {}

local CognateInternalEnvironment = {}

--//
--// GETTERS
--//
function CognateInternalEnvironment:getsenv()
    error("This method is not supported (Roblox limitations)")
end

function CognateInternalEnvironment:getmenv()
    error("This method is not supported (Roblox limitations)")
end

function CognateInternalEnvironment:getgenv()
    return CognateGlobals
end

function CognateInternalEnvironment:getrenv()
    return _G
end

function CognateInternalEnvironment:getconnections(sig: signal)
    return ProxyReflector.GetConnections(sig) or table.clone(EMPTY_TABLE_TEMPLATE)
end

--[=[
    getreg(): {[number]: table}

    Returns an array of reflected tables and metatables initialized using Cognate
]=]
function CognateInternalEnvironment:getreg()
    return ProxyReflector.GetTables()
end

--//
--// CLOSURES
--//

--[=[
    hookfunction(closure: function): function
]=]
function CognateInternalEnvironment:hookfunction(oldClosure: closure, newClosure: closure): closure
    assert(type(oldClosure) ~= "thread", "Argument 1 cannot be coroutine")
    if CognateFunction.is(oldClosure) then
        return oldClosure:Hook(newClosure)
    else
        local cognateFunction = CognateFunction.get(tostring(oldClosure))
        if cognateFunction then
            return cognateFunction:Hook(newClosure)
        end
    end
    warn(`The first provided argument was an invalid reflection (Not a Cognate Function)\t{debug.traceback()}`)
end

--[=[
    newcclosure(closure: function): thread
    
    Wraps the closure within a coroutine, thus making it C level closure
]=]
function CognateInternalEnvironment:newcclosure(closure: closure)
    local cclosure = coroutine.wrap(function(...: any)
        while true do
            coroutine.yield(closure(...))
        end
    end)
    FunctionReflector.SaveClosureIds(cclosure, closure)
    return cclosure
end

function CognateInternalEnvironment:iscognateclosure(closure: closure): boolean
    return CognateFunction.is(closure)
end

function CognateInternalEnvironment:iscclosure(closure: closure): boolean
    return (type(closure) == 'function' or type(closure) == 'thread') and debug.info(closure, 'n') == '[C]'
end

function CognateInternalEnvironment:isluaclosure(closure: closure): boolean
    return (type(closure) == 'function' or type(closure) == 'thread') and debug.info(closure, 'n') ~= '[C]'
end

--// METATABLES
function CognateInternalEnvironment:setmetatable() 
    
end

--//
--// UPVALUES
--//
function CognateInternalEnvironment:setupvalue(index: number, value: any)
    ValueReflector.SetValue(index, value)
end

function CognateInternalEnvironment:getupvalue(index: number)
    return ValueReflector.GetValue(index)
end

function CognateInternalEnvironment:getupvalues()
    return ValueReflector.GetValues()
end

--// HELPER
function CognateInternalEnvironment:rawvalue(value: {}): any
    if type(value) == "table" and type(value.get) == "function" then
        return value:get()
    end
    return value
end

--// PROTOTYPE
local CognateInternalEnvironmentPrototype = {__index = CognateInternalEnvironment}

local CognateEnvironment = {}
function CognateEnvironment.build()
    local fakeEnv;
    local internalEnv = setmetatable({
        ClosureIdentity = COGNATE_CLOSURE_IDENTIFIER
    }, CognateInternalEnvironmentPrototype)
    local env = getfenv(TARGET_CLOSURE_ENVIRONMENT)
    fakeEnv = setmetatable(EMPTY_TABLE_TEMPLATE, {
        __index = function(_self: fenv, key: string): any
            local cognateEnvResult = internalEnv[key]
            if type(cognateEnvResult) == "function" then
                -- return a wrapper instead
                return function(...: any): any
                    return internalEnv[key](internalEnv, ...)
                end
            end
            return cognateEnvResult or CognateGlobals[key] or env[key]
        end,
    })
    EnvironmentReflector.Append(fakeEnv)
    setfenv(TARGET_CLOSURE_ENVIRONMENT, fakeEnv)
end

return CognateEnvironment