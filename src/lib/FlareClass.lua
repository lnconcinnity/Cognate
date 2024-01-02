local HttpService = game:GetService("HttpService")

local Symbol = require(script.Parent.Symbol)
local Value = require(script.Parent.Value)
local Hash = require(script.Parent.Hash)
local C = require(script.Parent.C)

local PUBLIC_KEY, PRIVATE_KEY, PROTECTED_KEY, FN_REFERENCE_KEY, OBJECT_REFERENCE_KEY, FRIEND_MARKER_KEY = Symbol "PublicMembers", Symbol "PrivateMembers", Symbol "ProtectedMembers", Symbol "FunctionReferences", Symbol "ObjectReference", Symbol "FriendMarker"
local MAX_STACK_LEVEL = 2^16
local EXEMPTED_STATIC_FIELDS = {['extend'] = true, ['new'] = true}
local NOT_FRIEND_INTERNAL_FIELDS = {['GetPropertyChangedSignal'] = true}

local FlareClassObjects = {}
local FlareClassHelper = {}
local FlareClassAPI = {}

--
-- Internal helper functions
--
function FlareClassHelper.seekFunctionInTruthOrigin(objectId: string): boolean
    local currentLevel = 1
    local currentClosure = coroutine.running()

    local originOk = false
    local objectStructure = FlareClassObjects[objectId]
    debug.profilebegin("flareClass.functionoriginseeking.accessidentifier")
    while currentClosure ~= nil or originOk == false do
        local stackInfo = C.getStackInfo(currentLevel)
        -- check if we should skip the closure
        if stackInfo.line ~= -1 and (stackInfo.closure_name:sub(1, 2) ~= "__" or not rawequal(stackInfo.closure, FlareClassHelper[stackInfo.closure_name])) then
            currentClosure = stackInfo.closure
            local fnRefs = objectStructure[FN_REFERENCE_KEY]
            local closureAddress = tostring(currentClosure)
            if (fnRefs[closureAddress] or objectStructure[FRIEND_MARKER_KEY][closureAddress]) and not NOT_FRIEND_INTERNAL_FIELDS[stackInfo.closure_name] then
                originOk = true
            end
        elseif stackInfo.line == -1 or currentLevel > MAX_STACK_LEVEL then
            break
        end
        currentLevel += 1
        currentClosure = stackInfo.closure
    end
    debug.profileend()

    return originOk
end

--
-- Internal API
--

-- manage indexing, such as when indexing MyClass._player, MyClass.HEALTH, MyClass.damage, etc
function FlareClassAPI:__index<T>(key: T): T
    local key_, mustGetRaw = string.gsub(key, ".raw$", "")
    mustGetRaw = if type(mustGetRaw) == "number" then mustGetRaw > 0 else false
    local objectId = rawget(self, OBJECT_REFERENCE_KEY)
    local objectStructure = FlareClassObjects[objectId]
    local identifierCount = select(2, string.find(key_:sub(1, 2), '_', 1))
    local isIndexingLowLevelMembers = if identifierCount ~= nil and identifierCount == 1 then FlareClassHelper.seekFunctionInTruthOrigin(objectId) else true
    local value = objectStructure[PUBLIC_KEY][key_] or objectStructure[PROTECTED_KEY][key_] or objectStructure[PRIVATE_KEY][key_]
    if not isIndexingLowLevelMembers and value ~= nil then
        error(`Class access violation; attempted to index private "{key_}".`)
    end
    return if type(value) == "table" and type(value.get) == "function" then (if mustGetRaw then value else value:get()) else nil
end

function FlareClassAPI:__newindex(key: any, value: any)
    local objectId = rawget(self, OBJECT_REFERENCE_KEY)
    local objectStructure = FlareClassObjects[objectId]
    local identifierCount = select(2, string.find(key:sub(1, 2), '_', 1))
    local isIndexingInternals = identifierCount ~= nil and identifierCount > 0
    local hasHighLevelAccess = if isIndexingInternals then FlareClassHelper.seekFunctionInTruthOrigin(objectId) else false
    local targetContainer = objectStructure[PUBLIC_KEY]
    if hasHighLevelAccess then
        targetContainer = if identifierCount ~= nil and identifierCount == 1 then objectStructure[PRIVATE_KEY] elseif identifierCount ~= nil and identifierCount == 2 then objectStructure[PROTECTED_KEY] else objectStructure[PUBLIC_KEY]
    elseif isIndexingInternals then
        error(`Class access violation; attempted to assign "{key}" from an outside source.`)
    end
    if targetContainer[key] ~= nil then
        targetContainer[key]:set(value)
    else
        local val = Value.new(value)
        targetContainer[key] = val
        if type(value) == "function" then
            val:lock()
            objectStructure[FN_REFERENCE_KEY][tostring(value)] = true
        elseif type(key) == "string" and string.match(string.gsub(key, '_', ''), "^%u+$") ~= nil then
            val:lock()
        end
    end
end

local function pasteTo(src: {}, dst: {}, fromSuper: boolean)
    for propKey, propValue in pairs(src) do
        if EXEMPTED_STATIC_FIELDS[propKey] or (fromSuper == true and dst[propKey] ~= nil) then continue end
        dst[propKey] = propValue
    end
end

local function makeFlareClass<T...>(superClass: {T}): T...
    local flareClass: {T} = {}
    flareClass.__index = flareClass
    setmetatable(flareClass, superClass)
    function flareClass.new<T...>(...: T...)
        local objectId = Hash.sha256(HttpService:GenerateGUID(false)) :: string
        local objectStructure = {}
        objectStructure[PUBLIC_KEY] = {}
        objectStructure[PRIVATE_KEY] = {}
        objectStructure[PROTECTED_KEY] = {}
        objectStructure[FRIEND_MARKER_KEY] = setmetatable({}, {__mode = 'k'})
        objectStructure[FN_REFERENCE_KEY] = setmetatable({[tostring(flareClass.new)] = true}, {__mode = 'k'})
        FlareClassObjects[objectId] = objectStructure
        
        local self = setmetatable({
            [OBJECT_REFERENCE_KEY] = objectId,
        }, flareClass)
        setmetatable(self, FlareClassAPI)
        pasteTo(flareClass, self)
        if type(superClass) == "table" then
            pasteTo(superClass, self, true)
        end

        if flareClass.FlareInit then
            flareClass.FlareInit(self, ...)
        end
        return self
    end

    function flareClass.extend()
        return makeFlareClass(flareClass)
    end

    function flareClass:_IS_INTERNALLY_CALLED(): boolean
        return FlareClassObjects[self[OBJECT_REFERENCE_KEY]][FN_REFERENCE_KEY][tostring(C.getStackInfo(2).closure)] ~= nil
    end

    function flareClass:_INTERNAL_CLEANUP()
        table.clear(FlareClassObjects[self[OBJECT_REFERENCE_KEY]])
        FlareClassObjects[self[OBJECT_REFERENCE_KEY]] = nil
        setmetatable(self, nil)
    end

    function flareClass:_BYPASS_ACCESS_IDENTIFIERS_FOR(method: (...any) -> (...any)): (...any) -> (...any)
        local objectStructure = FlareClassObjects[self[OBJECT_REFERENCE_KEY]]
        if objectStructure then
            objectStructure[FN_REFERENCE_KEY][tostring(method)] = true
        end
        return method
    end

    function flareClass:GetPropertyChangedSignal(propKey: any, boundFn: (...any) -> ()): Value.Connection
        return self[`{propKey}.raw`].Changed:Connect(boundFn)
    end
    
    function flareClass:FriendReference(reference: (...any) -> (...any) | typeof(setmetatable({}, {})))
        local objectStructure = FlareClassObjects[self[OBJECT_REFERENCE_KEY]]
        if objectStructure then
            local refType = type(reference)
            if refType == "table" then
                assert(getmetatable(reference) and getmetatable(reference)[OBJECT_REFERENCE_KEY] ~= nil, `Attempted to friend a static FlareClass interface`)
                local objId = reference[OBJECT_REFERENCE_KEY]
                for _, marker in pairs(reference) do
                    if type(marker) == "function" then
                        objectStructure[FRIEND_MARKER_KEY][tostring(marker)] = objId
                    end
                end
            elseif refType == "function" then
                objectStructure[FRIEND_MARKER_KEY][tostring(reference)] = true
            else
                error("Invalid reference; must either be a function or another FlareClass")
            end
        end
    end

    function flareClass:UnfriendReference(reference: (...any) -> (...any) | typeof(setmetatable({}, {})))
        local objectStructure = FlareClassObjects[self[OBJECT_REFERENCE_KEY]]
        if objectStructure then
            local refType = type(reference)
            if refType == "table" then
                assert(getmetatable(reference) and getmetatable(reference)[OBJECT_REFERENCE_KEY] ~= nil, `Attempted to unfriend a static FlareClass interface`)
                local objId = reference[OBJECT_REFERENCE_KEY]
                local friendsContainer = objectStructure[FRIEND_MARKER_KEY]
                local keysForValues = {}
                for marker, objectId in pairs(friendsContainer) do
                    if objectId == objId then
                        keysForValues[#keysForValues+1] = marker
                    end
                end
                for n = #keysForValues, 1, -1 do
                    friendsContainer[keysForValues[n]] = nil
                end
                keysForValues = nil
            elseif refType == "function" then
                objectStructure[FRIEND_MARKER_KEY][tostring(reference)] = nil
            end
        end
    end

    return flareClass
end

local BaseFlareClass = makeFlareClass()
return BaseFlareClass