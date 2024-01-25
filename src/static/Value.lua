
local ValueReflector = require(script.Parent.Parent.private.reflectors.ValueReflector)
local Value = require(script.Parent.Parent.lib.Value)
local C = require(script.Parent.Parent.lib.C)

return function(initialValue: any): typeof(Value.new(true))
    local caller = C.getStackInfo(1)
    return ValueReflector.RetrieveValue(caller.source, caller.closure_address, caller.line, initialValue)
end