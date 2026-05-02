--[[ Lua code. See documentation: https://api.tabletopsimulator.com/ --]]

-----------------------------------------
-- Configuration
-----------------------------------------

BASE_URL = "http://127.0.0.1:5500/"
--BASE_URL = "https://mistralCeleste.github.io/LegacyOfIseria-Content/"
COMPONENT_REGISTRY = COMPONENT_REGISTRY or {}
SCRIPT_CACHE = {}

LOADER =
{
    state = "Registering", -- Registering, Spawning, Bagging, Ready
    registering = { progress = 0, total = 0 },
    spawning = { progress = 0, total = 0 },
    bagging = { progress = 0, total = 0 },
    ready = false
}


BAG_QUEUE = {}

function BAG_QUEUE.registerBag(bagId, itemId)
    if not bagId then
        error("BAG_QUEUE.registerBag: missing bagId")
    end
    table.insert(BAG_QUEUE, { itemId = itemId, bagId = entry.bag })
end

function BAG_QUEUE.getBag(bagId)
    return BAG_QUEUE[bagId]
end


SPAWNERS = {
    cards = spawnCard,
    tiles = spawnTile,
    models = spawnModel,
    assetbundles = spawnAssetBundle,
    tokens = spawnToken,
    figurines = spawnFigurine,
    dice = spawnDice,
    decks = spawnDeck,
    boards = spawnBoard,
    blocks = spawnBlock,
    bags = spawnBag
}

ComponentType =
{
    AssetBundle = "Custom_Assetbundle"
  , CustomCard = "CardCustom"
  , CustomDeck = "DeckCustom"
  , CustomTile = "Custom_Tile"
  , CustomModel = "Custom_Model"
  , CustomToken = "Custom_Token"
  , CustomFigurine = "Custom_Figurine"
  , Dice = "Custom_Dice"
  , CustomBoard = "Custom_Board"
  , Block = "Blocks"
  , Bag = "Bag"
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

        LOADER.registering.progress = 0
        LOADER.registering.total = #index.components
        LOADER.state = "Registering"
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

        LOADER.registering.progress = LOADER.registering.progress + 1
        checkRegisteringReady()
    end)
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

    for name, _ in pairs(COMPONENT_REGISTRY) do
        spawnComponent(name, {x=0, y=3, z=0})
    end
end


function checkSpawningReady()
    print("Spawning: " .. LOADER.spawning.progress .. "/" .. LOADER.spawning.total)
    if LOADER.spawning.progress >= LOADER.spawning.total then
        LOADER.ready = true
        print("All components spawned.")
        onAllComponentsSpawned()
    end
end


function onAllComponentsSpawned()
    LOADER.state = "Bagging"
    LOADER.bagging.progress = 0
    LOADER.bagging.total = #BAG_QUEUE
    processBagQueue()
end


function computeBagDepth(bagId)
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


function processBagQueue()
    table.sort(BAG_QUEUE, function(a, b)
      return computeBagDepth(a.bagId) < computeBagDepth(b.bagId)
    end)

    for _, pair in ipairs(LOADER.bagQueue) do
        local item = COMPONENT_REGISTRY[pair.itemId].object
        local bag  = COMPONENT_REGISTRY[pair.bagId].object

        if item and bag then
            putIntoBag(bag, item)
        else
            print("Bagging failed for:", pair.itemId, "→", pair.bagId)
        end
    end
end


function checkBaggingReady()
    print("Bagging: " .. LOADER.bagging.progress .. "/" .. LOADER.bagging.total)
    if LOADER.bagging.progress >= LOADER.bagging.total then
        LOADER.ready = true
        print("All components bagged.")
        onAllComponentsBagged()
    end
end


function onAllComponentsBagged()
    LOADER.state = "Ready"
    print("All bagging complete. Game Loaded.")
end


-- Extract folder path: "components/days/days.json" → "components/days/"
function getParentFolder(path)
    return path:match("(.+)/[^/]+$") .. "/"
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


function registerComponent(component, componentPath)
    local basePath = getParentFolder(componentPath)
    print("Registering component: " .. (component.name or componentPath) .. " | base path: " .. basePath)

    local componentName = component.name or componentPath
    COMPONENT_REGISTRY[componentName] = COMPONENT_REGISTRY[componentName] or {
        cards = {},
        models = {},
        tiles = {},
        assetbundles = {}
    }

    local registry = COMPONENT_REGISTRY[componentName]

    for key, value in pairs(component.components) do
        LOADER.spawning.total = LOADER.spawning.total + 1
        print("  key: " .. key .. ": type: " .. tostring(value.type) .. " | " .. (#value.sets))

        if value.type == ComponentType.AssetBundle then
            registerAssetBundleSet(basePath, component.assetbundles, registry.assetbundles)
        end

        if value.type == ComponentType.Bag then
            registerBagSet(basePath, component.bags, registry.bags)
        end

        if value.type == ComponentType.Block then
            registerBlockSet(basePath, component.blocks, registry.blocks)
        end

        if value.type == ComponentType.CustomBoard then
            registerBoardSet(basePath, component.boards, registry.boards)
        end

        if value.type == ComponentType.CustomCard then
            registerCardSet(basePath, value, registry.cards)
        end

        if value.type == ComponentType.CustomDeck then
            registerDeckSet(basePath, component.decks, registry.decks)
        end

        if value.type == ComponentType.Dice then
            registerDiceSet(basePath, component.dice, registry.dice)
        end

        if value.type == ComponentType.CustomFigurine then
            registerFigurineSet(basePath, component.figurines, registry.figurines)
        end

        if value.type == ComponentType.CustomModel then
            registerModelSet(basePath, value, registry.models)
        end

        if value.type == ComponentType.CustomTile then
            registerTileSet(basePath, component.tiles, registry.tiles)
        end

        if value.type == ComponentType.CustomToken then
            registerTokenSet(basePath, component.tokens, registry.tokens)
        end

    end

    print("Registered component: " .. componentName)
end


function spawnComponent(componentName, position)
    local comp = COMPONENT_REGISTRY[componentName]
    print("Spawning component: " .. componentName)

    if not comp then
        print("Unknown component: " .. componentName)
        return
    end

    -- Auto-bagging
    if comp.bag then
        local bagObj = spawnComponentBag(componentName, position)
        if bagObj then
            spawnComponentBagContents(componentName, bagObj)
        end
        return
    end

    if comp.assetbundles and #comp.assetbundles > 0 then
        spawnComponentAssetBundles(componentName, position)
    end

    if comp.bags and #comp.bags > 0 then
        spawnComponentBags(componentName, position)
    end

    if comp.blocks and #comp.blocks > 0 then
        spawnComponentBlocks(componentName, position)
    end

    if comp.boards and #comp.boards > 0 then
        spawnComponentBoards(componentName, position)
    end

    print("Component has cards: " .. tostring(comp.cards ~= nil and #comp.cards or 0))
    if comp.cards and #comp.cards > 0 then
        spawnComponentCards(componentName, position)
    end

    if comp.decks and #comp.decks > 0 then
        spawnComponentDecks(componentName, position)
    end

    if comp.dice and #comp.dice > 0 then
        spawnComponentDice(componentName, position)
    end

    if comp.figurines and #comp.figurines then
        spawnComponentFigurines(componentName, position)
    end

    if comp.tiles and #comp.tiles > 0 then
        spawnComponentTiles(componentName, position)
    end

    if comp.models and #comp.models > 0 then
        spawnComponentModels(componentName, position)
    end

    if comp.tokens and #comp.tokens > 0 then
        spawnComponentTokens(componentName, position)
    end

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



function getBagFromRegistry(id)
    local entry = COMPONENT_REGISTRY[id]
    if not entry then
        print("getBagFromRegistry: No registry entry for " .. tostring(id))
        return nil
    end

    if entry.type ~= "bag" then
        print("getBagFromRegistry: Entry " .. tostring(id) .. " is not a bag")
        return nil
    end

    -- If object reference exists, return it
    if entry.object then
        return entry.object
    end

    -- Fallback: try to fetch by GUID
    if entry.guid then
        return getObjectFromGUID(entry.guid)
    end

    print("getBagFromRegistry: Bag " .. tostring(id) .. " has no object or guid")
    return nil
end


-- Safely insert an object into a bag (normal or Custom_Model_Bag)
function putIntoBag(container, obj)
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
-- Cards
-----------------------------------------


function registerCardSet(basePath, cardBlock, cardList)
    for _, card in ipairs(cardBlock.sets) do
        local entry = {
            id = card.identifier,
            name = card.name or card.identifier,
            type = cardBlock.type or "CustomCard",
            shape = tonumber(cardBlock.shape) or 0,
            scale = card.scale or cardBlock.scale or {x=1, y=1, z=1},
            sideways = card.sideways or false,
            tags = card.tags or {},
            face = resolvePath(basePath, card.face),
            back = resolvePath(basePath, card.back),
            script = registerScript(card.script or cardBlock.script),
            container = card.container or nil
        }

        table.insert(cardList, entry)
        print("Registered card: " .. entry.id .. "->" .. entry.container)
    end
end


function buildCardJSON(entry, position)
    local deckIndex = 1
    return {
        Name = "CardCustom",
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
        LuaScript = "",
        LuaScriptState = ""
    }
end


function spawnCard(entry, position)
    local objData = buildCardJSON(entry, position)
    print("spawn card: " .. entry.id)

    local obj = spawnObjectData({data = objData})
    if not obj then
        print("Failed to spawn card: " .. entry.id)
        return
    end

        loadScript(entry.script, function(scriptText)
        local guid = obj.getGUID()

    Wait.condition(function()
        LOADER.spawning.progress = LOADER.spawning.progress + 1
        checkSpawningReady()

        local realObj = getObjectFromGUID(guid)

        if realObj then
            if entry.script then
                print("assigning script to: " .. entry.id)
                realObj.setLuaScript(scriptText)
            end
        else
            print("object disappeared: " .. entry.id)
        end

        end, function()
            return getObjectFromGUID(guid) ~= nil
        end)
    end)

    return obj
end


function spawnComponentCards(componentName, position)
    local comp = COMPONENT_REGISTRY[componentName]
    print("Spawning cards for component: " .. componentName)

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


-----------------------------------------
-- Tiles
-----------------------------------------


function registerTileSet(basePath, tileBlock, tileList)
    for _, tile in ipairs(tileBlock.sets) do
        local entry = {
            id = tile.identifier,
            name = tile.name or tile.identifier,
            scale = tileBlock.scale or {x=1, y=1, z=1},
            tags = tile.tags or {},
            face = resolvePath(basePath, tile.face),
            back = resolvePath(basePath, tile.back),
            script = registerScript(tile.script or tileBlock.script)
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
            rotY = 180,
            rotZ = 180,
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
            ImageScalar = 1,
            WidthScale = 1,
            CustomTile = {
            Type = 0,
            Thickness = 0.2,
            Stackable = true,
            Stretch = true
            }
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


-----------------------------------------
-- Models
-----------------------------------------

function registerModelSet(basePath, modelBlock, modelList)
    for _, model in ipairs(modelBlock.sets) do
        entry = {
            id = model.identifier,
            name = model.name or model.identifier,
            scale = modelBlock.scale or {x=1, y=1, z=1},
            tags = model.tags or {},
            colorDiffuse = model.ColorDiffuse or nil,
            mesh = resolvePath(basePath, model.mesh),
            texture = resolvePath(basePath, model.texture),
            normal = model.normal and resolvePath(basePath, model.normal) or nil,
            collider = model.collider and resolvePath(basePath, model.collider) or nil,
            script = registerScript(model.script or modelBlock.script),
            materialIndex = model.MaterialIndex or 0,
            typeIndex = model.TypeIndex or 0,
            bag = model.Bag or nil,
            container = model.container or nil
        }

        table.insert(modelList, entry)
        print("Registered model: " .. entry.id)
    end
end


function buildModelJSON(entry, position)
    local data = {
        Name = "Custom_Model",

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

        Nickname = entry.name,
        Description = "",
        GMNotes = "",
        Tags = entry.tags or {},

        AltLookAngle = {
            x = 0,
            y = 0,
            z = 0
        },

        ColorDiffuse = entry.colorDiffuse or {
            r = 1,
            g = 1,
            b = 1,
            a = 1
        },

        LayoutGroupSortIndex = 0,
        Value = 0,
        Locked = true,
        Grid = true,
        Snap = true,
        IgnoreFoW = false,
        MeasureMovement = false,
        DragSelectable = true,
        Autoraise = true,
        Sticky = true,
        Tooltip = true,
        GridProjection = false,
        HideWhenFaceDown = false,
        Hands = false,
        Number = 0,

        CustomMesh = {
            MeshURL = entry.mesh,
            DiffuseURL = entry.texture,
            NormalURL = entry.normal or "",
            ColliderURL = entry.collider or "",
            Convex = false,
            MaterialIndex = entry.materialIndex or 0,
            TypeIndex = entry.typeIndex or 0,

            CustomShader = {
                SpecularColor = {
                    r = 1,
                    g = 1,
                    b = 1
                },
                SpecularIntensity = 0,
                SpecularSharpness = 2,
                FresnelStrength = 0
            },

            CastShadows = true
        },

        LuaScript = "",
        LuaScriptState = "",
        XmlUI = ""
    }

    if entry.Bag then
        data.Name = "Custom_Model_Bag"
        data.Bag = { Order = entry.bag or 0 }
        BAG_QUEUE.registerBag(entry.bag, entry.id)
    end

    return data
end


function spawnModel(entry, position)
    print("spawn model: " .. entry.id)

    local objData = buildModelJSON(entry, position)
    objData.Locked = true   -- spawn with no physics

    local obj = spawnObjectData({ data = objData })
    if not obj then
        print("Failed to spawn model: " .. entry.id)
        return
    end

    local guid = obj.getGUID()

    -- Wait for the object AND its custom data to be ready
    Wait.condition(function()
        LOADER.spawning.progress = LOADER.spawning.progress + 1
        checkSpawningReady()

        local realObj = getObjectFromGUID(guid)
        if not realObj then return end

        -- Only refresh custom models
        if entry.type == "Custom_Model" or realObj.tag == "Custom_Model" then
            local ok, custom = pcall(function()
                return realObj.getCustomObject()
            end)

            if ok and custom and next(custom) ~= nil then
                realObj.setCustomObject(custom)
            else
                return  -- keep waiting
            end
        end

        realObj.setLock(false)
    end, function()
        local realObj = getObjectFromGUID(guid)
        if not realObj then return false end
        if entry.type == "Custom_Model" or realObj.tag == "Custom_Model" then
            local ok, custom = pcall(function()
                return realObj.getCustomObject()
            end)
            return ok and custom and next(custom) ~= nil
        end

        return true
    end)

    if entry.script then
        loadScript(entry.script, function(scriptText)
            Wait.condition(function()
                local realObj = getObjectFromGUID(guid)
                if realObj then
                    realObj.setLuaScript(scriptText)
                end
            end, function()
                return getObjectFromGUID(guid) ~= nil
            end)
        end)
    end

    return obj
end



function spawnComponentModels(componentName, position)
    local comp = COMPONENT_REGISTRY[componentName]
    if not comp or not comp.models then return end

    for _, entry in ipairs(comp.models) do
        spawnModel(entry, position)
    end
end


function registerScript(script)
    local scriptURL = nil

    if script then
        scriptURL = resolvePath(basePath, script)
        if scriptURL and not SCRIPT_CACHE[scriptURL] then
            loadScript(scriptURL, function(_) end)
        end
    end

    return scriptURL
end


-----------------------------------------
-- AssetBundles
-----------------------------------------

function registerAssetBundleSet(basePath, bundleBlock, bundleList)
    local scale = bundleBlock.scale or {x=1, y=1, z=1}

    for _, bundle in ipairs(bundleBlock.sets) do
        local entry = {
            id = bundle.identifier,
            name = bundle.name or bundle.identifier,
            scale = scale,
            tags = bundle.tags or {},
            colorDiffuse = bundle.ColorDiffuse or nil,
            assetbundleURL = resolvePath(basePath, bundle.assetbundleURL),
            assetbundleSecondaryURL = bundle.assetbundleSecondaryURL and resolvePath(basePath, bundle.assetbundleSecondaryURL) or nil,
            script = registerScript(bundle.script or bundleBlock.script),
            materialIndex = bundle.MaterialIndex or 0,
            typeIndex = bundle.TypeIndex or 0,
            bag = bundle.Bag or nil,
            container = bundle.container or nil
        }

        table.insert(bundleList, entry)
        print("Registered assetbundle: " .. entry.id)
    end
end


function buildAssetBundleJSON(entry, position)
    local data = {
        Name = "Custom_Assetbundle",

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

        Nickname = entry.name,
        Description = "",
        GMNotes = "",
        Tags = entry.tags or {},

        ColorDiffuse = entry.colorDiffuse or {
            r = 1,
            g = 1,
            b = 1,
            a = 1
        },

        CustomAssetbundle = {
            AssetbundleURL = entry.bundle,
            AssetbundleSecondaryURL = entry.bundle2 or "",
            MaterialIndex = entry.materialIndex or 0,
            TypeIndex = entry.typeIndex or 0,
        },

        LuaScript = "",
        LuaScriptState = ""
    }

    if entry.Bag then
        data.Bag = { Order = entry.bag or 0 }
        BAG_QUEUE.registerBag(entry.bag, entry.id)
    end

    return data
end


function spawnAssetBundle(entry, position)
    print("spawn assetbundle: " .. entry.id)

    local objData = buildAssetBundleJSON(entry, position)
    local obj = spawnObjectData({ data = objData })
    if not obj then
        print("Failed to spawn assetbundle: " .. entry.id)
        return
    end

    local guid = obj.getGUID()
    if entry.script then
        loadScript(entry.script, function(scriptText)
            Wait.condition(function()
                local realObj = getObjectFromGUID(guid)
                if realObj then
                    realObj.setLuaScript(scriptText)
                end
            end, function()
                return getObjectFromGUID(guid) ~= nil
            end)
        end)
    end

    return obj
end


function spawnComponentAssetBundles(componentName, position)
    local comp = COMPONENT_REGISTRY[componentName]
    if not comp or not comp.assetbundles then return end

    for _, entry in ipairs(comp.assetbundles) do
        spawnAssetBundle(entry, position)
    end
end


-----------------------------------------
-- Bags
-----------------------------------------

function registerBagSet(basePath, bagBlock, bagList)
    for _, bag in ipairs(bagBlock.sets) do
        local entry = {
            id = bag.identifier,
            name = bag.name or bag.identifier,
            scale = bagBlock.scale or {x=1, y=1, z=1},
            colorDiffuse = bag.ColorDiffuse or nil,
            script = registerScript(bag.script or bagBlock.script),
            container = bag.container or nil
        }

        table.insert(bagList, entry)
        print("Registered bag: " .. entry.id)
    end
end


function buildBagJSON(entry, position)

    local data = {
        type = entry.type,
        position = position,
        rotation = {0, 180, 0},
        scale = entry.scale,
        ColorDiffuse = entry.colorDiffuse or {
            r = 1,
            g = 1,
            b = 1,
            a = 1
        },
    }

    if entry.Bag then
        data.Bag = { Order = entry.bag or 0 }
        BAG_QUEUE.registerBag(entry.bag, entry.id)
    end

    return data
end


function spawnBag(entry, position)
    print("spawn bag: " .. entry.id)

    local objData = buildBagJSON(entry, position)
    local obj = spawnObjectData({ data = objData })

    if not obj then
        print("Failed to spawn bag: " .. entry.id)
        return
    end

    local guid = obj.getGUID()
    obj.setColorTint(entry.colorDiffuse)

    if entry.script then
        loadScript(entry.script, function(scriptText)
            Wait.condition(function()
                local realObj = getObjectFromGUID(guid)
                if realObj then
                    realObj.setLuaScript(scriptText)
                end
            end, function()
                return getObjectFromGUID(guid) ~= nil
            end)
        end)
    end

    return obj
end


function spawnComponentBag(componentName, position)
    local comp = COMPONENT_REGISTRY[componentName]
    if not comp or not comp.bag then return nil end

    local bagId = comp.identifier
    local bagEntry = findEntryInRegistry("bags", bagId)
    if not bagEntry then
        print("Bag not found: " .. bagId)
        return nil
    end

    local bagObj = spawnBag(bagEntry, position)
    return bagObj
end


function spawnComponentBagContents(componentName, bagObj)
    local comp = COMPONENT_REGISTRY[componentName]
    if not comp or not comp.bag or not comp.bag.contents then return end
    local bagGUID = bagObj.getGUID()

    for _, item in ipairs(comp.bag.contents) do
        local entry = findEntryInRegistry(item.type, item.id)
        if entry then
            spawnAndInsertIntoBag(entry, item.type, bagGUID)
        else
            print("Missing bag content: " .. item.type .. " / " .. item.id)
        end
    end
end


function spawnAndInsertIntoBag(entry, typeName, bagGUID)
    local bagObj = getObjectFromGUID(bagGUID)
    if not bagObj then return end
    local position = bagObj.getPosition()

    local spawner = SPAWNERS[typeName]
    if not spawner then
        print("No spawner for type: " .. typeName)
        return
    end

    local obj = spawner(entry, position, nil)
    if not obj then return end
    local guid = obj.getGUID()

    Wait.condition(function()
        local realObj = getObjectFromGUID(guid)
        if realObj then
            realObj.setLock(false)
            bagObj.putObject(realObj)
        end
    end, function()
        return getObjectFromGUID(guid) ~= nil
    end)
end


-----------------------------------------
-- Tokens
-----------------------------------------

function registerTokenSet(basePath, tokenBlock, tokenList)
    for _, token in ipairs(tokenBlock.sets) do
        local entry = {
            id = token.identifier,
            name = token.name or token.identifier,
            scale = tokenBlock.scale or {x=1, y=1, z=1},
            tags = token.tags or {},
            colorDiffuse = token.ColorDiffuse or nil,
            face = resolvePath(basePath, token.face),
            back = resolvePath(basePath, token.back),
            shape = token.shape or 0,
            script = registerScript(token.script or tokenBlock.script),
            materialIndex = token.MaterialIndex or 0,
            typeIndex = token.TypeIndex or 0,
            bag = token.Bag or nil,
            container = token.container or nil
        }

        table.insert(tokenList, entry)
        print("Registered token: " .. entry.id)
    end
end


function buildTokenJSON(entry, position)
    return {
        Name = "Custom_Token",

        Transform = {
            posX = position.x,
            posY = position.y,
            posZ = position.z,
            rotX = 0,
            rotY = 180,
            rotZ = 180,
            scaleX = entry.scale.x,
            scaleY = entry.scale.y,
            scaleZ = entry.scale.z
        },

        Nickname = entry.name,
        Description = "",
        GMNotes = "",
        Tags = entry.tags or {},

        ColorDiffuse = entry.colorDiffuse or {
            r = 1,
            g = 1,
            b = 1,
            a = 1
        },

        CustomImage = {
            ImageURL = entry.face,
            ImageSecondaryURL = entry.back,
            ImageScalar = 1,
            WidthScale = 1,
            MaterialIndex = entry.materialIndex or 0,
            TypeIndex = entry.typeIndex or 0,
            CustomToken = {
                Thickness = 0.2,
                MergeDistance = 15,
                Stackable = true,
                Shape = entry.shape
            }
        },

        LuaScript = "",
        LuaScriptState = ""
    }
end


function spawnToken(entry, position)
    print("spawn token: " .. entry.id)
-- todo
    local objData = buildTokenJSON(entry, position)
    local obj = spawnObjectData({data = objData})
    if not obj then return end

    local guid = obj.getGUID()

    if entry.script then
        loadScript(entry.script, function(scriptText)
            Wait.condition(function()
                local realObj = getObjectFromGUID(guid)
                if realObj then realObj.setLuaScript(scriptText) end
            end, function() return getObjectFromGUID(guid) ~= nil end)
        end)
    end
end


function spawnComponentTokens(componentName, position)
    local comp = COMPONENT_REGISTRY[componentName]
    if not comp or not comp.tokens then return end

    for _, entry in ipairs(comp.tokens) do
        spawnToken(entry, position)
    end
end


-----------------------------------------
-- Figurines
-----------------------------------------

function registerFigurineSet(basePath, figBlock, figList)
    for _, fig in ipairs(figBlock.sets) do
        local entry = {
            id = fig.identifier,
            name = fig.name or fig.identifier,
            scale = figBlock.scale or {x=1, y=1, z=1},
            color = fig.color or "White",
            colorDiffuse = fig.ColorDiffuse or nil,
            script = registerScript(fig.script or figBlock.script),
            materialIndex = fig.MaterialIndex or 0,
            typeIndex = fig.TypeIndex or 0,
            bag = fig.Bag or nil,
            container = fig.container or nil
        }

        table.insert(figList, entry)
        print("Registered figurine: " .. entry.id)
    end
end


function buildFiguringJSON(entry, position)
-- todo 
    local data = {
        type = "Figurine",
        position = position,
        rotation = {0, 180, 0},
        scale = entry.scale
    }

    return data
end


function spawnFigurine(entry, position)
    print("spawn figurine: " .. entry.id)

    local objData = buildFiguringJSON(entry, position)
    local obj = spawnObjectData({ data = objData })
    if not obj then return end

    local guid = obj.getGUID()
    obj.setColorTint(entry.color)

    if entry.script then
        loadScript(entry.script, function(scriptText)
            Wait.condition(function()
                local realObj = getObjectFromGUID(guid)
                if realObj then realObj.setLuaScript(scriptText) end
            end, function() return getObjectFromGUID(guid) ~= nil end)
        end)
    end
end


function spawnComponentFigurines(componentName, position, container)
    local comp = COMPONENT_REGISTRY[componentName]
    if not comp or not comp.figurines then return end

    for _, entry in ipairs(comp.figurines) do
        spawnFigurine(entry, position, container)
    end
end


-----------------------------------------
-- Dice
-----------------------------------------

function registerDiceSet(basePath, diceBlock, diceList)
    for _, die in ipairs(diceBlock.sets) do
        local entry = {
            id = die.identifier,
            name = die.name or die.identifier,
            scale = diceBlock.scale or {x=1, y=1, z=1},
            type = die.type,
            faces = die.faces,
            color = die.color,
            script = registerScript(die.script or diceBlock.script),
            materialIndex = die.MaterialIndex or 0,
            typeIndex = die.TypeIndex or 0,
            bag = die.Bag or nil,
            container = die.container or nil
        }

        table.insert(diceList, entry)
        print("Registered die: " .. entry.id)
    end
end


function buildDiceJSON(entry, position)
    local data = {
        Name = "Custom_Dice",

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

        ColorDiffuse = entry.colorDiffuse or {
            r = 1,
            g = 1,
            b = 1,
            a = 1
        },

        CustomDice = {
            Type = 0,
            Faces = entry.faces
        },

        LuaScript = "",
        LuaScriptState = ""
    }

    return data
end


function spawnDice(entry, position)
    print("spawn die: " .. entry.id)

    local obj
    if entry.faces then
        local objData = buildDiceJSON(entry, position)
        obj = spawnObjectData({data = objData})
    else
        obj = spawnObject({
            type = entry.type,
            position = position,
            rotation = {0,0,0},
            scale = entry.scale
        })
    end

    if not obj then return end
    local guid = obj.getGUID()

    if entry.script then
        loadScript(entry.script, function(scriptText)
            Wait.condition(function()
                local realObj = getObjectFromGUID(guid)
                if realObj then realObj.setLuaScript(scriptText) end
            end, function() return getObjectFromGUID(guid) ~= nil end)
        end)
    end
end


function spawnComponentDice(componentName, position)
    local comp = COMPONENT_REGISTRY[componentName]
    if not comp or not comp.dice then return end

    for _, entry in ipairs(comp.dice) do
        spawnDice(entry, position)
    end
end


-----------------------------------------
-- Decks
-----------------------------------------

function registerDeckSet(basePath, deckBlock, deckList)
    for _, deck in ipairs(deckBlock.sets) do
        local entry = {
            id = deck.identifier,
            name = deck.name or deck.identifier,
            scale = deckBlock.scale or {x=1, y=1, z=1},
            cardsheet = resolvePath(basePath, deck.cardsheet),
            back = resolvePath(basePath, deck.back),
            width = deck.width,
            height = deck.height,
            numCards = deck.numCards,
            script = registerScript(deck.script or deckBlock.script),
            materialIndex = deck.MaterialIndex or 0,
            typeIndex = deck.TypeIndex or 0,
            bag = deck.Bag or nil,
            container = deck.container or nil
        }

        table.insert(deckList, entry)
        print("Registered deck: " .. entry.id)
    end
end


function buildDeckJSON(entry, position)
    local data = {
        Name = "DeckCustom",

        Transform = {
            posX = position.x,
            posY = position.y,
            posZ = position.z,
            rotX = 0,
            rotY = 180,
            rotZ = 180,
            scaleX = entry.scale.x,
            scaleY = entry.scale.y,
            scaleZ = entry.scale.z
        },

        Nickname = entry.name,
        Description = "",
        GMNotes = "",
        Tags = entry.tags or {},

        ColorDiffuse = entry.colorDiffuse or {
            r = 1,
            g = 1,
            b = 1,
            a = 1
        },

        CustomDeck = {
            FaceURL = entry.cardsheet,
            BackURL = entry.back,
            NumWidth = entry.width,
            NumHeight = entry.height,
            BackIsHidden = true
        },

        DeckIDs = (function()
            local ids = {}
            for i=1, entry.numCards do table.insert(ids, i-1) end
            return ids
        end)(),

        LuaScript = "",
        LuaScriptState = ""
    }

    return data
end


function spawnDeck(entry, position)
    print("spawn deck: " .. entry.id)

    local objData = buildDeckJSON(entry, position)
    local obj = spawnObjectData({data = objData})
    if not obj then return end
    local guid = obj.getGUID()

    if entry.script then
        loadScript(entry.script, function(scriptText)
            Wait.condition(function()
                local realObj = getObjectFromGUID(guid)
                if realObj then realObj.setLuaScript(scriptText) end
            end, function() return getObjectFromGUID(guid) ~= nil end)
        end)
    end
end


function spawnComponentDecks(componentName, position)
    local comp = COMPONENT_REGISTRY[componentName]
    if not comp or not comp.decks then return end

    for _, entry in ipairs(comp.decks) do
        spawnDeck(entry, position)
    end
end


-----------------------------------------
-- Blocks
-----------------------------------------

function registerBlockSet(basePath, blockBlock, blockList)
    for _, block in ipairs(blockBlock.sets) do
        local entry = {
            id = block.identifier,
            name = block.name or block.identifier,
            scale = blockBlock.scale or {x=1, y=1, z=1},
            type = block.type or blockBlock.type or "BlockSquare",
            color = block.color or "White",
            tags = block.tags or {},
            script = registerScript(block.script or blockBlock.script),
            materialIndex = block.MaterialIndex or 0,
            typeIndex = block.TypeIndex or 0,
            bag = block.Bag or nil,
            container = block.container or nil
        }

        table.insert(blockList, entry)
        print("Registered block: " .. entry.id)
    end
end


function spawnBlock(entry, position)
    print("spawn block: " .. entry.id)

    local obj = spawnObject({
        type = entry.type,
        position = position,
        rotation = {0, 180, 0},
        scale = entry.scale
    })

    if not obj then
        print("Failed to spawn block: " .. entry.id)
        return
    end

    local guid = obj.getGUID()
    obj.setColorTint(entry.color)

    if entry.script then
        loadScript(entry.script, function(scriptText)
            Wait.condition(function()
                local realObj = getObjectFromGUID(guid)
                if realObj then
                    realObj.setLuaScript(scriptText)
                end
            end, function()
                return getObjectFromGUID(guid) ~= nil
            end)
        end)
    end

    return obj
end


function spawnComponentBlocks(componentName, position)
    local comp = COMPONENT_REGISTRY[componentName]
    if not comp or not comp.blocks then return end

    for _, entry in ipairs(comp.blocks) do
        spawnBlock(entry, position)
    end
end


-----------------------------------------
-- Boards
-----------------------------------------

function registerBoardSet(basePath, boardBlock, boardList)
    local scale = boardBlock.scale or {x=1, y=1, z=1}

    for _, board in ipairs(boardBlock.sets) do
        local entry = {
            id = board.identifier,
            name = board.name or board.identifier,
            scale = scale,
            face = resolvePath(basePath, board.face),
            back = resolvePath(basePath, board.back),
            script = board.script and resolvePath(basePath, board.script) or nil
        }

        table.insert(boardList, entry)
        print("Registered board: " .. entry.id)
    end
end


function buildBoardJSON(entry, position)
    return {
        Name = "Custom_Board",

        Transform = {
            posX = position.x,
            posY = position.y,
            posZ = position.z,
            rotX = 0,
            rotY = 180,
            rotZ = 180,
            scaleX = entry.scale.x,
            scaleY = entry.scale.y,
            scaleZ = entry.scale.z
        },

        Nickname = entry.name,

        CustomImage = {
            ImageURL = entry.face,
            ImageSecondaryURL = entry.back,
            ImageScalar = 1
        },

        LuaScript = "",
        LuaScriptState = ""
    }
end


function spawnBoard(entry, position)
    print("spawn board: " .. entry.id)

    local objData = buildBoardJSON(entry, position)
    local obj = spawnObjectData({data = objData})
    if not obj then return end
    local guid = obj.getGUID()

    if entry.script then
        loadScript(entry.script, function(scriptText)
            Wait.condition(function()
                local realObj = getObjectFromGUID(guid)
                if realObj then realObj.setLuaScript(scriptText) end
            end, function() return getObjectFromGUID(guid) ~= nil end)
        end)
    end
end


function spawnComponentBoards(componentName, position, container)
    local comp = COMPONENT_REGISTRY[componentName]
    if not comp or not comp.boards then return end

    for _, entry in ipairs(comp.boards) do
        spawnBoard(entry, position, container)
    end
end
