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

PAGE_INDEX = {}

MAX_TYPED_VALUE = 1000
PADDING_LENGTH = 3


-----------------------------------------
-- Event Handlers
-----------------------------------------

function onLoad()
    self.max_typed_number = MAX_TYPED_VALUE
    buildPageIndex()
    Global.call("registerBook", { name = self.getName(), guid = self.getGUID() })
end


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
        print("Book: No trigger effects found")
        return
    end

    for _, effect in ipairs(effects) do
        if effect.name and effect.name ~= "" then
            PAGE_INDEX[effect.name] = effect.index   -- zero-based
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
        print("Cannot find " .. tostring(id) .. " in " .. self.getName())
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

