--[[ Lua code. See documentation: https://api.tabletopsimulator.com/ --]]

-----------------------------------------
-- Configuration
-----------------------------------------

BASE_URL = "http://127.0.0.1:5500/"
--BASE_URL = "https://mistralCeleste.github.io/LegacyOfIseria-Content/"


-----------------------------------------
-- Event Handlers
-----------------------------------------

function onLoad()
    Log.info("############### Loading content index ###############\n")
    local indexUrl = BASE_URL .. "content/index.json"
    JSONLoader.read(indexUrl)
end


function fetchAndPrint(url)
    WebRequest.get(url, function(request)
        if request.is_error then
            Log.error("WebRequest error: " .. request.error)
            return
        end

        Log.debug("Response from " .. url .. ": " .. request.text)
    end)
end


-----------------------------------------
-- Dungeon Tracking
-----------------------------------------

DUNGEON_BAG_NAME = "dungeon bag"


function registerDungeonObject(params)
    local object = params.object
    local origin = params.origin or nil
    local guid = object.getGUID()
    object.setVar(DUNGEON_BAG_NAME,  origin)
    print("register dungeon object: " .. guid .. " from " .. origin .. " to bag " .. DUNGEON_BAG_NAME)
end


function unregisterDungeonObject(object)
    if object.getVar(DUNGEON_BAG_NAME) then
        object.setVar(DUNGEON_BAG_NAME, nil)
        print("unregister dungeon object: " .. object.getGUID())
    end
end


function cleanupDungeon()
    print("cleanup dungeon")

    for _, object in ipairs(getAllObjects()) do
        removeDungeonObject(object)
    end
end


function removeDungeonObject(object)
    print("remove object: " .. object.getGUID())
    local origin = object.getVar(DUNGEON_BAG_NAME)

    if origin then
        -- Real dungeon item → return to bag
        local bag = getObjectFromGUID(origin)
        if bag then
            bag.putObject(object)
            print("put in bag: ", object.getGUID(), origin)
        end
    else
        -- Clone or manually spawned → delete
        --destroyObject(object)
        print("delete", object.getGUID())
    end
end


--- ##############################################################################
--- Content Loader
--- ##############################################################################


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


local function hasScript(path)
    return type(path) == "string" and path:match("%S") ~= nil
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


function checkBaggingReady()
    Log.debug("Bagging: " .. LOADER.bagging.progress .. "/" .. LOADER.bagging.total)

    if LOADER.bagging.progress >= LOADER.bagging.total then
        Log.info("Everything is inserted into bags.")
        onBaggingComplete()
    end
end


local function unlockAllBags()
    local bags = Registry.getComponentsOfType("Custom_Model_Bag")
    for id, entry in pairs(bags) do
        local bagObj = getObjectFromGUID(entry.guid)
        if bagObj then
            Log.debug("Unlocking bag: " .. id)
            bagObj.setLock(false)
        else
            Log.warn("Bag not found for id: " .. id)
        end
    end
end


function onBaggingComplete()
    LOADER.state = "Ready"
    LOADER.ready = true

    unlockAllBags()
    Log.info("############### Loader READY ###############")
end


local function findRealCardObject(identifier)
    for _, o in ipairs(getAllObjects()) do
        if o.getName() == identifier then
            return o
        end
    end
    return nil
end


local function queueBagInsertion(bagId, entry)
    Log.debug("start queueBagInsertion")
    local identifier = entry.identifier
    local attempts = 0
    local MAX_ATTEMPTS = 10

    Wait.condition(
        function()
            attempts = attempts + 1
            Log.debug("attempts: " .. attempts .. "/" .. MAX_ATTEMPTS)

            -- Hard fail after too many attempts
            if attempts > MAX_ATTEMPTS then
                Log.error("Bag insertion FAILED for " .. identifier .. " after " .. MAX_ATTEMPTS .. " attempts.")
                LOADER.bagging.progress = LOADER.bagging.progress + 1
                checkBaggingReady()
                return true   -- <‑‑ stops the callback permanently
            end

            local bag = Registry.getComponent(bagId)
            local bagObj = bag and getObjectFromGUID(bag.guid)
            local cardObj = findRealCardObject(identifier)
            local BAG_UNLOCK_DELAY = 2

            if bagObj and cardObj then
                Log.debug("Inserting " .. identifier .. " into " .. bagId)
                cardObj.setLock(false)

                -- Wait a frame or two so physics settles
                Wait.frames(function()
                    -- Double-check objects still exist
                    local b = getObjectFromGUID(bagObj.getGUID())
                    local c = getObjectFromGUID(cardObj.getGUID())

                    if not b or not c then
                        Log.warn("Bagging failed after unlock delay for " .. identifier)
                        return
                    end

                    b.putObject(c)
                    LOADER.bagging.progress = LOADER.bagging.progress + 1
                    checkBaggingReady()

                    Log.debug("Bagging complete for " .. identifier)
                end, BAG_UNLOCK_DELAY)
                return true
            end

            return false  -- <‑‑ keep waiting for item to exist
        end,

        function()
            -- Condition: bag exists OR we hit timeout
            local bag = Registry.getComponent(bagId)
            local bagObj = bag and getObjectFromGUID(bag.guid)
            local cardObj = findRealCardObject(identifier)
            return bagObj ~= nil and cardObj ~= nil
        end
    )
end


-----------------------------------------
-- Logger
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


local function deepCopy(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = deepCopy(v)
    end
    return copy
end


-----------------------------------------
-- Registry
-----------------------------------------

Registry =
{
    _types = {}
    , _keys = {}
    , _scripts = {}
}

-- Can be called from other scripts to get data from the Registry
-- you will need to JSON.decode(entry) on the caller-side
function getRegistryComponentJSON(id)
    local entry = Registry.getComponent(id)
    if entry then
        return JSON.encode(entry)
    end
    return nil
end


function getRegistryComponentGUID(id)
    local entry = Registry.getComponent(id)
    if entry then
        return entry.getGUID()
    end
    return nil
end


function getRegistry()
    return Registry
end


function Registry.addComponent(component)
    Registry.addItem(component.Name, component.Nickname,  component)
    Log.debug("Registered " .. component.Name .. ": " .. component.Nickname .. "->" .. (component.bag or "None"))
end


function Registry.getComponent(id)
    return Registry._keys[id]
end


function Registry.getComponentByType(typeName, id)
    local bucket = Registry._types[typeName]
    return bucket and bucket[id] or nil
end


function Registry.getComponentsOfType(typeName)
    return Registry._types[typeName] or {}
end


function Registry.addItem(type, key, value)
    if not Registry._types[type] then
        Registry._types[type] = {}
    end
    Registry._types[type][key] = value
    Registry._keys[key] = value
end


function Registry.addScript(scriptUrl)
    if not hasScript(scriptUrl) then return "" end

    if Registry._scripts[scriptUrl] == nil then
        Registry._scripts[scriptUrl] = false
    end

    return scriptUrl
end


function Registry.getScript(url)
    return Registry._scripts[url]
end


function allScriptsLoaded()
    for _, text in pairs(Registry._scripts) do
        if text == false then return false end
    end
    return true
end


function Registry.setItem(type, key, value)
    Registry.addItem(type, key, value)
end


function Registry.getItem(type, key)
    local bucket = Registry._types[type]
    if not bucket then return nil end
    return bucket[key]
end


function Registry.hasItem(type, key)
    local bucket = Registry._types[type]
    return bucket and bucket[key] ~= nil
end


function Registry.eachItem(type, delegate)
    local bucket = Registry._types[type]
    if not bucket then return end
    for key, data in pairs(bucket) do
        delegate(key, data)
    end
end


-----------------------------------------
-- TTS Objects
-----------------------------------------


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


local function mergeSetAndItem(block, set)
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
            FaceURL = "",
            BackURL = ""
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


local AliasMap = {
    CardCustom = {
        face = { path = {"CustomDeck", "1", "FaceURL"} },
        back = { path = {"CustomDeck", "1", "BackURL"} }
    },

    DeckCustom = {
        face = { path = {"CustomDeck", "1", "FaceURL"} },
        back = { path = {"CustomDeck", "1", "BackURL"} }
    },

    Tile = {
        image = { path = {"CustomImage", "ImageURL"} }
    },

    Custom_Tile = {
        face = { path = {"CustomImage", "ImageURL"} },
        back = { path = {"CustomImage", "ImageSecondaryURL"} }
    },

    Token = {
        image = { path = {"CustomImage", "ImageURL"} }
    },

    Board = {
        image = { path = {"CustomImage", "ImageURL"} }
    },

    Figurine = {
        image = { path = {"CustomImage", "ImageURL"} }
    },

    Model = {
        texture = { path = {"CustomMesh", "DiffuseURL"} },
        normal = { path = {"CustomMesh", "NormalURL"} },
        mesh = { path = {"CustomMesh", "MeshURL"} },
        collider = { path = {"CustomMesh", "ColliderURL"} },
    },

    Custom_Model = {
        texture = { path = {"CustomMesh", "DiffuseURL"} },
        normal = { path = {"CustomMesh", "NormalURL"} },
        mesh = { path = {"CustomMesh", "MeshURL"} },
        collider = { path = {"CustomMesh", "ColliderURL"} },
        typeIndex = { path = {"CustomMesh", "TypeIndex"} },
    },

    Custom_Model_Bag = {
        texture = { path = {"CustomMesh", "DiffuseURL"} },
        normal = { path = {"CustomMesh", "NormalURL"} },
        mesh = { path = {"CustomMesh", "MeshURL"} },
        collider = { path = {"CustomMesh", "ColliderURL"} },
    },

    Dice = {
        image = { path = {"CustomImage", "ImageURL"} }
    }
}


local NamedColors = {
    White  = {1.00, 1.00, 1.00},
    Brown  = {0.59, 0.29, 0.00},
    Red    = {1.00, 0.00, 0.00},
    Orange = {1.00, 0.50, 0.00},
    Yellow = {1.00, 1.00, 0.00},
    Green  = {0.00, 1.00, 0.00},
    Teal   = {0.00, 0.50, 0.50},
    Blue   = {0.00, 0.00, 1.00},
    Purple = {0.50, 0.00, 0.50},
    Pink   = {1.00, 0.41, 0.71},
    Grey   = {0.50, 0.50, 0.50},
    Black  = {0.00, 0.00, 0.00}
}


local function hexToRGBA(hex)
    hex = hex:gsub("#", "")

    local r, g, b, a

    if #hex == 6 then
        r = tonumber(hex:sub(1,2), 16)
        g = tonumber(hex:sub(3,4), 16)
        b = tonumber(hex:sub(5,6), 16)
        a = 255
    elseif #hex == 8 then
        r = tonumber(hex:sub(1,2), 16)
        g = tonumber(hex:sub(3,4), 16)
        b = tonumber(hex:sub(5,6), 16)
        a = tonumber(hex:sub(7,8), 16)
    else
        return nil
    end

    return {
        r = r / 255,
        g = g / 255,
        b = b / 255,
        a = a / 255
    }
end


local function parseColor(value)
    if type(value) == "table" then
        -- Already a color table
        return {
            r = value.r or value[1] or 1,
            g = value.g or value[2] or 1,
            b = value.b or value[3] or 1,
            a = value.a or value[4] or 1
        }
    end

    if type(value) ~= "string" then
        return nil
    end

    -- Named color
    local named = NamedColors[value]
    if named then
        return {
            r = named[1],
            g = named[2],
            b = named[3],
            a = 1
        }
    end

    -- Hex color
    if value:match("^#?%x%x%x%x%x%x$") or value:match("^#?%x%x%x%x%x%x%x%x$") then
        return hexToRGBA(value)
    end

    return nil
end


local function setPath(root, path, value)
    local t = root
    for i = 1, #path - 1 do
        local key = path[i]
        t[key] = t[key] or {}
        t = t[key]
    end
    t[path[#path]] = value
end


-----------------------------------------
-- Json Adapters
-----------------------------------------


local function expandColorAliases(entry)
        -- color → ColorDiffuse
    if entry.color then
        local rgba = parseColor(entry.color)
        if rgba then
            entry.ColorDiffuse = rgba
        end
        entry.color = nil
    end
end


local function expandTransformAliases(entry)
    -- position → Transform    
    if entry.position then
        entry.Transform = entry.Transform or {}
        entry.Transform.posX = entry.position.x or entry.Transform.posX
        entry.Transform.posY = entry.position.y or entry.Transform.posY
        entry.Transform.posZ = entry.position.z or entry.Transform.posZ
        entry.position = nil
    end

    if entry.scale then
        entry.Transform.scaleX = entry.scale.x or entry.Transform.scaleX
        entry.Transform.scaleY = entry.scale.y or entry.Transform.scaleY
        entry.Transform.scaleZ = entry.scale.z or entry.Transform.scaleZ
        entry.scale = nil
    end

    if entry.rotation then
        entry.Transform.rotX = entry.rotation.x or entry.Transform.rotX
        entry.Transform.rotY = entry.rotation.y or entry.Transform.rotY
        entry.Transform.rotZ = entry.rotation.z or entry.Transform.rotZ
        entry.rotation = nil
    end
end


local function expandSnapPointAliases(entry)
     -- Expand snappoints aliases into TTS snap point format
    if type(entry.snappoints) == "table" and entry.snappoints.cols then
        local sp = entry.snappoints
        local cols = sp.cols
        local rows = sp.rows
        local gridX = sp.gridX or 0.1
        local gridZ = sp.gridZ or 0.1
        local offsetX = sp.offsetX or 0
        local offsetZ = sp.offsetZ or 0
        local y = sp.y or 0.1

        entry.SnapPoints = {}

        -- Compute starting positions so grid is centered
        local startX = offsetX - ((cols - 1) * gridX) / 2
        local startZ = offsetZ - ((rows - 1) * gridZ) / 2

        for rowIndex = 0, rows - 1 do
            for colIndex = 0, cols - 1 do
                table.insert(entry.SnapPoints, {
                    position = {
                        x = startX + colIndex * gridX,
                        y = y,
                        z = startZ + rowIndex * gridZ
                    },
                    rotation = { x = 0, y = 0, z = 0 },
                    rotation_snap = false
                })
            end
        end

        entry.snappoints = nil -- remove alias
    end
end


local function expandAliases(entry)
    local typeName = entry.Name
    local map = AliasMap[typeName]

    if map then
        for alias, info in pairs(map) do
            if entry[alias] then
                setPath(entry, info.path, entry[alias])
                entry[alias] = nil
            end
        end
    end

    -- identifier → Nickname
    if entry.identifier then
        entry.Nickname = entry.identifier
    end

    expandColorAliases(entry)
    expandTransformAliases(entry)
    expandSnapPointAliases(entry)
end


JsonAdapter = {}


local function loadIncludeSync(path)
    local url = BASE_URL .. "content/" .. path
    local req = WebRequest.getSync(url)
    if req.is_error then
        Log.error("Include load error: " .. path .. " | " .. req.error)
        return { components = {} }
    end
    return JSON.decode(req.text)
end


local function expandIncludesAsync(components, basePath, callback)
    local result = {}
    local pending = 0

    local function add(c)
        table.insert(result, c)
    end

    local function process(entry)
        if entry.include then
            pending = pending + 1
            local includePath = basePath .. entry.include
            local url = BASE_URL .. "content/" .. includePath

            WebRequest.get(url, function(req)
                if not req.is_error then
                    local data = JSON.decode(req.text)
                    expandIncludesAsync(data.components or {}, basePath, function(sub)
                        for _, c in ipairs(sub) do add(c) end
                        pending = pending - 1
                        if pending == 0 then callback(result) end
                    end)
                else
                    Log.error("Include load error: " .. includePath)
                    pending = pending - 1
                    if pending == 0 then callback(result) end
                end
            end)
        else
            add(entry)
        end
    end

    for _, entry in ipairs(components) do
        process(entry)
    end

    if pending == 0 then
        callback(result)
    end
end


function JsonAdapter.registerComponent(path, root)
    local basePath = getParentFolder(path)

    expandIncludesAsync(root.components, basePath, function(expanded)
        for _, component in ipairs(expanded) do
            JsonAdapter.registerComponentSet(basePath, component)
        end

        for url, state in pairs(Registry._scripts) do
            if state == false then
                WebRequest.get(url, function(req)
                    if not req.is_error then
                        Registry._scripts[url] = req.text
                    else
                        Registry._scripts[url] = ""
                        Log.error("Script load error: " .. url)
                    end
                end)
            end
        end

        Wait.condition(
            function()
                LOADER.registering.progress = LOADER.registering.progress + 1
                checkRegisteringReady()
            end,
            function()
                for _, text in pairs(Registry._scripts) do
                    if text == false then return false end
                end
                return true
            end
        )
    end)
end


function JsonAdapter.registerComponentSet(basePath, component)
    if not component.set then
        Log.error("registerComponentSet: missing 'set' field: " .. JSON.encode(component))
        return
    end

    if not component.set.Name then
        Log.error("registerComponentSet: missing set.Name: " .. JSON.encode(component))
        return
    end

    if not component.items then
        Log.error("registerComponentSet: missing 'items' array: " .. JSON.encode(component))
        return
    end

    local componentType = component.set.Name
    local template = deepCopy(TTS_ObjectData.base)
    deepMerge(template, TTS_ObjectData[componentType] or {})

    local spawnOffset = component.spawnOffset or nil
    local dx = spawnOffset and (spawnOffset.dx or 0) or 0
    local dy = spawnOffset and (spawnOffset.dy or 0) or 0
    local dz = spawnOffset and (spawnOffset.dz or 0) or 0

    for index, item in ipairs(component.items) do
        local merged = mergeSetAndItem(component.set, item)
        local entry = deepCopy(template)
        deepMerge(entry, merged)
        resolveAllPaths(basePath, entry)
        expandAliases(entry)

        if spawnOffset then
            local count = index - 1
            entry.Transform.posX = entry.Transform.posX + dx * count
            entry.Transform.posY = entry.Transform.posY + dy * count
            entry.Transform.posZ = entry.Transform.posZ + dz * count
        end

        if entry.script then
            entry.script = resolvePath(basePath, entry.script)
            Registry.addScript(entry.script)
        end

        Registry.addComponent(entry)
    end
end


function JsonAdapter.spawnComponent(entry)
    local obj = spawnObjectData({
        data = entry,
        callback_function = function(obj)
            if entry.bag then
                queueBagInsertion(entry.bag, entry)
            end
        end
    })

    if not obj then
        Log.error("spawnComponent: failed to spawn " .. tostring(entry.identifier))
        return nil
    end

    obj.setLock(true)
    entry.guid = obj.getGUID()

    if hasScript(entry.script) then
        local scriptText = Registry.getScript(entry.script)
        if scriptText then
            obj.setLuaScript(scriptText)
        end
    end

    if entry.SnapPoints then
        obj.setSnapPoints(entry.SnapPoints)
    end

    Registry.addComponent(entry)

    Log.debug("Spawned " .. tostring(entry.identifier) .. " with GUID " .. tostring(entry.guid))
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
    -- Spawn bags first
    for id, entry in pairs(Registry._keys) do
        if entry.Name == "Custom_Model_Bag" or entry.Bag then
            JsonAdapter.spawnComponent(entry)
        end
    end

    -- Spawn everything else
    for id, entry in pairs(Registry._keys) do
        if entry.Name ~= "Custom_Model_Bag" and not entry.Bag then
            JsonAdapter.spawnComponent(entry)
        end
    end
end


