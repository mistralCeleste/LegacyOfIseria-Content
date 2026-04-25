--[[ Lua code. See documentation: https://api.tabletopsimulator.com/ --]]

-----------------------------------------
-- Configuration
-----------------------------------------

BASE_URL = "http://127.0.0.1:5500"

-----------------------------------------
-- Event Handlers
-----------------------------------------

function onLoad()
    local loader = include(BASE_URL .. "index.json")
    loader.loadAll()

    self.createButton({
        label="Spawn Test Grid",
        click_function="spawnTestGrid",
        function_owner=self,
        position={0,1,0},
        width=2000,
        height=500,
        font_size=300
    })
end

-----------------------------------------
-- Loader
-----------------------------------------

INCLUDE = {}
REGISTRY = {}
BUILDER = {}
SPAWNER = {}

