REGISTRY = {
    components = {},     -- FullId → component definition
    bags = {},           -- BagId → bag definition
    scripts = {},        -- ScriptPath → script text
    builders = {},       -- ObjectType → builder function
    spawners = {},       -- ObjectType → spawner function
    classes = {}         -- Optional: class metadata (Vanguard, Pathfinder, etc.)
}

------------------------------------------------------------
-- COMPONENT REGISTRATION
------------------------------------------------------------

-- Register a component definition (cards, tiles, models, dice, bags, etc.)
function REGISTRY.registerComponent(fullId, data)
    if not fullId then
        error("REGISTRY.registerComponent: missing fullId")
    end
    REGISTRY.components[fullId] = data
end

-- Retrieve a component definition by FullId
function REGISTRY.getComponent(fullId)
    return REGISTRY.components[fullId]
end

-- Iterate all components (useful for debugging or bulk spawning)
function REGISTRY.getAllComponents()
    return REGISTRY.components
end

------------------------------------------------------------
-- BAG REGISTRATION
------------------------------------------------------------

function REGISTRY.registerBag(bagId, data)
    if not bagId then
        error("REGISTRY.registerBag: missing bagId")
    end
    REGISTRY.bags[bagId] = data
end

function REGISTRY.getBag(bagId)
    return REGISTRY.bags[bagId]
end

------------------------------------------------------------
-- SCRIPT REGISTRATION
------------------------------------------------------------

-- Cache a script's text so builders can inject it into spawned objects
function REGISTRY.registerScript(path, text)
    REGISTRY.scripts[path] = text
end

function REGISTRY.getScript(path)
    return REGISTRY.scripts[path]
end

------------------------------------------------------------
-- BUILDER REGISTRATION
------------------------------------------------------------

-- Register a builder for a specific object type (CustomCard, Custom_Tile, etc.)
function REGISTRY.registerBuilder(objectType, fn)
    REGISTRY.builders[objectType] = fn
end

function REGISTRY.getBuilder(objectType)
    return REGISTRY.builders[objectType]
end

------------------------------------------------------------
-- SPAWNER REGISTRATION
------------------------------------------------------------

function REGISTRY.registerSpawner(objectType, fn)
    REGISTRY.spawners[objectType] = fn
end

function REGISTRY.getSpawner(objectType)
    return REGISTRY.spawners[objectType]
end

------------------------------------------------------------
-- CLASS METADATA (OPTIONAL)
------------------------------------------------------------

function REGISTRY.registerClass(name, data)
    REGISTRY.classes[name] = data
end

function REGISTRY.getClass(name)
    return REGISTRY.classes[name]
end

------------------------------------------------------------
-- DEBUG HELPERS
------------------------------------------------------------

function REGISTRY.debugPrint()
    print("=== REGISTRY DEBUG ===")
    print("Components:", #REGISTRY.components)
    print("Bags:", #REGISTRY.bags)
    print("Scripts:", #REGISTRY.scripts)
    print("Builders:", #REGISTRY.builders)
    print("Spawners:", #REGISTRY.spawners)
    print("Classes:", #REGISTRY.classes)
end


------------------------------------------------------------
-- BUILDER FUNCTIONS
------------------------------------------------------------
BUILDER = BUILDER or {}

------------------------------------------------------------
-- Build a bag object (supports: Bag, InfiniteBag, Custom_Model bag)
------------------------------------------------------------
function BUILDER.buildBag(set, defaults)
    defaults = defaults or {}

    local scale = set.scale or defaults.scale or { x = 1, y = 1, z = 1 }
    local bagType = set.bagType or "Bag"   -- "Bag", "InfiniteBag", or "Custom_Model"

    --------------------------------------------------------
    -- BUILT-IN BAG (TTS native Bag)
    --------------------------------------------------------
    if bagType == "Bag" then
        return {
            Name = "Bag",
            Transform = {
                posX = 0, posY = 0, posZ = 0,
                rotX = 0, rotY = 180, rotZ = 0,
                scaleX = scale.x, scaleY = scale.y, scaleZ = scale.z
            },
            Nickname = set.name or "",
            Description = set.description or "",
            ColorDiffuse = set.color or { r = 1, g = 1, b = 1 },
            Locked = false,
            Grid = true,
            Snap = true,
            Autoraise = true,
            Sticky = true,
            Tooltip = true,
            LuaScript = set.scriptText or "",
            LuaScriptState = "",
            Tags = set.tags or {}
        }
    end

    --------------------------------------------------------
    -- INFINITE BAG (TTS native InfiniteBag)
    --------------------------------------------------------
    if bagType == "InfiniteBag" then
        return {
            Name = "InfiniteBag",
            Transform = {
                posX = 0, posY = 0, posZ = 0,
                rotX = 0, rotY = 180, rotZ = 0,
                scaleX = scale.x, scaleY = scale.y, scaleZ = scale.z
            },
            Nickname = set.name or "",
            Description = set.description or "",
            ColorDiffuse = set.color or { r = 1, g = 1, b = 1 },
            Locked = false,
            Grid = true,
            Snap = true,
            Autoraise = true,
            Sticky = true,
            Tooltip = true,
            LuaScript = set.scriptText or "",
            LuaScriptState = "",
            Tags = set.tags or {}
        }
    end

    --------------------------------------------------------
    -- CUSTOM-MODEL BAG (Custom_Model with container metadata)
    --------------------------------------------------------
    if bagType == "Custom_Model" then
        return {
            Name = "Custom_Model",
            Transform = {
                posX = 0, posY = 0, posZ = 0,
                rotX = set.rotX or 0,
                rotY = set.rotY or 180,
                rotZ = set.rotZ or 0,
                scaleX = scale.x, scaleY = scale.y, scaleZ = scale.z
            },
            Nickname = set.name or "",
            Description = set.description or "",
            ColorDiffuse = { r = 1, g = 1, b = 1 },
            Locked = false,
            Grid = true,
            Snap = true,
            Autoraise = true,
            Sticky = true,
            Tooltip = true,
            LuaScript = set.scriptText or "",
            LuaScriptState = "",
            Tags = set.tags or {},

            CustomMesh = {
                MeshURL = set.mesh,
                DiffuseURL = set.diffuse or "",
                NormalURL = set.normal or "",
                ColliderURL = set.collider or "",
                Convex = set.convex ~= false,
                MaterialIndex = set.materialIndex or 0,
                TypeIndex = set.typeIndex or 0,
                CastShadows = set.castShadows ~= false
            },

            -- Container metadata (TTS will treat this as a bag)
            Container = {
                Type = set.containerType or 0,   -- 0 = bag, 1 = infinite bag
                Stackable = set.stackable ~= false
            }
        }
    end

    --------------------------------------------------------
    -- Unknown bag type
    --------------------------------------------------------
    error("builder_bags: Unsupported bagType '" .. tostring(bagType) .. "'")
end

REGISTRY.registerBuilder("Custom_Bag", BUILDER.buildBag)


------------------------------------------------------------
-- Build a CustomCard JSON table for spawnObjectData
------------------------------------------------------------
function BUILDER.buildCard(set, defaults)
    defaults = defaults or {}

    local card = {
        Name = "CardCustom",
        Transform = {
            posX = 0, posY = 0, posZ = 0,
            rotX = 0, rotY = 180, rotZ = 0,
            scaleX = (set.scale and set.scale.x) or (defaults.scale and defaults.scale.x) or 1,
            scaleY = (set.scale and set.scale.y) or (defaults.scale and defaults.scale.y) or 1,
            scaleZ = (set.scale and set.scale.z) or (defaults.scale and defaults.scale.z) or 1
        },
        Nickname = set.name or "",
        Description = set.description or "",
        ColorDiffuse = { r = 1, g = 1, b = 1 },
        Locked = false,
        Grid = true,
        Snap = true,
        Autoraise = true,
        Sticky = true,
        Tooltip = true,
        CardID = 0,
        CustomDeck = {},
        LuaScript = set.scriptText or "",
        LuaScriptState = "",
        Tags = set.tags or {}
    }

    --------------------------------------------------------
    -- CustomDeck entry
    --------------------------------------------------------
    local deckId = 1
    card.CustomDeck[deckId] = {
        FaceURL = set.face,
        BackURL = set.back,
        NumWidth = 1,
        NumHeight = 1,
        BackIsHidden = false,
        UniqueBack = false
    }

    card.CardID = deckId * 100

    return card
end

REGISTRY.registerBuilder("CustomCard", BUILDER.buildCard)

------------------------------------------------------------
-- Build a Custom_Dice JSON table for spawnObjectData
------------------------------------------------------------
function BUILDER.buildDice(set, defaults)
    defaults = defaults or {}

    local scale = set.scale or defaults.scale or { x = 1, y = 1, z = 1 }

    local dice = {
        Name = "Custom_Dice",
        Transform = {
            posX = 0, posY = 0, posZ = 0,
            rotX = set.rotX or 0,
            rotY = set.rotY or 180,
            rotZ = set.rotZ or 0,
            scaleX = scale.x,
            scaleY = scale.y,
            scaleZ = scale.z
        },
        Nickname = set.name or "",
        Description = set.description or "",
        ColorDiffuse = { r = 1, g = 1, b = 1 },
        Locked = false,
        Grid = true,
        Snap = true,
        Autoraise = true,
        Sticky = true,
        Tooltip = true,
        LuaScript = set.scriptText or "",
        LuaScriptState = "",
        Tags = set.tags or {},

        CustomDice = {
            Type = set.diceType or 0,   -- 0 = d6, 1 = d4, 2 = d8, etc.
            Faces = set.faces or {},    -- array of image URLs
            BackURL = set.back or "",   -- optional
            Thickness = set.thickness or 0.2,
            MaterialIndex = set.materialIndex or 0
        }
    }

    return dice
end

REGISTRY.registerBuilder("Custom_Dice", BUILDER.buildDice)


------------------------------------------------------------
-- Build a Custom_Model JSON table for spawnObjectData
------------------------------------------------------------
function BUILDER.buildModel(set, defaults)
    defaults = defaults or {}

    local scale = set.scale or defaults.scale or { x = 1, y = 1, z = 1 }

    local model = {
        Name = "Custom_Model",
        Transform = {
            posX = 0, posY = 0, posZ = 0,
            rotX = set.rotX or 0,
            rotY = set.rotY or 180,
            rotZ = set.rotZ or 0,
            scaleX = scale.x,
            scaleY = scale.y,
            scaleZ = scale.z
        },
        Nickname = set.name or "",
        Description = set.description or "",
        ColorDiffuse = { r = 1, g = 1, b = 1 },
        Locked = false,
        Grid = true,
        Snap = true,
        Autoraise = true,
        Sticky = true,
        Tooltip = true,
        LuaScript = set.scriptText or "",
        LuaScriptState = "",
        Tags = set.tags or {},

        CustomMesh = {
            MeshURL = set.mesh,
            DiffuseURL = set.diffuse or "",
            NormalURL = set.normal or "",
            ColliderURL = set.collider or "",
            Convex = set.convex or true,
            MaterialIndex = set.materialIndex or 0,
            TypeIndex = set.typeIndex or 0,
            CastShadows = set.castShadows ~= false
        }
    }

    return model
end

REGISTRY.registerBuilder("Custom_Model", BUILDER.buildModel)


------------------------------------------------------------
-- Build a Custom_Tile JSON table for spawnObjectData
------------------------------------------------------------
function BUILDER.buildTile(set, defaults)
    defaults = defaults or {}

    local scale = set.scale or defaults.scale or { x = 1, y = 1, z = 1 }

    local tile = {
        Name = "Custom_Tile",
        Transform = {
            posX = 0, posY = 0, posZ = 0,
            rotX = 0, rotY = 180, rotZ = 0,
            scaleX = scale.x,
            scaleY = scale.y,
            scaleZ = scale.z
        },
        Nickname = set.name or "",
        Description = set.description or "",
        ColorDiffuse = { r = 1, g = 1, b = 1 },
        Locked = false,
        Grid = true,
        Snap = true,
        Autoraise = true,
        Sticky = true,
        Tooltip = true,
        LuaScript = set.scriptText or "",
        LuaScriptState = "",
        Tags = set.tags or {},

        CustomImage = {
            ImageURL = set.face,
            ImageSecondaryURL = set.back or set.face,
            WidthScale = set.widthScale or 0,
            HeightScale = set.heightScale or 0,
            Type = 0,          -- 0 = tile
            Thickness = 0.1,   -- default tile thickness
            Stackable = set.stackable or true
        }
    }

    return tile
end

REGISTRY.registerBuilder("Custom_Tile", BUILDER.buildTile)

------------------------------------------------------------
-- Build a generic misc object
-- Supports:
--   - Built-in TTS objects (BlockSquare, Chip, Token, Figurine, etc.)
--   - CustomObject (single image)
--   - Custom_Model fallback (if mesh is provided)
------------------------------------------------------------
function BUILDER.buildMisc(set, defaults)
    defaults = defaults or {}

    local scale = set.scale or defaults.scale or { x = 1, y = 1, z = 1 }
    local objType = set.miscType or "CustomObject"

    --------------------------------------------------------
    -- CUSTOM MODEL FALLBACK (if mesh is provided)
    --------------------------------------------------------
    if set.mesh then
        return {
            Name = "Custom_Model",
            Transform = {
                posX = 0, posY = 0, posZ = 0,
                rotX = set.rotX or 0,
                rotY = set.rotY or 180,
                rotZ = set.rotZ or 0,
                scaleX = scale.x, scaleY = scale.y, scaleZ = scale.z
            },
            Nickname = set.name or "",
            Description = set.description or "",
            ColorDiffuse = { r = 1, g = 1, b = 1 },
            Locked = false,
            Grid = true,
            Snap = true,
            Autoraise = true,
            Sticky = true,
            Tooltip = true,
            LuaScript = set.scriptText or "",
            LuaScriptState = "",
            Tags = set.tags or {},

            CustomMesh = {
                MeshURL = set.mesh,
                DiffuseURL = set.diffuse or "",
                NormalURL = set.normal or "",
                ColliderURL = set.collider or "",
                Convex = set.convex ~= false,
                MaterialIndex = set.materialIndex or 0,
                TypeIndex = set.typeIndex or 0,
                CastShadows = set.castShadows ~= false
            }
        }
    end

    --------------------------------------------------------
    -- BUILT-IN TTS OBJECT (BlockSquare, Chip, Token, etc.)
    --------------------------------------------------------
    if objType ~= "CustomObject" then
        return {
            Name = objType,
            Transform = {
                posX = 0, posY = 0, posZ = 0,
                rotX = set.rotX or 0,
                rotY = set.rotY or 180,
                rotZ = set.rotZ or 0,
                scaleX = scale.x, scaleY = scale.y, scaleZ = scale.z
            },
            Nickname = set.name or "",
            Description = set.description or "",
            ColorDiffuse = set.color or { r = 1, g = 1, b = 1 },
            Locked = false,
            Grid = true,
            Snap = true,
            Autoraise = true,
            Sticky = true,
            Tooltip = true,
            LuaScript = set.scriptText or "",
            LuaScriptState = "",
            Tags = set.tags or {}
        }
    end

    --------------------------------------------------------
    -- CUSTOM OBJECT (single image)
    --------------------------------------------------------
    return {
        Name = "Custom_Object",
        Transform = {
            posX = 0, posY = 0, posZ = 0,
            rotX = set.rotX or 0,
            rotY = set.rotY or 180,
            rotZ = set.rotZ or 0,
            scaleX = scale.x, scaleY = scale.y, scaleZ = scale.z
        },
        Nickname = set.name or "",
        Description = set.description or "",
        ColorDiffuse = { r = 1, g = 1, b = 1 },
        Locked = false,
        Grid = true,
        Snap = true,
        Autoraise = true,
        Sticky = true,
        Tooltip = true,
        LuaScript = set.scriptText or "",
        LuaScriptState = "",
        Tags = set.tags or {},

        CustomImage = {
            ImageURL = set.face or "",
            ImageSecondaryURL = set.back or set.face or "",
            WidthScale = set.widthScale or 0,
            HeightScale = set.heightScale or 0,
            Type = 0,        -- flat token
            Thickness = set.thickness or 0.1,
            Stackable = set.stackable ~= false
        }
    }
end

REGISTRY.registerBuilder("Custom_Misc", BUILDER.buildMisc)

local PATH = {}

------------------------------------------------------------
-- Normalize slashes (Windows, GitHub, TTS safe)
------------------------------------------------------------
function PATH.normalize(p)
    return (p:gsub("\\", "/"))
end

------------------------------------------------------------
-- Extract directory from a path
-- "foo/bar/baz.json" → "foo/bar"
------------------------------------------------------------
function PATH.getDirectory(path)
    path = PATH.normalize(path)
    local idx = path:match("^.*()/")
    if idx then
        return path:sub(1, idx - 1)
    end
    return ""
end

------------------------------------------------------------
-- Join two paths safely
------------------------------------------------------------
function PATH.join(a, b)
    a = PATH.normalize(a or "")
    b = PATH.normalize(b or "")

    if a == "" then return b end
    if b == "" then return a end

    return a .. "/" .. b
end

------------------------------------------------------------
-- Resolve relative paths like "../", "./"
------------------------------------------------------------
function PATH.resolveRelative(base, rel)
    base = PATH.normalize(base)
    rel = PATH.normalize(rel)

    -- If rel is already absolute (starts with http or /), return as-is
    if rel:match("^https?://") or rel:sub(1,1) == "/" then
        return rel
    end

    -- Combine
    local combined = PATH.join(base, rel)

    -- Resolve ../ and ./
    local parts = {}
    for part in combined:gmatch("[^/]+") do
        if part == ".." then
            table.remove(parts)
        elseif part ~= "." then
            table.insert(parts, part)
        end
    end

    return table.concat(parts, "/")
end

------------------------------------------------------------
-- Resolve JSON file path (TTS asset or GitHub Pages)
------------------------------------------------------------
function PATH.resolveJSON(path)
    path = PATH.normalize(path)

    -- If it's already a URL, return as-is
    if path:match("^https?://") then
        return path
    end

    -- TTS loads JSON from asset files directly
    local content = getObjectFromGUID("GLOBAL").getLuaScript() -- placeholder
    local json = JSON.decode(content)

    return json
end

------------------------------------------------------------
-- Read a Lua script file from TTS assets
------------------------------------------------------------
function PATH.readScript(path)
    path = PATH.normalize(path)

    if not path:match("%.lua$") then
        path = path .. ".lua"
    end

    -- TTS loads script assets via Global.getLuaScript() or via AssetBundles
    -- Here we assume the script is stored in the TTS asset list
    local script = getObjectFromGUID("GLOBAL").getLuaScript() -- placeholder

    return script
end

---------------------------------------------------------------
-- SPANWERS
---------------------------------------------------------------

SPAWNER = SPAWNER or {}

------------------------------------------------------------
-- Generic spawn function for ANY component type
------------------------------------------------------------
function SPAWNER.spawn(fullId, position)
    local comp = REGISTRY.getComponent(fullId)
    if not comp then
        error("SPAWNER.spawn: Unknown component FullId '" .. tostring(fullId) .. "'")
    end

    -- Get the builder for this object type
    local builder = REGISTRY.getBuilder(comp.type)
    if not builder then
        error("SPAWNER.spawn: No builder registered for type '" .. tostring(comp.type) .. "'")
    end

    -- Build the TTS object JSON
    local ttsJSON = builder(comp.data, {
        scale = comp.scale
    })

    -- Apply spawn position
    if position then
        ttsJSON.Transform.posX = position.x or 0
        ttsJSON.Transform.posY = position.y or 3
        ttsJSON.Transform.posZ = position.z or 0
    end

    -- Spawn the object
    local obj = spawnObjectData({ data = ttsJSON })
    if not obj then
        error("SPAWNER.spawn: spawnObjectData failed for '" .. fullId .. "'")
    end

    return obj
end

REGISTRY.registerSpawner("CustomCard",   SPAWNER.spawn)
REGISTRY.registerSpawner("Custom_Tile",  SPAWNER.spawn)
REGISTRY.registerSpawner("Custom_Model", SPAWNER.spawn)
REGISTRY.registerSpawner("Custom_Dice",  SPAWNER.spawn)
REGISTRY.registerSpawner("Custom_Bag",   SPAWNER.spawn)
REGISTRY.registerSpawner("Custom_Misc",  SPAWNER.spawn)

-------------------------------------------------------------
-- LOADER
--------------------------------------------------------------

LOADER = {}

function LOADER.loadAll()
    -- Load your root JSON file(s)
    -- Example:
    -- JSON_LOADER.load("data/root.json")

    print("[LOADER] All systems initialized.")
end

