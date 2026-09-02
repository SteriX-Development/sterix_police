if GetResourceState('es_extended') ~= 'started' then return end

Bridge = Bridge or {}
Bridge.Framework = 'esx'

local ESX = exports['es_extended']:getSharedObject()

-- ---------------------------------------------------------------------------
-- Player
-- ---------------------------------------------------------------------------

function Bridge.GetPlayerData()
    return ESX.GetPlayerData()
end

---@return table job { name, label, grade, grade_label, onduty }
function Bridge.GetJob()
    local playerData = ESX.GetPlayerData()

    return {
        name = playerData.job.name,
        label = playerData.job.label,
        grade = playerData.job.grade,
        grade_label = playerData.job.grade_label,
        onduty = true, -- ESX has no duty state by default, treat job members as always on duty unless you add esx_duty/qb-style duty
    }
end

function Bridge.IsPlayerLoaded()
    return ESX.IsPlayerLoaded()
end

-- ---------------------------------------------------------------------------
-- Events -> forward framework specific job/player update events to a single
-- bridge event so the rest of the script never needs to care which
-- framework fired it.
-- ---------------------------------------------------------------------------

RegisterNetEvent('esx:setJob', function(job)
    TriggerEvent('sterix_police:bridge:client:jobUpdate', job)
end)

RegisterNetEvent('esx:playerLoaded', function()
    TriggerEvent('sterix_police:bridge:client:playerLoaded')
end)

RegisterNetEvent('esx:onPlayerLogout', function()
    TriggerEvent('sterix_police:bridge:client:playerUnloaded')
end)

-- ---------------------------------------------------------------------------
-- Inventory (ox_inventory - common default on modern ESX servers)
-- ---------------------------------------------------------------------------

---@param item string
---@param amount? number
function Bridge.HasItem(item, amount)
    return exports.ox_inventory:Search('count', item) >= (amount or 1)
end
