-----------------------------------------
-- Usage:
-- Add script to Box type component.
--
-- Behavior:
-- Unpack (download) the game into the current session through a context menu.
--
-- Example:
-- Player right-clicks the game box,
-- they select "Unpack Game",
-- and the game loads from the website.
-----------------------------------------

-----------------------------------------
-- Configuration
-----------------------------------------

local id = nil
local title = "Legacy of Iseria: Base"
local isProd = true

-----------------------------------------
-- Events
-----------------------------------------

function onLoad()
    id = self.getName()
    buildContextMenus()
end


-----------------------------------------
-- Setup
-----------------------------------------

function buildContextMenus()
    self.clearContextMenu()
    self.addContextMenuItem("Unpack Game", unpackGame, false)

    if not isProd then
        self.addContextMenuItem("Use Local endpoint", useLocal, false)
        self.addContextMenuItem("Use Prod endpoint", useProd, false)
    end
end


function unpackGame()
    if isProd then
        useProd()
    end

    Global.call("unpackGame", title)
end


function useLocal()
    Global.call("setLocalEndpoint")
end


function useProd()
    Global.call("setProdEndpoint")
end
