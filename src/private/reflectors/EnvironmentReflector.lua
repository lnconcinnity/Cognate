type fenv = {[string]: any}
type closure = (...any) -> (...any) | thread

local C = require(script.Parent.Parent.Parent.lib.C)

local TARGET_STACK_SET_LEVEL = 3

local ReflectedEnvironments = {}

local EnvironmentReflector = {}
function EnvironmentReflector.Append(env: fenv)
    local info = C.getStackInfo(TARGET_STACK_SET_LEVEL)
    if info.source ~= "<c>" then
        if not ReflectedEnvironments[info.source] then
            ReflectedEnvironments[info.source] = env
        end
    end
end

function EnvironmentReflector.GetFrom(id: string): fenv
    return assert(ReflectedEnvironments[id], `Environment {id} does not exist.`)
end

function EnvironmentReflector.Modify(closure: closure, rfEnv: fenv)
    local env = getfenv(closure)
    setfenv(closure, setmetatable({}, {
        __index = function(_self: fenv, key: string): any
            return rfEnv[key] or env[key]
        end,
    }))
end

return EnvironmentReflector