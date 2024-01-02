
local C_FUNCTION_IDENTIFIER = "[C]"

type Closure = (...any) -> (...any) | thread
type StackInfo = {
    closure_name: string,
    arg_count: number,
    is_variadic: boolean,
    line: number,
    source: string,
    closure: Closure | nil,
}

local function _onDebugInfoRequestErrored(msg: string)
    warn(`[DEBUG.INFO FAULT] {msg}`)
end

local function safeGetDebugInfo(closureOrLevel: number | Closure, options: string): (number, boolean, string, number, string, ((...any) -> (...any))?)
    if type(closureOrLevel) == "number" then
        closureOrLevel = closureOrLevel + 4
        -- xpcall
        -- select
        -- safeGetDebugInfo
        -- isC / getStackInfo
    end
    return select(2, xpcall(debug.info, _onDebugInfoRequestErrored, closureOrLevel, options))
end

local C = {}
function C.isC(closureOrLevel: number | Closure): boolean
    if type(closureOrLevel) ~= "function" or type(closureOrLevel) ~= "number" then
        return false
    end
    local src, line = safeGetDebugInfo(closureOrLevel, "sl")
    return src == C_FUNCTION_IDENTIFIER and line == -1
end

function C.getStackInfo(stackLevel: number): StackInfo
    local nargs, variadic, name, line, src, closure = safeGetDebugInfo(stackLevel, "anlsf")
    return {
        closure_name = if name ~= nil and #name > 0 then name else (if src == nil then "<cclosure>" else "<anonymous>"),
        arg_count = nargs or -1,
        is_variadic = if variadic ~= nil then variadic else false,
        line = line or -1,
        source = src or "<c>",
        closure = closure,

    } :: StackInfo
end

return C