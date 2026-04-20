--[[ Lua code. See documentation: https://api.tabletopsimulator.com/ --]]

-----------------------------------------
-- Configuration
-----------------------------------------


-----------------------------------------
-- Event Handlers
-----------------------------------------


-----------------------------------------
-- Book Tracking
-----------------------------------------

BOOKS = {}

function registerBook(params)
    BOOKS[params.name] = params.guid
    print("Registering book " .. params.name .. " with GUID" .. params.guid)
end


function getBook(params)
    return getObjectFromGUID(BOOKS[params.name])
end


function printBooks()
        for name, guid in pairs(BOOKS) do
        print(name, guid, params.name)
    end
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
