if GetResourceState('es_extended') ~= 'started' then return end

Bridge = Bridge or {}
Bridge.Framework = 'esx'

local ESX = exports['es_extended']:getSharedObject()

-- ---------------------------------------------------------------------------
-- Player
-- ---------------------------------------------------------------------------

---@param source number
function Bridge.GetPlayer(source)
    return ESX.GetPlayerFromId(source)
end

---@param source number
---@return string|nil identifier
function Bridge.GetPlayerIdentifier(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    return xPlayer and xPlayer.identifier
end

---@param source number
---@return table|nil job
function Bridge.GetJob(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return nil end

    return {
        name = xPlayer.job.name,
        label = xPlayer.job.label,
        grade = xPlayer.job.grade,
        grade_label = xPlayer.job.grade_label,
        onduty = true, -- ESX has no duty state by default, see bridge/esx/client.lua
        isboss = false, -- ESX has no native boss flag - see DutyTracking.IsJobBoss in server/addons/duty/boss.lua
    }
end

---@param source number
---@return string name
function Bridge.GetPlayerName(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return ('Unknown (%s)'):format(source) end

    if xPlayer.getName then
        return xPlayer.getName()
    end

    return GetPlayerName(source)
end

---@param source number
---@return number grade ESX already stores job.grade as a plain number
function Bridge.GetJobGrade(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    return xPlayer and xPlayer.job.grade or 0
end

---@param source number
---@param job string
---@param grade? number
function Bridge.SetJob(source, job, grade)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end

    xPlayer.setJob(job, grade or 0)
    return true
end

---@param source number
---@return nil ESX has no built-in duty state
function Bridge.ToggleDuty(source)
    print('[sterix_police] Bridge.ToggleDuty is not supported on ESX (no built-in duty state)')
end

---@param source number
---@param state boolean desired duty state
---@return boolean state ESX has no native duty flag, so the script's own duty
--- tracking (server/addons/duty/tracking.lua) is the source of truth - just
--- echo the requested state back so dutyChanged can act on it.
function Bridge.SetDuty(source, state)
    return state and true or false
end

---@return table[] all connected players (esx player objects)
function Bridge.GetPlayers()
    return ESX.GetExtendedPlayers()
end

---@param job string
---@return number[] source ids of every player on that job (ESX has no built-in duty state)
function Bridge.GetPlayersOnDuty(job)
    local sources = {}

    for _, xPlayer in pairs(ESX.GetExtendedPlayers()) do
        if xPlayer.job.name == job then
            sources[#sources + 1] = xPlayer.source
        end
    end

    return sources
end

---@param job string
---@return { identifier: string, name: string }[] offline employees for that job
--- Assumes the stock ESX `users` table (identifier PRIMARY KEY, firstname/
--- lastname, job VARCHAR). Older/custom ESX forks may use `name` instead of
--- firstname/lastname, or a relational job_grades setup - adjust the query
--- to match your actual schema if it errors or returns no rows.
function Bridge.GetOfflineEmployees(job)
    local rows = MySQL.query.await('SELECT identifier, firstname, lastname FROM users WHERE job = ?', { job })
    local employees = {}

    for _, row in ipairs(rows or {}) do
        employees[#employees + 1] = {
            identifier = row.identifier,
            name = ('%s %s'):format(row.firstname or '?', row.lastname or ''),
        }
    end

    return employees
end

-- ---------------------------------------------------------------------------
-- Inventory (ox_inventory - common default on modern ESX servers)
-- ---------------------------------------------------------------------------

---@param source number
---@param item string
---@param amount number
---@param metadata? table
---@param slot? number
function Bridge.AddItem(source, item, amount, metadata, slot)
    return exports.ox_inventory:AddItem(source, item, amount, metadata, slot)
end

---@param source number
---@param item string
---@param amount number
---@param metadata? table
---@param slot? number
function Bridge.RemoveItem(source, item, amount, metadata, slot)
    return exports.ox_inventory:RemoveItem(source, item, amount, metadata, slot)
end

---@param source number
---@param item string
---@param amount? number
function Bridge.HasItem(source, item, amount)
    return exports.ox_inventory:GetItemCount(source, item) >= (amount or 1)
end
