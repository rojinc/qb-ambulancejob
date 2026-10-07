# fxmanifest.lua Reference

> Resource manifest specification for FiveM

## Required Fields

```lua
fx_version 'cerulean'   -- Required: FiveM version target
game 'gta5'             -- Required: Target game

-- Metadata (recommended)
author 'Your Name'
description 'Resource description'
version '1.0.0'
repository 'https://github.com/user/repo'
```

## FX Versions

| Version | Features |
|---------|----------|
| `adamant` | Legacy |
| `bodacious` | Statebags |
| `cerulean` | Current stable (recommended) |

---

## Script Declarations

```lua
-- Client-only scripts
client_scripts {
    'client/main.lua',
    'client/modules/*.lua'  -- Glob pattern
}

-- Server-only scripts
server_scripts {
    '@oxmysql/lib/MySQL.lua',   -- External resource dependency
    'server/main.lua',
    'server/modules/*.lua'
}

-- Shared (both client & server)
shared_scripts {
    '@ox_lib/init.lua',         -- ox_lib initialization
    'config.lua',
    'shared/*.lua'
}

-- Single file alternative
client_script 'client.lua'
server_script 'server.lua'
shared_script 'config.lua'
```

---

## Dependencies

```lua
dependencies {
    'qbx_core',           -- Required resource
    'ox_lib',
    'ox_inventory',
    '/server:5104',       -- Minimum server version
    '/onesync'            -- Requires OneSync
}

-- Dependency on specific resource
dependency 'qb-core'

-- Soft dependency (won't error if missing)
-- Check in code: GetResourceState('optional_resource')
```

---

## File Declarations

```lua
-- Files accessible to client (NUI, data files)
files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/assets/*.png',
    'data/*.json',
    'locales/*.json'
}

-- Or single file
file 'data/items.json'
```

---

## NUI Setup

```lua
ui_page 'html/index.html'

-- Alternative: External URL (development)
-- ui_page 'http://localhost:3000'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}
```

---

## Lua 5.4

```lua
lua54 'yes'  -- Enable Lua 5.4 features

-- Benefits:
-- - <const> keyword
-- - <close> variables
-- - Better performance
-- - Integer division //
```

---

## Exports

```lua
-- Declare exports for other resources
exports {
    'GetPlayerData',
    'SetPlayerData',
    'AddItem',
    'RemoveItem'
}

-- Server-only exports
server_exports {
    'GetPlayer',
    'CreatePlayer'
}
```

---

## Data Files

```lua
-- DLC data files
data_file 'WEAPONINFO_FILE' 'data/weapons.meta'
data_file 'VEHICLE_METADATA_FILE' 'data/vehicles.meta'
data_file 'HANDLING_FILE' 'data/handling.meta'
data_file 'CARCOLS_FILE' 'data/carcols.meta'
data_file 'CARMOD_FILE' 'data/carvariations.meta'
data_file 'PED_METADATA_FILE' 'data/peds.meta'
```

---

## Loadscreen

```lua
loadscreen 'html/loadscreen.html'

files {
    'html/loadscreen.html',
    'html/loadscreen.css',
    'html/loadscreen.js'
}

loadscreen_manual_shutdown 'yes'  -- Control when to hide
loadscreen_cursor 'yes'           -- Show cursor on loadscreen
```

---

## Complete Example

```lua
fx_version 'cerulean'
game 'gta5'

author 'YourName'
description 'My awesome resource'
version '1.0.0'

lua54 'yes'

dependencies {
    'ox_lib',
    'ox_inventory',
    'qbx_core'
}

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua'
}

client_scripts {
    'client/main.lua',
    'client/modules/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/modules/*.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/assets/*.png',
    'locales/*.json'
}

exports {
    'GetData',
    'SetData'
}

server_exports {
    'GetServerData'
}
```

---

## Resource Structure

```
my_resource/
├── fxmanifest.lua          # Manifest
├── README.md               # Documentation
│
├── shared/
│   └── config.lua          # Shared configuration
│
├── client/
│   ├── main.lua            # Client entry point
│   └── modules/
│       ├── ui.lua
│       └── events.lua
│
├── server/
│   ├── main.lua            # Server entry point
│   └── modules/
│       ├── database.lua
│       └── events.lua
│
├── html/                   # NUI files
│   ├── index.html
│   ├── style.css
│   └── script.js
│
├── data/                   # Data files
│   └── items.json
│
└── locales/                # Translations
    ├── en.json
    └── tr.json
```

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Missing `fx_version` | Add `fx_version 'cerulean'` |
| Wrong game | Use `game 'gta5'` for GTA V |
| File not found | Check path and add to `files {}` |
| Dependency not loading | Check resource name, ensure it's started |
| Script order issues | Put dependencies first in script lists |
| NUI not showing | Check `ui_page` path, add files to `files {}` |
