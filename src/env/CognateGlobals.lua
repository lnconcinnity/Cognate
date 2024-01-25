local GLOBALS = {}
GLOBALS.Libraries = {} do
    for _, module in ipairs(script.Parent.Parent.lib:GetChildren()) do
        if module:IsA("ModuleScript") then
            local success, result = xpcall(require, warn, module)
            if success then
                GLOBALS.Libraries[module.Name] = result
            end
        end
    end
end
return GLOBALS