-----------------------------------------
-- CONFIGURATION
-----------------------------------------
DIALS = {
    threat = { max = 12, prefix = "Threat ", index = 0 },
    escalation = { max = 12, prefix = "Escalation ", index = 0 },
    corruption = { max = 12, prefix = "Corruption ", index = 0 }
}

triggerMap = {}
MAX_TYPED_VALUE = 1000
USE_PADDING = false


-----------------------------------------
-- ON LOAD
-----------------------------------------
function onLoad()
    self.max_typed_number = MAX_TYPED_VALUE
    cacheTriggerEffects()
    buildContextMenus()
    registerHotkeys()
end

function cacheTriggerEffects()
    local effects = self.AssetBundle.getTriggerEffects()
    if not effects then
        print("No trigger effects found on the Wheel")
        return
    end

    for i, effect in ipairs(effects) do
        triggerMap[effect.name] = i - 1   -- TTS uses 0-based index
    end
end

function buildContextMenus()
    self.clearContextMenu()
    for name, dial in pairs(DIALS) do
        self.addContextMenuItem("+ " .. name, function() stepDialByName(name, 1) end, true)
        self.addContextMenuItem("- " .. name, function() stepDialByName(name, -1) end, true)
    end
end

function registerHotkeys()
    for name, dial in pairs(DIALS) do
        addHotkey("Increment " .. name, function(_, obj)
            if obj == self then stepDialByName(name, 1) end
        end)

        addHotkey("Decrement " .. name, function(_, obj)
            if obj == self then stepDialByName(name, -1) end
        end)
    end
end

-----------------------------------------
-- Event Handlers
-----------------------------------------

function onNumberTyped(player_color, number, alt)
    local hoverObject = Player[player_color].getHoverObject()
    if not hoverObject then return end
    if hoverObject.getGUID() ~= self.getGUID() then return end
    
    local amount = number
    local isDecrement = alt

    if amount == 0 then
        amount = 10
    end

    if isDecrement then
        amount = -amount
    end

    adjustThreat(amount)
end

function onScriptingButtonDown(index, player_color)
    local hoverObject = Player[player_color].getHoverObject()
    if not hoverObject then return end
    if hoverObject.getGUID() ~= self.getGUID() then return end

    local amount = index

    if amount == 0 then
        amount = 10
    end

    adjustThreat(amount)
end

-----------------------------------------
-- CORE LOGIC
-----------------------------------------
function adjustThreat(delta)
    local threat = DIALS.threat
    local escalation = DIALS.escalation
    local oldIndex = threat.index
    local newIndex = oldIndex + delta

    -- Increment overflow wraps + escalate
    if delta > 0 then
        if newIndex >= threat.max then
            stepDial(escalation, 1)
            newIndex = newIndex % threat.max
        end

    -- Decrement underflow clamps at 0
    elseif delta < 0 then
        if newIndex < 0 then
            newIndex = 0
        end
    end

    setDial(threat, newIndex)
end

function stepDialByName(name, delta)
    local dial = DIALS[name]
    stepDial(dial, delta)
end

function stepDial(dial, delta)
    local newIndex = (dial.index + delta) % dial.max
    setDial(dial, newIndex)
end

function setDial(dial, index)
    dial.index = index
    playTriggerEffect(dial, index)
end

function playTriggerEffect(dial, index)
    local indexName = index

    if USE_PADDING then
        indexName = string.format("%02d", index)
    end

    local triggerName = dial.prefix .. indexName
    local effectIndex = triggerMap[triggerName]

    if effectIndex then
        print("Playing: " .. effectIndex .. "name: " .. triggerName)
        self.AssetBundle.playTriggerEffect(effectIndex)
    else
        print("Missing trigger effect: " .. triggerName)
    end
end
