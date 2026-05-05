-- defaultCardBehavior.lua
-- Attached to every card by your loader

local entry = nil

function onLoad()
    local id = self.getName()
    local data = Global.call("getRegistryComponentJSON", self.getName())
    entry = JSON.decode(data)
    self.addContextMenuItem("Announce " .. id, announce)
end


function announce(playerColor)
    print("[Card Announcement] " .. entry.identifier)
end

