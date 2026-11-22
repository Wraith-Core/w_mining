fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'w_mining'
author 'Wraith Studio'
version '1.0.0'
description 'Mining camps, wild rock extraction, ore crushing, gold washing, and smelting furnaces built with w_lib for Wraith Framework RedM'
license 'GPL-3.0'
repository 'https://github.com/Wraith-Core/w_mining'

dependencies {
    'w_lib',
    'w_core',
    'w_inventory',
}

shared_scripts {
    '@w_lib/init.lua',
    'shared/contract.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

files {
    'locales/*.json',
}

w_lib {
    'locale',
}
