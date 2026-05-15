-----------------------------------------
-- Usage:
-- Add script to Book type component.
--
-- Behavior:
-- Flips to the page referenced by the deck index a player types.
--
-- Example:
-- Player hovers over the LOC booklet (book), they type "101",
-- the page containing LOC-101 is opened.
-----------------------------------------

-----------------------------------------
-- Configuration
-----------------------------------------

-- number of times to try loading the component information from the Global Registry
local MAX_REGISTRY_TRIES = 5      -- how many times to try
local REGISTRY_RETRY_DELAY = 2    -- frames between tries (30 = ~0.5 sec)
local tries = 0

PAGE_INDEX = {}
MAX_TYPED_VALUE = 1000
PADDING_LENGTH = 3


-----------------------------------------
-- Component
-----------------------------------------
local id = nil
local component = nil


local function waitForObjectLoaded(obj, callback)
    Wait.condition(
        function()
           Log.debug("loaded object: " .. component.identifier)
            callback(obj)
        end,
        function()
            local bundle = obj.AssetBundle
            Log.debug("waiting for object: " .. component.identifier)
            return bundle ~= nil and bundle.getTriggerEffects() ~= nil
        end
    )
end


local function tryLoadComponent()
    tries = tries + 1
    local json = Global.call("getRegistryComponentJSON", id)

    if json then
        component = JSON.decode(json)
        waitForObjectLoaded(self, function(o)
            onComponentLoaded(o)
        end)
        return
    end

    if tries < MAX_REGISTRY_TRIES then
        Wait.frames(tryLoadComponent, REGISTRY_RETRY_DELAY)
        return
    end

    Log.error("Unable to load from Global Registry component id: " .. id)
end


-----------------------------------------
-- Events
-----------------------------------------

function onLoad()
    id = self.getName()
    self.max_typed_number = MAX_TYPED_VALUE
    tryLoadComponent()
end


function onComponentLoaded()
    Log.debug("Book loaded:")

    Wait.frames(function()
        local effects = self.AssetBundle.getTriggerEffects()
        buildPageIndex()
    end, 10)
end


-----------------------------------------
-- Event Handlers
-----------------------------------------

function onNumberTyped(player_color, number, alt)
    local hover_object = Player[player_color].getHoverObject()
    if not hover_object then return end
    if hover_object.getGUID() ~= self.getGUID() then return end
    findAndOpenPage(number)
    return true
end


-----------------------------------------
-- Setup
-----------------------------------------

function buildPageIndex()
    PAGE_INDEX = {}
    local effects = self.AssetBundle.getTriggerEffects()

    if not effects then
        print("Book: No trigger effects found for booklet: " .. component.identifier)
        return
    end

    for _, effect in ipairs(effects) do
        if effect.name and effect.name ~= "" then
            PAGE_INDEX[effect.name] = effect.index   -- zero-based
            Log.debug("Booklet: " .. component.identifier .. " add page: " .. effect.name .. " to index: " .. effect.index)
        end
    end
end


-----------------------------------------
-- Book Operations
-----------------------------------------

function openBookToPage(page)
    self.AssetBundle.playTriggerEffect(page)
end


function openPageToId(id)
    local index = PAGE_INDEX[id]

    if not index then
        print("Cannot find " .. tostring(id) .. " in " .. component.identifier)
        return
    end

    self.AssetBundle.playTriggerEffect(index)
    print("Opened " .. self.getName() .. " to " .. tostring(id))
end


function findAndOpenPage(value)
    local search = applyIndexPadding(value, PADDING_LENGTH)
    local index = findFirstPageIndex(search)
    if not index then return end
    openBookToPage(index)
end


function applyIndexPadding(value, padding_length)
    return string.format("%0" .. padding_length .. "d", value)
end


function checkStringContains(text, search)
    text = string.lower(text or "")
    search = string.lower(search or "")
    return string.find(text, search) ~= nil
end


function findFirstPageIndex(search)
    for name, index in pairs(PAGE_INDEX) do
        print("name: " .. name .. "; index: " .. index)
        if not string.match(name, "^page") and not string.match(name, "^spread") then
            if checkStringContains(name, search) then
                print("found " .. name)
                return index
            end
        end
    end
    return nil
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
