if GetResourceState('qbx_core') ~= 'started' then return end

Bridge = Bridge or {}
Bridge.Framework = 'qbx'

-- ---------------------------------------------------------------------------
-- Player
-- ---------------------------------------------------------------------------

---@param source number
function Bridge.GetPlayer(source)
    return exports.qbx_core:GetPlayer(source)
end

---@param source number
---@return string|nil citizenid
function Bridge.GetPlayerIdentifier(source)
    local player = exports.qbx_core:GetPlayer(source)
    return player and player.PlayerData.citizenid
end

---@param source number
---@return table|nil job
function Bridge.GetJob(source)
    local player = exports.qbx_core:GetPlayer(source)
    return player and player.PlayerData.job
end

---@param source number
---@return string name
function Bridge.GetPlayerName(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return ('Unknown (%s)'):format(source) end

    local info = player.PlayerData.charinfo
    return ('%s %s'):format(info.firstname, info.lastname)
end

---@param source number
---@return number grade normalized numeric job grade (qbx stores job.grade as { name, level })
function Bridge.GetJobGrade(source)
    local player = exports.qbx_core:GetPlayer(source)
    return player and player.PlayerData.job.grade.level or 0
end

---@param source number
---@param job string
---@param grade? number
function Bridge.SetJob(source, job, grade)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end

    return exports.qbx_core:SetJob(source, job, grade or 0)
end

---@param source number
---@return boolean|nil onDuty the player's new duty state, or nil if no player found
function Bridge.ToggleDuty(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return nil end

    local onDuty = not player.PlayerData.job.onduty
    player.Functions.SetJobDuty(onDuty)

    Bridge.Notify(source, onDuty and 'You just went On Duty' or 'You just went Off Duty', onDuty and 'success' or 'error')

    return onDuty
end

---@param source number
---@param state boolean desired duty state (true = on duty, false = off duty)
---@return boolean|nil onDuty the player's duty state after the call, or nil if no player found
--- Idempotent: only touches the framework flag / notifies when the state
--- actually changes, so it can be called safely on spawn/relog without
--- flip-flopping an existing shift.
function Bridge.SetDuty(source, state)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return nil end

    state = state and true or false

    if player.PlayerData.job.onduty ~= state then
        player.Functions.SetJobDuty(state)
        Bridge.Notify(source, state and 'You just went On Duty' or 'You just went Off Duty', state and 'success' or 'error')
    end

    return state
end

---@return table[] all connected players (qbx player objects)
function Bridge.GetPlayers()
    return exports.qbx_core:GetQBPlayers()
end

---@param job string
---@return number[] source ids of every player on duty for that job
function Bridge.GetPlayersOnDuty(job)
    local sources = {}

    for _, player in pairs(exports.qbx_core:GetQBPlayers()) do
        if player.PlayerData.job.name == job and player.PlayerData.job.onduty then
            sources[#sources + 1] = player.PlayerData.source
        end
    end

    return sources
end

---@param job string
---@return { identifier: string, name: string }[] offline employees for that job
--- Assumes the stock qbx_core `players` table (citizenid PRIMARY KEY,
--- job/charinfo JSON columns). Adjust the query if your server uses a
--- custom players schema.
function Bridge.GetOfflineEmployees(job)
    -- JSON_UNQUOTE(JSON_EXTRACT(...)) rather than the `->>` shorthand: MySQL
    -- supports `->>` but MariaDB never implemented it (only plain `->`,
    -- which stays JSON-quoted), so this form works on both.
    local rows = MySQL.query.await("SELECT citizenid, charinfo FROM players WHERE JSON_UNQUOTE(JSON_EXTRACT(job, '$.name')) = ?", { job })
    local employees = {}

    for _, row in ipairs(rows or {}) do
        local charinfo = json.decode(row.charinfo or '{}')
        employees[#employees + 1] = {
            identifier = row.citizenid,
            name = ('%s %s'):format(charinfo.firstname or '?', charinfo.lastname or ''),
        }
    end

    return employees
end

-- ---------------------------------------------------------------------------
-- Inventory (ox_inventory - qbx_core default)
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
