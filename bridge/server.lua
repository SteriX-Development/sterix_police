--[[
    bridge/server.lua

    Framework-agnostic server bridge. Anything that behaves the same no
    matter which framework is running (notify) lives here, built on top of
    ox_lib.

    Framework specific pieces (players, jobs, inventory) are added on top of
    this same `Bridge` table by bridge/qbx/server.lua, bridge/qb/server.lua
    or bridge/esx/server.lua - whichever one detects its framework is running.
]]

Bridge = Bridge or {}

-- ---------------------------------------------------------------------------
-- Notify (ox_lib)
-- ---------------------------------------------------------------------------

---@param source number
---@param text string
---@param type? 'inform'|'success'|'error'|'warning'
---@param duration? number ms
---@param title? string
function Bridge.Notify(source, text, type, duration, title)
    TriggerClientEvent('ox_lib:notify', source, {
        title = title,
        description = text,
        type = type or 'inform',
        duration = duration or 5000,
    })
end

-- ---------------------------------------------------------------------------
-- Duty (forwards to the framework specific Bridge.ToggleDuty added by
-- bridge/qbx/server.lua, bridge/qb/server.lua, or bridge/esx/server.lua)
--
-- This is the ONLY place that calls Bridge.ToggleDuty (the framework's own
-- flag flip) - it then broadcasts the resulting state via dutyChanged so
-- anything else that needs to react (server/addons/duty/tracking.lua) does
-- so based on the actual new state, not by independently guessing/toggling
-- its own separate flag. Two independent toggles can start one step out of
-- sync (e.g. a player already on duty before the tracking system ever saw
-- them) and would otherwise stay inverted forever after.
-- ---------------------------------------------------------------------------

RegisterNetEvent('sterix_police:bridge:server:toggleDuty', function()
    local source = source
    local onDuty = Bridge.ToggleDuty(source)

    TriggerEvent('sterix_police:bridge:server:dutyChanged', source, onDuty)
end)

-- Deterministic counterpart of toggleDuty - sets an explicit state instead of
-- flipping. Used e.g. to force a player OFF duty on spawn/relog without any
-- risk of accidentally toggling them the wrong way. Same trust level as
-- toggleDuty (the client could already freely toggle its own duty).
RegisterNetEvent('sterix_police:bridge:server:setDuty', function(state)
    local source = source
    local onDuty = Bridge.SetDuty(source, state and true or false)

    TriggerEvent('sterix_police:bridge:server:dutyChanged', source, onDuty)
end)

-- ---------------------------------------------------------------------------
-- Resource lifecycle
-- ---------------------------------------------------------------------------

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    TriggerEvent('sterix_police:bridge:server:resourceStart')
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    TriggerEvent('sterix_police:bridge:server:resourceStop')
end)
