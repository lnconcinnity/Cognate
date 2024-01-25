local IGNORED_STATICS = {['TableReflector'] = true}

local function wrap(static: ModuleScript): (any)
    local success, result = xpcall(require, warn, static)
    if success then
        return if type(result) == "table" then result.new else result
    end
end

local static = {}
for _, object in ipairs(script:GetChildren()) do
    if IGNORED_STATICS[object.Name] then continue end
    static[object.Name] = wrap(object)
end
return static