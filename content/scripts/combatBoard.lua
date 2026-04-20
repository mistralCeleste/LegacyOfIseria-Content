--[[ Lua code. See documentation: https://api.tabletopsimulator.com/ --]]

-----------------------------------------
-- Configuration
-----------------------------------------


-----------------------------------------
-- Event Handlers
-----------------------------------------

function onLoad()
    self.addContextMenuItem("Cleanup Dungeon", cleanupDungeon)
end


-----------------------------------------
-- Dungeon Tracking
-----------------------------------------

function cleanupDungeon(player_color)
    Global.call("cleanupDungeon")
end
