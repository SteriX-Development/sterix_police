--[[
    client/main.lua

    Entry point for the police script's client-side logic. `Bridge` is
    already populated by this point (bridge/*.lua load before this file in
    fxmanifest.lua) - use Bridge.* for anything framework/inventory/target
    related instead of calling qbx_core/qb-core/es_extended/ox_target etc.
    directly, so the rest of the script stays framework agnostic.
]]

if Config.Debug then
    print(('[sterix_police] client loaded, framework detected: %s'):format(Bridge.Framework or 'none'))
end

RegisterNetEvent('sterix_police:bridge:client:jobUpdate', function(job)
    -- TODO: react to job changes (e.g. toggle police features on/off)
end)

RegisterNetEvent('sterix_police:bridge:client:playerLoaded', function()
    -- TODO: init anything that needs a loaded player
end)

RegisterNetEvent('sterix_police:bridge:client:playerUnloaded', function()
    -- TODO: cleanup
end)



local function getCoordsFromRaycast()
    lib.showTextUI('**[E]** to Confirm Location  \n**[Arrow Up/Down]** To Adjust Distance')
    local distance = 20.0
    local coords = vec3(0, 0, 0)
    repeat
        if IsControlJustPressed(0, 187) then distance -= 0.5 end
        if IsControlJustPressed(0, 188) then distance += 0.5 end

        _, _, coords = lib.raycast.fromCamera(511, 4, distance)

        ---@diagnostic disable-next-line: param-type-mismatch
        DrawMarker(28, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.2, 0.2, 0.2, 255, 0, 0, 100, false, false, 0, true, false, false, false)
        Wait(0)
    until IsControlJustPressed(0, 38)
    lib.hideTextUI()
    return coords
end

RegisterCommand('getcoords', function()
    local coords = getCoordsFromRaycast()
    if coords then
        local coordsString = ('vec3(%s, %s, %s)'):format(coords.x, coords.y, coords.z)
        print(('Coordinates: %s'):format(coordsString))
        lib.setClipboard(coordsString)
    end
end)