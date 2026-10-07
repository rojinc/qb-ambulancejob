fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'Kakarot'
description 'Player health, death, and wounding system with ems job'
version '1.3.0'

shared_scripts {
	'@qb-core/shared/locale.lua',
	'locales/en.lua',
	'locales/*.lua',
	'config.lua'
}

client_scripts {
	'@PolyZone/client.lua',
	'@PolyZone/BoxZone.lua',
	'@PolyZone/ComboZone.lua',
	'client/main.lua',
	'client/wounding.lua',
	'client/knockdown.lua',
	'client/laststand.lua',
	'client/crawl.lua',
	'client/job.lua',
	'client/dead.lua'
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'server/main.lua'
}

dependencies {
	'qb-core',
	'PolyZone',
	'oxmysql'
}
