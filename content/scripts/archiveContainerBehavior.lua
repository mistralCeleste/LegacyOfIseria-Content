-----------------------------------------
-- Usage:
-- Add script to a container object
--
-- Returns:
-- A card from the container matching the number the player types
--
-- Example:
-- Player hovers over the NPC archive (container), they type "101",
-- and the first card found with index "101" is taken out.
-----------------------------------------

-----------------------------------------
-- Configuration
-----------------------------------------

MAX_TYPED_VALUE = 1000
PADDING_LENGTH = 3

SEARCH_TYPE_ALL = 'all'
SEARCH_TYPE_FIRST = 'first'
SEARCH_TYPE = SEARCH_TYPE_FIRST

TRACK_DUNGEON_ITEMS = true
ENSURE_FACEDOWN_WHEN_DRAWN = true

-----------------------------------------
-- Event Handlers
-----------------------------------------

function onLoad()
    self.max_typed_number = MAX_TYPED_VALUE
end


function onNumberTyped(player_color, number, alt)
    local hover_object = Player[player_color].getHoverObject()
    if not hover_object then return end
    if hover_object.getGUID() ~= self.getGUID() then return end

    if SEARCH_TYPE == SEARCH_TYPE_ALL then
        findAndTakeOutAllObjectsToHand(player_color, hover_object, number)
    end

    if SEARCH_TYPE == SEARCH_TYPE_FIRST then
        findAndTakeOutObjectToHand(player_color, hover_object, number)
    end
    return true
end


function onObjectEnterContainer(container, object)
    if not object then return end
    if container.getGUID() ~= self.getGUID() then return end

    if object.tag == "Deck" then
        splitDeckIntoContainer(container, object)
    end

    Global.call("unregisterDungeonObject", object)
end


function onObjectLeaveContainer(container, object)
    if not object then return end
    if container.getGUID() ~= self.getGUID() then return end

    if ENSURE_FACEDOWN_WHEN_DRAWN then
        if object.tag == "Card" or object.tag == "Tile" then
            ensureFaceDown(object)
        end
    end

    if TRACK_DUNGEON_ITEMS then
        local origin = self.getGUID()
        Global.call("registerDungeonObject", { object = object, origin = origin })
    end
end


function ensureFaceDown(card)
    if not isFaceDown(card) then
        local rot = card.getRotation()
        card.setRotation({ rot.x, 180, 180 })
    end
end


function isFaceDown(object)
    local rotation = object.getRotation()
    return math.abs(rotation.z - 180) < 5
end


-----------------------------------------
-- Container Operations
-----------------------------------------

function findAndTakeOutObjectToHand(player_color, container, value)
    local taken = findAndTakeOutObject(container, value)
    putObjectToPlayerHand(player_color, taken)
    return taken
end


function findAndTakeOutObject(container, value)
    local search = applyIndexPadding(value, PADDING_LENGTH)
    local taken = takeFirstPartialMatchingNameFromContainer(container, search)
    printTakenMessage(container.getName(), taken, search)
    return taken
end


function findAndTakeOutAllObjectsToHand(player_color, container, value)
    local cards = findAllObjects(container, value)
    local count = #cards
    local last_card_guid = cards[count].guid
    local taken_cards = {}
    local guids = {}

    for counter = 1, count - 1 do
        local card = cards[counter]
        local taken_card = container.takeObject
        ({
            guid = card.guid,
            smooth = false
        })
        table.insert(taken_cards, taken_card)
        table.insert(guids, card.guid)
    end

    local last_card = getObjectFromGUID(last_card_guid)
    table.insert(taken_cards, last_card)
    table.insert(guids, last_card_guid)

    Wait.frames
    (
        function()
            putObjectWithGuidsToPlayerHand(player_color, guids)
        end,
        1
    )
end


function findAllObjects(container, value)
    local search = applyIndexPadding(value, PADDING_LENGTH)
    return findAllPartialMatchingNamesFromContainer(container, search)
end


function takeFirstPartialMatchingNameFromContainer(container, partial_name)
    for _, item in ipairs(container.getObjects()) do
        if checkStringContains(item.name, partial_name) then
            return container.takeObject({index = item.index})
        end
    end
    return nil
end


function findAllPartialMatchingNamesFromContainer(container, partial_name)
    local results = {}
    local items = container.getObjects()

    for _, item in ipairs(items) do
        if checkStringContains(item.name, partial_name) then
            print("found " .. item.name)
            table.insert(results, item)
        end
    end
    return results
end


function putObjectToPlayerHand(player_color, object)
    local hand = Player[player_color].getHandTransform(1)
    object.setPositionSmooth(hand.position)
end


function putObjectWithGuidsToPlayerHand(player_color, guids)
    local hand = Player[player_color].getHandTransform(1)
    for _, guid in ipairs(guids) do
        putObjectWithGuidToPlayerHand(hand, guid)
    end
end


function putObjectWithGuidToPlayerHand(hand, guid)
    local object = getObjectFromGUID(guid)
    if object == nil then return end
    if not object.isDestroyed() then
        object.setPositionSmooth(hand.position)
    end
end


function splitDeckIntoContainer(container, deck)
    local taken_deck = container.takeObject
    ({
        guid = deck.getGUID(),
        smooth = false
    })

    local cards = taken_deck.getObjects()
    local count = #cards
    local last_card_guid = cards[count].guid
    local taken_cards = {}
    local guids = {}

    for counter = 1, count - 1 do
        local card = cards[counter]
        local taken_card = taken_deck.takeObject
        ({
            guid = card.guid,
            smooth = false
        })
        table.insert(taken_cards, taken_card)
        table.insert(guids, card.guid)
    end

    local last_card = getObjectFromGUID(last_card_guid)
    table.insert(taken_cards, last_card)
    table.insert(guids, last_card_guid)

    Wait.frames
    (
        function()
            transferObjectsWithGuid(container, guids)
        end,
        2
    )
end


function transferCards(container, cards)
    for _, card in ipairs(cards) do
        addObjectToContainer(container, card)
    end
end


function addObjectToContainer(container, object)
    if not object.isDestroyed() then
        local real_object = getObjectFromGUID(object.guid)
        container.putObject(real_object)
    end
end


function transferObjectsWithGuid(container, guids)
    for _, guid in ipairs(guids) do
        addObjectWithGuidToContainer(container, guid)
    end
end


function addObjectWithGuidToContainer(container, guid)
    local object = getObjectFromGUID(guid)
    if not object.isDestroyed() then
        container.putObject(object)
    end
end


-----------------------------------------
-- Helpers
-----------------------------------------

function applyIndexPadding(value, padding_length)
    return string.format("%0" .. padding_length .. "d", value)
end


function checkStringContains(text, search)
    text = string.lower(text or "")
    search = string.lower(search or "")
    return string.find(text, search) ~= nil
end


function printTakenMessage(container, found, search)
    if found then
        print("You drew " .. found.getName() .. " from " .. container)
    else
        print("Cannot find " .. search .. " in " .. container)
    end
end


function printCustomCardData(object)
    local custom = object.getCustomObject()
    print("Face URL: " .. tostring(custom.face))
    print("Back URL: " .. tostring(custom.back))
    print("Width: " .. tostring(custom.width))
    print("Height: " .. tostring(custom.height))
    print("Unique Back: " .. tostring(custom.unique_back))
end

