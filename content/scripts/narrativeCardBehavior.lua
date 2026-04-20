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
-- and the page containing the NPC is opened in the associated booklet..
-----------------------------------------

-----------------------------------------
-- CONFIGURATION
-----------------------------------------


-----------------------------------------
-- Event Handlers
-----------------------------------------

function onLoad()
    buildContextMenus()
    registerHotkeys()
end


-----------------------------------------
-- Setup
-----------------------------------------

function buildContextMenus()
    self.clearContextMenu()
    self.addContextMenuItem("Open Book to " .. self.getName(), openBookFromMenu, false)
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
    if hovered_object.getGUID() == self.getGUID() then
        openBook()
    end
end


function openBook()
    local name = self.getName()
    local book = findBookForCard(name)
    if not book then return end
    book.call("openPageToId", name)
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
    local book_name = extractIdPrefix(name)
    local book = Global.call("getBook", { name = book_name })
    warnIfInvalid(book, "Book " .. book_name .. " not found")
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
        print(warning)
    end
end
