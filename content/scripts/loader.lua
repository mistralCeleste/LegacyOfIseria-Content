--[[ Lua code. See documentation: https://api.tabletopsimulator.com/ --]]

-----------------------------------------
-- Configuration
-----------------------------------------

BASE_URL = "http://127.0.0.1:5500/"
--BASE_URL = "https://mistralCeleste.github.io/LegacyOfIseria-Content/"


function onLoad()
    Log.info("############### Loading content index ###############\n")
    local indexUrl = BASE_URL .. "content/index.json"
    JSONLoader.read(indexUrl)
end


LOADER =
{
    state = "Registering", -- Registering, Spawning, Bagging, Ready
    registering = { progress = 0, total = 0 },
    spawning = { progress = 0, total = 0 },
    bagging = { progress = 0, total = 0 },
    ready = false
}


JSONLoader = {}


local function loadComponent(path)
    local url = BASE_URL .. "content/" .. path

    WebRequest.get(url, function(request)
        if request.is_error then
            print("Error loading component: " .. path .. " | " .. request.error)
        else
            local root = JSON.decode(request.text)
            JsonAdapter.registerComponent(path, root)
        end

        LOADER.registering.progress = LOADER.registering.progress + 1
        checkRegisteringReady()
    end)
end


local function loadComponentJson(request)
    if request.is_error then
        print("Error: " .. request.error)
        return
    end

    local json = JSON.decode(request.text)
    LOADER.registering.progress = 0
    LOADER.registering.total = #json.components
    LOADER.state = "Registering"
    LOADER.ready = false

    for _, componentPath in ipairs(json.components) do
        loadComponent(componentPath)
    end
end


function JSONLoader.read(url)
    Log.debug("webrequest to: " .. url)
    WebRequest.get(url, loadComponentJson)
end


function checkRegisteringReady()
    print("Registering: " .. LOADER.registering.progress .. "/" .. LOADER.registering.total)
    if LOADER.registering.progress >= LOADER.registering.total then
        LOADER.ready = true
        print("All components registered.")
        onAllComponentsRegistered()
    end
end


function onAllComponentsRegistered()
    LOADER.state = "Spawning"
    LOADER.spawning.progress = 0
    JsonAdapter.spawnAllComponents()
end


local function computeBagDepth(bagId)
    local depth = 0
    local current = bagId

    while true do
        local entry = COMPONENT_REGISTRY[current]
        if not entry or not entry.bag then break end
        depth = depth + 1
        current = entry.bag
    end

    return depth
end


-- Safely insert an object into a bag (normal or Custom_Model_Bag)
local function putIntoBag(container, obj)
    print("put into bag: " .. container)
    if not container or not obj then
        print("putIntoBag: missing bag or object")
        return
    end

    local bagGUID = bag.getGUID()
    local objGUID = obj.getGUID()

    -- Wait until BOTH objects exist in the world
    Wait.condition(function()
        local realBag = getObjectFromGUID(bagGUID)
        local realObj = getObjectFromGUID(objGUID)

        if not realBag or not realObj then
            return  -- keep waiting
        end

        -- Unlock before insertion (TTS requirement)
        realObj.setLock(false)

        -- Insert into bag
        realBag.putObject(realObj)
        LOADER.bagging.progress = LOADER.bagging.progress + 1
        checkBaggingReady()

    end, function()
        return getObjectFromGUID(bagGUID) ~= nil
           and getObjectFromGUID(objGUID) ~= nil
    end)
end


-----------------------------------------
-- Framework
-----------------------------------------
Log =
{
    level = "DEBUG",
    levels = { ERROR = 1, WARN = 2, INFO = 3, DEBUG = 4 }
}

local function shouldLog(requested)
    return Log.levels[requested] <= Log.levels[Log.level]
end


function Log.error(msg)
    if shouldLog("ERROR") then print("[ERROR] " .. msg) end
end


function Log.warn(msg)
    if shouldLog("WARN") then print("[WARN] " .. msg) end
end


function Log.info(msg)
    if shouldLog("INFO") then print("[INFO] " .. msg) end
end


function Log.debug(msg)
    if shouldLog("DEBUG") then print("[DEBUG] " .. msg) end
end


Registry =
{
    _table = {}
    , _index = {}
}


function Registry.addComponent(component)
    Registry.add(component.Name, component.Nickname,  component)
    Log.debug("Registered " .. component.Name .. ": " .. component.Nickname .. "->" .. (component.container or "None"))
end


function Registry.getComponent(id)
    return Registry._index[id]
end


function Registry.getComponentByType(typeName, id)
    local bucket = Registry._table[typeName]
    return bucket and bucket[id] or nil
end

function Registry.getComponentsOfType(typeName)
    return Registry._table[typeName] or {}
end


function Registry.add(type, key, value)
    Log.debug("type: " .. type .. "; key: " .. key .. "; value: " .. tostring(value))
    
    if not Registry then
        Log.debug("registry is nil")
    end

    if not Registry._table then
        Log.debug("registry._table is nil")
    end

    if not Registry._table[type] then
        Log.debug("registry._table[type] is nil")
    end

    if not Registry._table[type] then
        Registry._table[type] = {}
    end
    Registry._table[type][key] = value
    Registry._index[key] = value
end


local function loadScript(scriptUrl, callback)
    if not scriptUrl then return end
    local scriptType = "Script"
    if Registry.add(scriptType, scriptUrl, nil) then
        callback(Registry.get(scriptType, scriptUrl))
        return
    end

    WebRequest.get
    (
        scriptUrl,
        function(request)
            if request.is_error then
                print("Error loading script: " .. scriptUrl)
                callback("")
                return
            end

            Registry.set(scriptType, scriptUrl, request.text)
            callback(request.text)
        end
    )
end


function Registry.addScript(basePath, script)
    if not script then return nil end
    local scriptUrl = resolvePath(basePath, script)
    loadScript(scriptUrl, function(_) end)
    return scriptUrl
end


function Registry.set(type, key, value)
    Registry.add(type, key, value)
end


function Registry.get(type, key)
    local bucket = Registry._table[type]
    if not bucket then return nil end
    return bucket[key]
end


function Registry.has(type, key)
    local bucket = Registry._table[type]
    return bucket and bucket[key] ~= nil
end


function Registry.each(type, delegate)
    local bucket = Registry._table[type]
    if not bucket then return end
    for key, data in pairs(bucket) do
        delegate(key, data)
    end
end


local function deepCopy(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = deepCopy(v)
    end
    return copy
end


local function deepMerge(base, override)
    for k, v in pairs(override) do
        if type(v) == "table" and type(base[k]) == "table" then
            deepMerge(base[k], v)
        else
            base[k] = v
        end
    end
    return base
end


local function mergeBlockAndSet(block, set)
    local merged = deepCopy(block)
    deepMerge(merged, set)
    return merged
end


TTS_ObjectData = {}

TTS_ObjectData.base =
{
    Name = nil,
    Nickname = nil,
    Description = "",
    GMNotes = "",
    Tags = {},
    Locked = false,
    Grid = true,
    Snap = true,
    Autoraise = true,
    Sticky = true,
    Tooltip = true,
    LuaScript = "",
    LuaScriptState = "",
    XmlUI = "",
    Transform = {
        posX = 0,
        posY = 3,
        posZ = 0,
        rotX = 0,
        rotY = 180,
        rotZ = 0,
        scaleX = 1,
        scaleY = 1,
        scaleZ = 1
    }
}


TTS_ObjectData.CardCustom =
{
    Name = "CardCustom",
    CustomDeck =
    {
        ["1"] =
        {
            Type = 0,
            NumWidth = 1,
            NumHeight = 1,
            BackIsHidden = false,
        }
    },
    SidewaysCard = false,
    CardID = 100
}


TTS_ObjectData.Custom_Model =
{
    Name = "Custom_Model",
    CustomMesh =
    {
        MeshURL = "",
        DiffuseURL = "",
        NormalURL = "",
        ColliderURL = "",
        Convex = true,
        MaterialIndex = -1,
        TypeIndex = 0,
        CastShadows = true
    }
}


TTS_ObjectData.Custom_Model_Bag =
{
    Name = "Custom_Model_Bag",
    CustomMesh =
    {
        MeshURL = "",
        DiffuseURL = "",
        NormalURL = "",
        ColliderURL = "",
        Convex = true,
        MaterialIndex = 3,
        TypeIndex = 6,
        CastShadows = true
    },
    Bag = { Order = 0 }
}


local function isRelativePath(path)
    return type(path) == "string"
       and not path:match("^https?://")
       and (path:match("%.png$") or path:match("%.jpg$") or path:match("%.jpeg$")
         or path:match("%.obj$") or path:match("%.mtl$"))
end


local function getParentFolder(path)
    return path:match("(.+)/[^/]+$") .. "/"
end


local function resolvePath(basePath, relative)
    relative = relative:gsub("\\", "/")
    basePath = basePath:gsub("\\", "/")
    local full = basePath .. relative

    local parts = {}
    for part in string.gmatch(full, "[^/]+") do
        if part == ".." then
            if #parts > 0 then
                table.remove(parts)
            end
        elseif part ~= "." and part ~= "" then
            table.insert(parts, part)
        end
    end

    local normalized = table.concat(parts, "/")
    return BASE_URL .. "content/" .. normalized
end


local function resolveAllPaths(basePath, entry)
    for key, value in pairs(entry) do
        if type(value) == "table" then
            resolveAllPaths(basePath, value)
        elseif isRelativePath(value) then
            entry[key] = resolvePath(basePath, value)
        end
    end
end


JsonAdapter = {}


function JsonAdapter.registerComponent(path, root)
    local basePath = getParentFolder(path)
    local name = root.name or path
    Log.debug("Registering component: " .. (name or path) .. " | base path: " .. basePath)

    for key, component in pairs(root.components) do
        Log.debug("  key: " .. key .. ": type: " .. tostring(component.type) .. " | " .. (#component.sets))
        JsonAdapter.registerComponentSet(basePath, component)
    end
end


function JsonAdapter.registerComponentSet(basePath, component)
    local template = deepCopy(TTS_ObjectData.base)
    deepMerge(template, TTS_ObjectData[component.block.Name])
    Log.debug("Template: " .. JSON.encode(template))

    for _, set in ipairs(component.sets) do
        local merged = mergeBlockAndSet(component.block, set)
        Log.debug("Block and set: " .. JSON.encode(merged))

        local entry = deepCopy(template)
        deepMerge(entry, merged)
        resolveAllPaths(basePath, entry)
        Log.debug("Final component: " .. JSON.encode(entry))

        Registry.addComponent(entry)
    end
end


function JsonAdapter.spawnComponent(entry)
    local obj = spawnObjectData( {data = entry })
    if not obj then
        Log.error("spawnComponent: failed to spawn " .. entry.identifier)
    else
        Log.info("spawnComponent: spawned " .. entry.identifier)
    end

    if entry.LuaScript and entry.LuaScript ~= "" then
        WebRequest.get(entry.LuaScript, function(req)
            if req.is_error then
               Log.info("Script load error for " .. entry.identifier .. ": " .. req.error)
                return
            end
            obj.setLuaScript(req.text)
        end)
    end

    return obj
end


function JsonAdapter.spawnById(id, position, rotation)
    local entry = Registry.getComponent(id)
    if not entry then
        Log.error("Unknown component id: " .. tostring(id))
    end
    return JsonAdapter.spawnComponent(entry)
end


function JsonAdapter.spawnAllComponents()
    for id, entry in pairs(Registry._index) do
        JsonAdapter.spawnComponent(entry)
    end
end


function JsonAdapter.spawnAllComponentsByType(typeName)
    local components = Registry.getComponentsOfType(typeName)

    if not next(components) then
        Log.error("No components of type " .. typeName .. " are registered.")
        return
    end

    for id, entry in pairs(components) do
        JsonAdapter.spawnComponent(entry)
    end
end



