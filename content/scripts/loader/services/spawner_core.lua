-- spawner_core.lua
-- Generic spawner for all component types.

local include = require("loader/include")
local REGISTRY = include("loader/registry")

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

REGISTRY.registerSpawner("CustomCard", SPAWNER.spawn)
REGISTRY.registerSpawner("Custom_Tile", SPAWNER.spawn)
REGISTRY.registerSpawner("Custom_Model", SPAWNER.spawn)
REGISTRY.registerSpawner("Custom_Dice", SPAWNER.spawn)
REGISTRY.registerSpawner("Custom_Bag", SPAWNER.spawn)

return SPAWNER
