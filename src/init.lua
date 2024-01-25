local static = require(script.static)
local env = require(script.env)

return setmetatable({
    BUILD_VERSION = script.version.Value,
}, {
    __index = function(_self: {}, key: string): any
        return static[key]
    end,
    __call = function(_self: {})
        env.build()
    end,
})