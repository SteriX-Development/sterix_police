if GetResourceState('qbx_core') ~= 'started' then return end

Bridge = Bridge or {}
Bridge.Framework = 'qbx'

-- ---------------------------------------------------------------------------
-- Player
-- ---------------------------------------------------------------------------

function Bridge.GetPlayerData()
    return exports.qbx_core:GetPlayerData()
end

---@return table job { name, label, grade, grade_label, onduty, type, isboss }
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
-- Inventory (ox_inventory - qbx_core default)
-- ---------------------------------------------------------------------------

---@param item string
---@param amount? number
function Bridge.HasItem(item, amount)
    return exports.ox_inventory:Search('count', item) >= (amount or 1)
end
