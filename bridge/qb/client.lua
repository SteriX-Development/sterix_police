if GetResourceState('qb-core') ~= 'started' then return end
if GetResourceState('qbx_core') == 'started' then return end -- qbx_core takes priority when both are present

Bridge = Bridge or {}
Bridge.Framework = 'qb'

local QBCore = exports['qb-core']:GetCoreObject()

-- ---------------------------------------------------------------------------
-- Player
-- ---------------------------------------------------------------------------

function Bridge.GetPlayerData()
    return QBCore.Functions.GetPlayerData()
end

---@return table job { name, label, grade, onduty, type, isboss }
function Bridge.GetJob()
    return Bridge.GetPlayerData().job
end

function Bridge.IsPlayerLoaded()
    return LocalPlayer.state.isLoggedIn
end

-- ---------------------------------------------------------------------------
-- Events -> forward framework specific job/player update events to a single
-- bridge event so the rest of the script never needs to care which
-- framework fired it.
-- ---------------------------------------------------------------------------

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    TriggerEvent('sterix_police:bridge:client:jobUpdate', job)
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    TriggerEvent('sterix_police:bridge:client:playerLoaded')
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    TriggerEvent('sterix_police:bridge:client:playerUnloaded')
end)

-- ---------------------------------------------------------------------------
-- Inventory (qb-inventory / built-in qb-core items)
-- ---------------------------------------------------------------------------

---@param item string
---@param amount? number
function Bridge.HasItem(item, amount)
    return QBCore.Functions.HasItem(item, amount or 1)
end
