# FiveM Development Rules for Cursor

> Expert FiveM development assistant for QBox, QBCore, and ESX frameworks.
> Supports Lua scripting and NUI (JavaScript/TypeScript).

---

## Core Principles

1. **Always fetch latest docs** - Use web search for natives and framework APIs
2. **Framework-agnostic first** - Write portable code when possible
3. **Performance-first** - FiveM has strict tick budgets
4. **Server-side validation** - Never trust client data

---

## CRITICAL: No Hallucination Policy

**NEVER invent or guess native functions, framework APIs, or parameters.**

### Strict Rules:
1. **If unsure about a native** → Search `site:docs.fivem.net/natives {name}`
2. **If unsure about framework API** → Search official docs first
3. **If function doesn't exist** → Tell user honestly, suggest alternatives
4. **If parameters unknown** → Look up documentation, don't guess
5. **NEVER make up function names** → Only use verified APIs

### Before writing ANY native or API call, verify:
- Is this a real FiveM native? (check docs.fivem.net/natives)
- Is the function name spelled correctly?
- Are the parameters in correct order and type?
- Does this work on client/server/both?

### When uncertain, say:
"I'm not 100% certain about this native/API. Please verify at [doc link]"

### Verification Sources:
| Type | Verify At |
|------|-----------|
| Natives | docs.fivem.net/natives |
| QBox | docs.qbox.re |
| QBCore | docs.qbcore.org |
| ESX | docs.esx-framework.org |
| ox_lib | overextended.dev/ox_lib |
| Assets | forge.plebmasters.de |

### Example - WRONG (hallucination):
```lua
-- BAD: Made-up native that doesn't exist
SetPlayerInvincible(playerId, true)
EnableVehicleNitro(vehicle)
GetPlayerBankBalance(source)
```

### Example - RIGHT (verified):
```lua
-- GOOD: Real natives with correct parameters
SetEntityInvincible(PlayerPedId(), true)  -- Verified
SetVehicleBoostActive(vehicle, true)      -- Verified
-- Bank balance: Use framework API, not native
```

---

## Framework Detection

Check `fxmanifest.lua` for dependencies:
```lua
dependency 'qbx_core'    -- QBox
dependency 'qb-core'     -- QBCore
dependency 'es_extended' -- ESX
```

Check code imports:
```lua
-- QBox
local QBX = exports.qbx_core:GetCoreObject()

-- QBCore
local QBCore = exports['qb-core']:GetCoreObject()

-- ESX
local ESX = exports.es_extended:getSharedObject()
```

---

## Documentation Sources

When user asks about:
- **Native functions** → Search: `site:docs.fivem.net/natives {function_name}`
- **QBox API** → Search: `site:docs.qbox.re {topic}`
- **QBCore API** → Search: `site:docs.qbcore.org {topic}`
- **ESX API** → Search: `site:docs.esx-framework.org {topic}`
- **ox_lib** → Search: `site:overextended.dev/ox_lib {topic}`
- **Assets (props, vehicles, peds)** → Search: `site:forge.plebmasters.de {asset_name}`

---

## QBox Framework

```lua
local QBX = exports.qbx_core:GetCoreObject()

-- Player Data (Client)
local playerData = QBX.Functions.GetPlayerData()
playerData.citizenid
playerData.charinfo.firstname
playerData.money.cash
playerData.money.bank
playerData.job.name

-- Player Object (Server)
local player = QBX.Functions.GetPlayer(source)
player.Functions.GetMoney('cash')
player.Functions.AddMoney('cash', amount, reason)
player.Functions.RemoveMoney('cash', amount, reason)
player.PlayerData.citizenid

-- Callbacks (use ox_lib)
lib.callback.register('myresource:server:getData', function(source)
    return { data = 'value' }
end)

lib.callback('myresource:server:getData', false, function(result)
    print(result.data)
end)
```

---

## QBCore Framework

```lua
local QBCore = exports['qb-core']:GetCoreObject()

-- Player Data (Client)
local playerData = QBCore.Functions.GetPlayerData()
playerData.citizenid
playerData.charinfo.firstname
playerData.money['cash']
playerData.job.name

-- Player Object (Server)
local player = QBCore.Functions.GetPlayer(source)
player.Functions.GetMoney('cash')
player.Functions.AddMoney('cash', amount, reason)
player.Functions.RemoveMoney('cash', amount, reason)
player.PlayerData.citizenid

-- Callbacks
QBCore.Functions.CreateCallback('myresource:server:getData', function(source, cb)
    cb({ data = 'value' })
end)

QBCore.Functions.TriggerCallback('myresource:server:getData', function(result)
    print(result.data)
end)

-- Notifications
QBCore.Functions.Notify('Message', 'success', 5000)

-- Useable Items (Server)
QBCore.Functions.CreateUseableItem('itemname', function(source, item)
    local player = QBCore.Functions.GetPlayer(source)
    -- item logic
end)
```

---

## ESX Framework

```lua
local ESX = exports.es_extended:getSharedObject()

-- Player Data (Client)
local playerData = ESX.GetPlayerData()
playerData.identifier
playerData.job.name
playerData.accounts -- { bank, money, black_money }

-- xPlayer Object (Server)
local xPlayer = ESX.GetPlayerFromId(source)
xPlayer.getMoney()
xPlayer.getAccount('bank').money
xPlayer.addMoney(amount, reason)
xPlayer.removeMoney(amount, reason)
xPlayer.getJob()
xPlayer.setJob(name, grade)
xPlayer.getInventory()
xPlayer.addInventoryItem(item, count)
xPlayer.removeInventoryItem(item, count)

-- Callbacks
ESX.RegisterServerCallback('myresource:getData', function(source, cb)
    cb({ data = 'value' })
end)

ESX.TriggerServerCallback('myresource:getData', function(result)
    print(result.data)
end)

-- Notifications
ESX.ShowNotification('Message')

-- Useable Items (Server)
ESX.RegisterUsableItem('itemname', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    -- item logic
end)
```

---

## ox_lib (Utility Library)

```lua
-- fxmanifest.lua
shared_scripts { '@ox_lib/init.lua' }
dependencies { 'ox_lib' }

-- Callbacks
lib.callback.register('name', function(source, ...) return data end)
lib.callback('name', false, function(result) end)

-- Notifications
lib.notify({ title = 'Title', description = 'Text', type = 'success' })

-- Progress Bar
lib.progressBar({ duration = 5000, label = 'Loading...', canCancel = true })

-- Context Menu
lib.registerContext({
    id = 'my_menu',
    title = 'Menu Title',
    options = {
        { title = 'Option 1', onSelect = function() end },
        { title = 'Option 2', args = { data = 1 } }
    }
})
lib.showContext('my_menu')

-- Input Dialog
local input = lib.inputDialog('Title', {
    { type = 'input', label = 'Name' },
    { type = 'number', label = 'Amount' }
})

-- Target (interactions)
exports.ox_target:addBoxZone({
    coords = vec3(x, y, z),
    size = vec3(1, 1, 1),
    rotation = 0,
    options = {
        { name = 'interact', label = 'Interact', onSelect = function() end }
    }
})

-- Cache (auto-updated)
local ped = cache.ped
local coords = cache.coords
local vehicle = cache.vehicle
```

---

## fxmanifest.lua Template

```lua
fx_version 'cerulean'
game 'gta5'

author 'Your Name'
description 'Resource description'
version '1.0.0'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependencies {
    'ox_lib',
    'oxmysql',
    -- 'qbx_core' or 'qb-core' or 'es_extended'
}

-- NUI (if needed)
ui_page 'html/index.html'
files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}
```

---

## Client-Server Communication

```lua
-- Client → Server (no response)
TriggerServerEvent('myresource:server:doAction', data)

-- Server handler
RegisterNetEvent('myresource:server:doAction', function(data)
    local source = source
    -- validate & process
end)

-- Server → Client
TriggerClientEvent('myresource:client:notify', source, data)

-- Server → All Clients
TriggerClientEvent('myresource:client:notify', -1, data)

-- Client handler
RegisterNetEvent('myresource:client:notify', function(data)
    -- process
end)

-- With response: Use callbacks (ox_lib or framework callbacks)
```

---

## Thread Management & Performance

```lua
-- BAD: Burns CPU
CreateThread(function()
    while true do
        -- code
        Wait(0)  -- Every frame!
    end
end)

-- GOOD: Adaptive wait
CreateThread(function()
    while true do
        local sleep = 1000
        local coords = GetEntityCoords(cache.ped)

        for _, zone in ipairs(zones) do
            local dist = #(coords - zone.coords)
            if dist < 5.0 then
                sleep = 0
                handleZone(zone)
            elseif dist < 50.0 then
                sleep = math.min(sleep, 500)
            end
        end

        Wait(sleep)
    end
end)

-- BEST: Use ox_lib target instead of distance loops
exports.ox_target:addBoxZone({ ... })
```

### Performance Rules
- Avoid `Wait(0)` unless drawing or absolutely necessary
- Cache `PlayerPedId()`, coordinates (use `cache.ped`, `cache.coords`)
- Use ox_lib target for interactions (not distance checks)
- Use events/callbacks instead of polling
- Use statebags for state sync (not event spam)

---

## NUI (HTML/JS Interface)

### Lua → NUI
```lua
SendNUIMessage({ action = 'open', data = { ... } })
SetNuiFocus(true, true)  -- Enable mouse + keyboard
```

### NUI → Lua
```javascript
// JavaScript
fetch(`https://${GetParentResourceName()}/callback`, {
    method: 'POST',
    body: JSON.stringify({ action: 'submit', value: 123 })
});
```

```lua
-- Lua callback
RegisterNUICallback('callback', function(data, cb)
    if data.action == 'submit' then
        -- process data.value
    end
    cb('ok')
end)
```

### Close NUI
```lua
RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)
```

---

## Common Natives

```lua
-- Player
local ped = PlayerPedId()
local coords = GetEntityCoords(ped)
local heading = GetEntityHeading(ped)
local health = GetEntityHealth(ped)

-- Vehicle
local vehicle = GetVehiclePedIsIn(ped, false)
local plate = GetVehicleNumberPlateText(vehicle)
local speed = GetEntitySpeed(vehicle) * 3.6  -- km/h

-- Spawn Vehicle
local hash = GetHashKey('adder')
RequestModel(hash)
while not HasModelLoaded(hash) do Wait(10) end
local veh = CreateVehicle(hash, x, y, z, heading, true, false)
SetModelAsNoLongerNeeded(hash)

-- Spawn Ped
local hash = GetHashKey('a_m_y_hipster_01')
RequestModel(hash)
while not HasModelLoaded(hash) do Wait(10) end
local ped = CreatePed(4, hash, x, y, z, heading, true, true)
SetModelAsNoLongerNeeded(hash)

-- Spawn Object
local hash = GetHashKey('prop_laptop_01a')
RequestModel(hash)
while not HasModelLoaded(hash) do Wait(10) end
local obj = CreateObject(hash, x, y, z, true, true, true)
SetModelAsNoLongerNeeded(hash)

-- Draw Marker (needs Wait(0) loop)
DrawMarker(1, x, y, z, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, 255, 0, 0, 100, false, false, 2, false, nil, nil, false)

-- Draw 3D Text
SetTextScale(0.35, 0.35)
SetTextFont(4)
SetTextColour(255, 255, 255, 215)
SetTextEntry('STRING')
SetTextCentre(true)
AddTextComponentString(text)
SetDrawOrigin(x, y, z, 0)
DrawText(0.0, 0.0)
ClearDrawOrigin()
```

---

## Security Rules

1. **NEVER trust client data** - Always validate on server
2. **Use callbacks** - Not direct server events for sensitive operations
3. **Check permissions** - Verify player can perform action
4. **Rate limit** - Prevent spam/abuse
5. **Sanitize input** - Prevent injection

```lua
-- Server-side validation example
RegisterNetEvent('myresource:server:withdraw', function(amount)
    local source = source
    local player = QBCore.Functions.GetPlayer(source)

    -- Validate
    if type(amount) ~= 'number' then return end
    if amount <= 0 then return end
    if amount > player.Functions.GetMoney('bank') then return end

    -- Process
    player.Functions.RemoveMoney('bank', amount)
    player.Functions.AddMoney('cash', amount)
end)
```

---

## Anti-Patterns

| Don't | Do |
|-------|-----|
| `while true do Wait(0)` | Adaptive wait or events |
| Trust client data | Server-side validation |
| `TriggerServerEvent` for money | Callbacks with validation |
| Distance check loops | ox_lib target zones |
| Global variables | Local + encapsulation |
| Fetch data every frame | Cache with refresh interval |

---

## Resource Structure

```
resource_name/
├── fxmanifest.lua
├── config.lua
├── client/
│   └── main.lua
├── server/
│   └── main.lua
├── shared/
│   └── functions.lua
└── html/           # NUI (optional)
    ├── index.html
    ├── style.css
    └── script.js
```

---

## Framework-Agnostic Pattern

```lua
local Framework = {}

if GetResourceState('qbx_core') ~= 'missing' then
    Framework.Core = exports.qbx_core:GetCoreObject()
    Framework.Type = 'qbox'
elseif GetResourceState('qb-core') ~= 'missing' then
    Framework.Core = exports['qb-core']:GetCoreObject()
    Framework.Type = 'qbcore'
elseif GetResourceState('es_extended') ~= 'missing' then
    Framework.Core = exports.es_extended:getSharedObject()
    Framework.Type = 'esx'
end

function Framework.GetPlayerMoney(source)
    if Framework.Type == 'esx' then
        return Framework.Core.GetPlayerFromId(source).getMoney()
    else
        return Framework.Core.Functions.GetPlayer(source).Functions.GetMoney('cash')
    end
end

return Framework
```
