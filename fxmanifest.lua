fx_version 'cerulean'
game 'gta5'

description 'K-9 Script for QB'
version '1.0.0'

shared_script {
	'config.lua',
	'@qb-core/import.lua'
}

client_scripts {
	'client/client.lua'
}

server_script {
	'server/server.lua'
}

ui_page 'html/menu.html'

files {
	"html/menu.html",
	"html/style.css",
	"html/script.js",
	"html/*.png"
}
dependency 'qb-core'
