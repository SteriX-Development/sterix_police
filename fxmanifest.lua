fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sterix_police'
author 'Sterix'
description 'Sterix Police - QBX / QBCore / ESX compatible police job script'
version '0.0.1'

dependencies {
    'ox_lib',
    'oxmysql',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config/config.lua',
    'config/locations/*.lua',
    'shared/duty.lua',
}

client_scripts {
    -- framework-agnostic bridge (notify/progress/input/target via ox_lib + ox_target/qb-target)
    'bridge/client.lua',

    -- framework specific bridges, each self-guards and only loads for the framework that is running
    'bridge/qbx/client.lua',
    'bridge/qb/client.lua',
    'bridge/esx/client.lua',

    'client/main.lua',
    'client/addons/armory.lua',
    --- Duty
    'client/addons/duty/menu.lua',
    'client/addons/duty/duty.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',

    'bridge/server.lua',

    'bridge/qbx/server.lua',
    'bridge/qb/server.lua',
    'bridge/esx/server.lua',

    -- duty tracking engine must load before the boss module (which calls into it)
    'server/addons/duty/tracking.lua',
    'server/addons/duty/boss.lua',

    'server/main.lua',
}
