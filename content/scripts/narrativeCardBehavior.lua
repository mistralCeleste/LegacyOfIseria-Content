-----------------------------------------
-- Usage:
-- Add script to Card type component.
--
-- Behavior:
-- Enables a player to open the card in the associated booklet.
--
-- Example:
-- Player hovers over the NPC card (Card),
-- they either press the registered hotkey or select "Open Book" from the menu,
-- and the page containing the NPC is opened in the NPC booklet.
-----------------------------------------

-----------------------------------------
-- Configuration
-----------------------------------------

-- number of times to try loading the component information from the Global Registry
local MAX_REGISTRY_TRIES = 5      -- how many times to try
local REGISTRY_RETRY_DELAY = 2    -- frames between tries (30 = ~0.5 sec)
local tries = 0


-----------------------------------------
-- Component
-----------------------------------------
local id = nil
local component = nil


local function tryLoadComponent()
    tries = tries + 1
    local json = Global.call("getRegistryComponentJSON", id)

    if json then
        component = JSON.decode(json)
        onComponentLoaded()
        return
    end

    if tries < MAX_REGISTRY_TRIES then
        Wait.frames(tryLoadEntry, REGISTRY_RETRY_DELAY)
        return
    end

    Log.error("Unable to load from Global Registry component id: " .. id)
end


-----------------------------------------
-- Events
-----------------------------------------

function onLoad()
    id = self.getName()
    tryLoadComponent()
end


function onComponentLoaded()
    buildContextMenus()
    registerHotkeys()
end


function onPlayerPing(player, position, pinged_object)
   if not pinged_object then return end
    if pinged_object.getGUID() ~= self.getGUID() then return end
    openBook()
end

-----------------------------------------
-- Setup
-----------------------------------------

function buildContextMenus()
    self.clearContextMenu()
    self.addContextMenuItem("Open Book to " .. component.identifier, openBookFromMenu, false)
end


function registerHotkeys()
    addHotkey("Card -> Open Book", openBookFromHotkey)
end


-----------------------------------------
-- Operations
-----------------------------------------

function openBookFromMenu(player_color, object_position, object)
    openBook()
end


function openBookFromHotkey(player_color, hovered_object, position, is_key_up)
        if hovered_object.getGUID() ~= self.getGUID() then return end
    openBook()
end


function openBook()
    local book = findBookForCard(component.identifier)
    if not book then return end
    book.call("openPageToId", component.identifier)
end


function findBookObject(name)
    for _, object in ipairs(getAllObjects()) do
        if object.getName() == name then
            return object
        end
    end
    return nil
end


function findBookForCard(name)
    local book_id = extractIdPrefix(name)
    local book_guid = Global.call("getRegistryComponentGUID", book_id)
    local book = getObjectFromGUID(book_guid) or findBookObject(book_id)
    warnIfInvalid(book, "Book " .. book_id .. " not found")
    return book
end


function extractIdPrefix(name)
    return string.match(name, "^(%u+)%-%d") or name
end


function extractIndexCode(name)
    return string.match(name, "%-(.+)$") or name
end


function warnIfInvalid(object, warning)
    if not object then
        Log.warn(warning)
    end
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
