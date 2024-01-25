type closure = (...any) -> (...any) | thread

local SavedLuaClosures = setmetatable({}, {__mode = 'kv'})
local SavedCClosures = setmetatable({}, {__mode = 'kv'})

local FunctionReflector = {}
function FunctionReflector.SaveClosureIds(cclosure: closure | string, luaclosure: closure | string)
    local c, l = tostring(cclosure), tostring(luaclosure)
    SavedLuaClosures[c] = l
    SavedCClosures[l] = c
end

function FunctionReflector.GetLuaClosureIdFromC(cclosure: closure | string) -- retrieves the lua closure of a c closure
    return SavedLuaClosures[tostring(cclosure)]
end

function FunctionReflector.GetCClosureFromLua(closure: closure | string) -- retrieves the c closure from a saved lua closure reference
    return SavedCClosures[tostring(closure)]
end

return FunctionReflector