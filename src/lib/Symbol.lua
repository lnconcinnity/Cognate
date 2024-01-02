local SYMBOL_KEY_PRESET = "Symbol<%s>"

type Symbol = typeof(newproxy(true))

local function makeSymbol(symbolName: string): Symbol
    local symbolKey = SYMBOL_KEY_PRESET:format(symbolName)
    local proxy = newproxy(true)
    getmetatable(proxy).__tostring = function()
        return symbolKey
    end
    return proxy
end

return makeSymbol