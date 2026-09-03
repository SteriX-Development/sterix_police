--[[
    server/main.lua

    Entry point for the police script's server-side logic. `Bridge` is
    already populated by this point (bridge/*.lua load before this file in
    fxmanifest.lua) - use Bridge.* for anything framework/inventory related
    instead of calling qbx_core/qb-core/es_extended/ox_inventory etc.
    directly, so the rest of the script stays framework agnostic.
]]

CreateThread(function()
    if Config.Debug then
        print(('[sterix_police] server loaded, framework detected: %s'):format(Bridge.Framework or 'none'))
    end
end)
