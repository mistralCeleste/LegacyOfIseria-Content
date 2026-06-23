-- Hooks into the summable overlay
-- for objects with values

-----------------------------------------
-- Configuration
-----------------------------------------

local MAX_REGISTRY_TRIES = 5      -- how many times to try
local REGISTRY_RETRY_DELAY = 30    -- frames between tries (30 = ~0.5 sec)
local tries = 0

-----------------------------------------
-- Component
-----------------------------------------
local id = nil
local component = nil


-----------------------------------------
-- Events
-----------------------------------------

function onLoad()
    id = self.getName()
    tryLoadComponent()
end


function tryLoadComponent()
    tries = tries + 1
    local json = Global.call("getRegistryComponentJSON", id)

    if json then
        component = JSON.decode(json)
        onComponentLoaded()
        return
    end

    if tries < MAX_REGISTRY_TRIES then
        Wait.frames(tryLoadComponent, REGISTRY_RETRY_DELAY)
        return
    end

    Log.error("Unable to load from Global Registry component id: " .. id)
end


function onComponentLoaded()
    self.addContextMenuItem("Show Sum", showSum)
    self.addContextMenuItem("Announce " .. id, announce)
end


function announce(player_color)
    print("[Announcement] " .. component.identifier)
end


function getValue()
    return tonumber(component.value)
end


function showSum(player_color)
    local sum = sumSelectedValues(player_color)
    print("Sum value: " .. sum)
end


function sumSelectedValues(player_color)
    local player = Player[player_color]
    if not player then return end

    local selected = player.getSelectedObjects()
    local total = 0

    for _, obj in ipairs(selected) do
        local value = obj.call("getValue")
        if value then total = total + value end
    end

    return total
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
