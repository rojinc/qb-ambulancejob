# QBox Framework Reference

> Modern successor to QBCore with ox_lib integration

**Documentation:** https://docs.qbox.re/

## Core Access


---

## Key Differences from QBCore

| Feature | QBCore | QBox |
|---------|--------|------|
| Resource name | `qb-core` | `qbx_core` |
| Core access | `exports['qb-core']:GetCoreObject()` |
| Inventory | qb-inventory | ox_inventory (required) |
| Utilities | Built-in | ox_lib (required) |
| Callbacks | QBCore.Functions.CreateCallback | lib.callback |
| Notifications | QBCore.Functions.Notify | lib.notify |
| Menus | qb-menu | ox_lib context/menu |

---

## Player Data (Client)

```lua

-- Get player data
local PlayerData = QBX.Functions.GetPlayerData()

-- Common properties
PlayerData.citizenid      -- Unique character ID
PlayerData.charinfo       -- Name, birthdate, etc.
PlayerData.job            -- Current job
PlayerData.gang           -- Gang info
PlayerData.money          -- Money table
PlayerData.metadata       -- Additional data
```

---

## Player Functions (Server)

```lua

-- Get player object
local Player = QBX.Functions.GetPlayer(source)

-- Money operations
Player.Functions.GetMoney('cash')
Player.Functions.GetMoney('bank')
Player.Functions.AddMoney('cash', amount, reason)
Player.Functions.RemoveMoney('cash', amount, reason)

-- Job operations
Player.Functions.SetJob(name, grade)
Player.Functions.GetJob()

-- Inventory (via ox_inventory)
exports.ox_inventory:GetItem(source, 'item_name')
exports.ox_inventory:AddItem(source, 'item_name', count)
exports.ox_inventory:RemoveItem(source, 'item_name', count)
```

---

## Callbacks (ox_lib)

```lua
-- Server: Register callback
lib.callback.register('myresource:getData', function(source, arg1, arg2)
    local Player = QBX.Functions.GetPlayer(source)
    return { money = Player.Functions.GetMoney('cash') }
end)

-- Client: Call callback
lib.callback('myresource:getData', false, function(result)
    print(result.money)
end, arg1, arg2)

-- Client: Await callback (recommended)
local result = lib.callback.await('myresource:getData', false, arg1, arg2)
print(result.money)
```

---

## Events

### Player Events
```lua
-- Player loaded (client)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    -- Player is ready
end)

-- Player loaded (server)
RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local Player = QBX.Functions.GetPlayer(source)
end)

-- Job updated
RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    print('New job:', job.name)
end)
```

---

## Notifications (ox_lib)

```lua
-- Client
lib.notify({
    title = 'Success',
    description = 'Action completed',
    type = 'success',  -- success, error, warning, info
    duration = 5000,
    position = 'top'
})

-- Server (to specific player)
TriggerClientEvent('ox_lib:notify', source, {
    title = 'Error',
    description = 'Something went wrong',
    type = 'error'
})
```

---

## Common Exports

```lua
-- Get all players
local players = QBX.Functions.GetPlayers()

-- Get player by citizen ID
local Player = QBX.Functions.GetPlayerByCitizenId(citizenid)

-- Get players with specific job
local cops = QBX.Functions.GetPlayersOnDuty('police')

-- Check if player online
local online = QBX.Functions.IsPlayerOnline(identifier)
```

---

## Required Dependencies

```lua
-- fxmanifest.lua
dependencies {
    'qbx_core',
    'ox_lib',
    'ox_inventory'
}

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/import.lua'
}
```

---

## Fetch Latest Docs

For the most current QBox documentation:
```
WebFetch(
    url: "https://docs.qbox.re/",
    prompt: "Find {SPECIFIC_TOPIC} documentation"
)
```
