--[[
    bridge/client.lua

    Framework-agnostic client bridge. Anything that behaves the same no matter
    which framework is running (notify, progress, target) lives here,
    built on top of ox_lib / ox_target with a qb-target fallback.

    Framework specific pieces (player data, jobs, ...) are added on top of
    this same `Bridge` table by bridge/qbx/client.lua, bridge/qb/client.lua
    or bridge/esx/client.lua - whichever one detects its framework is running.

    Callbacks are not wrapped here - use ox_lib's lib.callback directly.
]]

Bridge = Bridge or {}

local hasOxTarget = GetResourceState('ox_target') == 'started'
local hasQBTarget = GetResourceState('qb-target') == 'started'

-- ---------------------------------------------------------------------------
-- Notify / Progress (ox_lib)
-- ---------------------------------------------------------------------------

---@param text string
---@param type? 'inform'|'success'|'error'|'warning'
---@param duration? number ms
---@param title? string
function Bridge.Notify(text, type, duration, title)
    lib.notify({
        title = title,
        description = text,
        type = type or 'inform',
        duration = duration or 5000,
    })
end

---@param label string
---@param duration number ms
---@param options? table { canCancel?, useWhileDead?, disable?, anim?, prop? }
---@return boolean success
function Bridge.Progress(label, duration, options)
    options = options or {}

    return lib.progressBar({
        label = label,
        duration = duration,
        canCancel = options.canCancel ~= false,
        useWhileDead = options.useWhileDead or false,
        allowRagdoll = options.allowRagdoll or false,
        allowCuffed = options.allowCuffed or false,
        disable = options.disable,
        anim = options.anim,
        prop = options.prop,
    })
end

-- ---------------------------------------------------------------------------
-- Target (ox_target preferred, qb-target fallback)
-- ---------------------------------------------------------------------------

---@param name string
---@param coords vector3
---@param length number
---@param width number
---@param options table { heading?, height?, debug?, options } - options.options is the list of target options
function Bridge.AddBoxZone(name, coords, length, width, options)
    options = options or {}

    if hasOxTarget then
        return exports.ox_target:addBoxZone({
            coords = coords,
            size = vec3(length, width, options.height or 2.0),
            rotation = options.heading or 0.0,
            debug = options.debug or false,
            options = options.options,
        })
    elseif hasQBTarget then
        exports['qb-target']:AddBoxZone(name, coords, length, width, options)
        return name
    end
end

---@param entity number
---@param targetOptions table
function Bridge.AddTargetEntity(entity, targetOptions)
    if hasOxTarget then
        return exports.ox_target:addLocalEntity(entity, targetOptions)
    elseif hasQBTarget then
        exports['qb-target']:AddTargetEntity(entity, { options = targetOptions, distance = 2.5 })
    end
end

---@param models string|number|table
---@param targetOptions table
function Bridge.AddTargetModel(models, targetOptions)
    if hasOxTarget then
        return exports.ox_target:addModel(models, targetOptions)
    elseif hasQBTarget then
        exports['qb-target']:AddTargetModel(models, { options = targetOptions, distance = 2.5 })
    end
end

---@param id string|number id/name returned by AddBoxZone/AddTargetEntity/AddTargetModel
function Bridge.RemoveZone(id)
    if hasOxTarget then
        exports.ox_target:removeZone(id)
    elseif hasQBTarget then
        exports['qb-target']:RemoveZone(id)
    end
end

-- ---------------------------------------------------------------------------
-- Duty (server owns the actual toggle - see bridge/server.lua and
-- Bridge.ToggleDuty in bridge/qbx/server.lua, bridge/qb/server.lua,
-- bridge/esx/server.lua)
-- ---------------------------------------------------------------------------

function Bridge.ToggleDuty()
    TriggerServerEvent('sterix_police:bridge:server:toggleDuty')
end

---@param state boolean desired duty state (true = on duty, false = off duty)
--- Deterministic set (no flip). Server-side Bridge.SetDuty is idempotent, so
--- calling this when already in the desired state is a no-op.
function Bridge.SetDuty(state)
    TriggerServerEvent('sterix_police:bridge:server:setDuty', state and true or false)
end

-- ---------------------------------------------------------------------------
-- Resource lifecycle
-- ---------------------------------------------------------------------------

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    TriggerEvent('sterix_police:bridge:client:resourceStart')
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    TriggerEvent('sterix_police:bridge:client:resourceStop')
end)
