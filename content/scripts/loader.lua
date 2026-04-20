
BASE_URL = "https://mistralCeleste.github.io/LegacyOfIseria-Content/"
COMPONENT_REGISTRY = COMPONENT_REGISTRY or {}
SCRIPT_CACHE = {}


LOADER = {
    total = 0,
    loaded = 0,
    ready = false
}


function onLoad()
    print("Loading content index...")
    loadIndex()
end


function loadIndex()
    local url = BASE_URL .. "content/index.json"

    WebRequest.get(url, function(req)
        if req.is_error then
            print("Error loading index.json: " .. req.error)
            return
        end

        local index = JSON.decode(req.text)

        LOADER.total = #index.components
        LOADER.loaded = 0
        LOADER.ready = false

        for _, componentPath in ipairs(index.components) do
            loadComponent(componentPath)
        end
    end)
end


function loadComponent(path)
    local url = BASE_URL .. "content/" .. path

    WebRequest.get(url, function(req)
        if req.is_error then
            print("Error loading component: " .. path .. " | " .. req.error)
        else
            local component = JSON.decode(req.text)
            registerComponent(component, path)
        end

        LOADER.loaded = LOADER.loaded + 1
        checkLoaderReady()
    end)
end


function checkLoaderReady()
    if LOADER.loaded >= LOADER.total then
        LOADER.ready = true
        print("All components loaded.")

        onAllComponentsLoaded()
    end
end


function onAllComponentsLoaded()
    -- Example: spawn Days
    spawnComponent("Days", {x=0, y=3, z=0})

    -- Or spawn everything
    -- for name, _ in pairs(COMPONENT_REGISTRY) do
    --     spawnComponent(name, {x=0, y=3, z=0})
    -- end
end


function registerComponent(component, componentPath)
    -- Extract folder path: "components/days/days.json" → "components/days/"
    local basePath = componentPath:match("(.+)/[^/]+$") .. "/"

    -- Create registry entry for this component
    local componentName = component.name or componentPath
    COMPONENT_REGISTRY[componentName] = COMPONENT_REGISTRY[componentName] or {
        cards = {},
        models = {},
        tiles = {},
        assetbundles = {}
    }

    local registry = COMPONENT_REGISTRY[componentName]

    -- Register each object type
    if component.cards then
        registerCardSet(basePath, component.cards, registry.cards)
    end

    if component.models then
        --registerModelSet(basePath, component.models, registry.models)
    end

    if component.tiles then
        registerTileSet(basePath, component.tiles, registry.tiles)
    end

    if component.assetbundles then
        --registerAssetBundleSet(basePath, component.assetbundles, registry.assetbundles)
    end

    print("Registered component: " .. componentName)
end


function registerCardSet(basePath, cardBlock, cardList)
    local cardType  = cardBlock.type or "CustomCard"
    local shape     = tonumber(cardBlock.shape) or 0
    local scale     = cardBlock.scale or {x=1, y=1, z=1}

    local scriptURL = nil
    if cardBlock.script then
        scriptURL = resolvePath(basePath, cardBlock.script)
        if scriptURL and not SCRIPT_CACHE[scriptURL] then
            loadScript(scriptURL, function(_) end)
        end
    end

    for _, card in ipairs(cardBlock.sets) do
        local entry = {
            id = card.identifier,
            name = card.name or card.identifier,
            type = cardType,
            shape = shape,
            scale = scale,
            sideways = card.sideways or false,
            tags = card.tags or {},
            face = resolvePath(basePath, card.face),
            back = resolvePath(basePath, card.back),
            script = scriptURL
        }

        table.insert(cardList, entry)
        print("Registered card: " .. entry.id)
    end
end


function resolvePath(basePath, relative)
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


function buildCardJSON(entry, position)
    local deckIndex = 1  -- each card is its own deck

    local obj = {
        Name = "Card",
        Nickname = entry.name,
        Description = "",
        GMNotes = "",
        Tags = entry.tags or {},

        Transform = {
            posX = position.x,
            posY = position.y,
            posZ = position.z,
            rotX = 0,
            rotY = 180,
            rotZ = 0,
            scaleX = entry.scale.x,
            scaleY = entry.scale.y,
            scaleZ = entry.scale.z
        },

        CustomDeck = {
            [deckIndex] = {
                FaceURL = entry.face,
                BackURL = entry.back,
                NumWidth = 1,
                NumHeight = 1,
                BackIsHidden = false,
                SidewaysCard = entry.sideways or false
            }
        },

        CardID = deckIndex * 100,

        -- Script injected after spawn
        LuaScript = "",
        LuaScriptState = ""
    }

    return JSON.encode(obj)
end


function spawnCard(entry, position)
    local json = buildCardJSON(entry, position)

    local obj = spawnObjectJSON(json)
    if not obj then
        print("Failed to spawn card: " .. entry.id)
        return
    end

    if entry.script then
        loadScript(entry.script, function(scriptText)
            obj.setLuaScript(scriptText)
        end)
    end

    return obj
end


function loadScript(scriptURL, callback)
    if SCRIPT_CACHE[scriptURL] then
        callback(SCRIPT_CACHE[scriptURL])
        return
    end

    WebRequest.get(scriptURL, function(req)
        if req.is_error then
            print("Error loading script: " .. scriptURL)
            callback("")
            return
        end

        SCRIPT_CACHE[scriptURL] = req.text
        callback(req.text)
    end)
end


function spawnComponent(componentName, position)
    local comp = COMPONENT_REGISTRY[componentName]

    if not comp then
        print("Unknown component: " .. componentName)
        return
    end

    -- Spawn cards
    if comp.cards and #comp.cards > 0 then
        spawnComponentCards(componentName, position)
    end

    -- Spawn models (future)
    if comp.models and #comp.models > 0 then
        --spawnComponentModels(componentName, position)
    end

    -- Spawn assetbundles (future)
    if comp.assetbundles and #comp.assetbundles > 0 then
        --spawnComponentBundles(componentName, position)
    end

    -- Spawn tiles (future)
    if comp.tiles and #comp.tiles > 0 then
        spawnComponentTiles(componentName, position)
    end

end


function spawnComponentCards(componentName, position)
    local comp = COMPONENT_REGISTRY[componentName]

    if not comp or not comp.cards then
        return
    end

    local pilePos = {
        x = position.x,
        y = position.y,
        z = position.z
    }

    for _, entry in ipairs(comp.cards) do
        spawnCard(entry, pilePos)
    end
end

function registerTileSet(basePath, tileBlock, tileList)
    local scale = tileBlock.scale or {x=1, y=1, z=1}

    local scriptURL = nil
    if tileBlock.script then
        scriptURL = resolvePath(basePath, tileBlock.script)
        if scriptURL and not SCRIPT_CACHE[scriptURL] then
            loadScript(scriptURL, function(_) end)
        end
    end

    for _, tile in ipairs(tileBlock.sets) do
        local entry = {
            id = tile.identifier,
            name = tile.name or tile.identifier,
            scale = scale,
            tags = tile.tags or {},
            face = resolvePath(basePath, tile.face),
            back = resolvePath(basePath, tile.back),
            script = scriptURL
        }

        table.insert(tileList, entry)
        print("Registered tile: " .. entry.id)
    end
end

function buildTileJSON(entry, position)
    return {
        Name = "Custom_Tile",

        Transform = {
            posX = position.x,
            posY = position.y,
            posZ = position.z,
            rotX = 0,
            rotY = 0,
            rotZ = 0,
            scaleX = entry.scale.x,
            scaleY = entry.scale.y,
            scaleZ = entry.scale.z
        },

        Nickname = entry.name,
        Description = "",
        GMNotes = "",
        Tags = entry.tags or {},

        CustomImage = {
            ImageURL = entry.face,
            ImageSecondaryURL = entry.back,
            Width = 1,
            Height = 1,
            Type = 0,        -- 0 = square tile
            Thickness = 0.1,
            Stackable = true
        },

        LuaScript = "",
        LuaScriptState = ""
    }
end

function spawnTile(entry, position)
    print("spawn tile: " .. entry.id)

    local objData = buildTileJSON(entry, position)
    local obj = spawnObjectData({data = objData})

    if not obj then
        print("Failed to spawn tile: " .. entry.id)
        return
    end

    -- Capture GUID immediately
    local guid = obj.getGUID()

    if entry.script then
        loadScript(entry.script, function(scriptText)
            print("add script to tile: " .. entry.id)

            Wait.condition(function()
                local realObj = getObjectFromGUID(guid)
                if realObj then
                    print("assigning script to tile: " .. entry.id)
                    realObj.setLuaScript(scriptText)
                else
                    print("tile vanished: " .. entry.id)
                end
            end, function()
                return getObjectFromGUID(guid) ~= nil
            end)
        end)
    end

    return obj
end

function spawnComponentTiles(componentName, position)
    local comp = COMPONENT_REGISTRY[componentName]
    if not comp or not comp.tiles then return end

    local pilePos = {
        x = position.x,
        y = position.y,
        z = position.z
    }

    for _, entry in ipairs(comp.tiles) do
        spawnTile(entry, pilePos)
    end
end

