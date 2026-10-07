# ESX Legacy Framework Reference

> Established roleplay framework with extensive addon ecosystem

**Documentation:** https://docs.esx-framework.org/

## Core Access

```lua
-- Modern (recommended)
local ESX = exports.es_extended:getSharedObject()

-- Legacy callback pattern
ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- With imports (es_extended v1.9+)
-- Add to fxmanifest: shared_script '@es_extended/imports.lua'
```

---

## Player Data (Client)

```lua
local ESX = exports.es_extended:getSharedObject()

-- Get player data
local PlayerData = ESX.GetPlayerData()

-- Properties
PlayerData.identifier     -- Unique player identifier
PlayerData.accounts       -- { bank, money, black_money }
PlayerData.coords         -- Player position
PlayerData.job            -- { name, label, grade, grade_name, grade_salary }
PlayerData.loadout        -- Weapons
PlayerData.inventory      -- Items
PlayerData.maxWeight      -- Inventory weight limit
```

---

## xPlayer Object (Server)

```lua
local ESX = exports.es_extended:getSharedObject()

-- Get xPlayer object
local xPlayer = ESX.GetPlayerFromId(source)

-- Money operations
xPlayer.getMoney()                    -- Cash
xPlayer.getAccount('bank').money      -- Bank balance
xPlayer.getAccount('black_money').money

xPlayer.addMoney(amount, reason)
xPlayer.removeMoney(amount, reason)
xPlayer.setMoney(amount, reason)

xPlayer.addAccountMoney('bank', amount, reason)
xPlayer.removeAccountMoney('bank', amount, reason)
xPlayer.setAccountMoney('bank', amount, reason)

-- Job
xPlayer.getJob()                      -- Returns job table
xPlayer.setJob(name, grade)

-- Inventory
xPlayer.getInventory()
xPlayer.getInventoryItem(itemName)
xPlayer.addInventoryItem(itemName, count)
xPlayer.removeInventoryItem(itemName, count)
xPlayer.setInventoryItem(itemName, count)
xPlayer.canCarryItem(itemName, count)
xPlayer.canSwapItem(item1, count1, item2, count2)

-- Weapons
xPlayer.addWeapon(weaponName, ammo)
xPlayer.removeWeapon(weaponName)
xPlayer.addWeaponComponent(weaponName, componentName)
xPlayer.addWeaponAmmo(weaponName, ammo)
xPlayer.hasWeapon(weaponName)
xPlayer.getWeapon(weaponName)

-- Other
xPlayer.getName()
xPlayer.setName(newName)
xPlayer.kick(reason)
xPlayer.setCoords(x, y, z)
xPlayer.getCoords(useVector)
xPlayer.getIdentifier()
xPlayer.getGroup()                    -- Admin level
```

---

## Callbacks

```lua
-- Server: Register callback
ESX.RegisterServerCallback('myresource:getData', function(source, cb, arg1)
    local xPlayer = ESX.GetPlayerFromId(source)
    cb({
        money = xPlayer.getMoney(),
        job = xPlayer.getJob()
    })
end)

-- Client: Trigger callback
ESX.TriggerServerCallback('myresource:getData', function(result)
    print('Money:', result.money)
    print('Job:', result.job.name)
end, arg1)
```

---

## Events

### Player Events (Client)
```lua
-- Player loaded
RegisterNetEvent('esx:playerLoaded', function(xPlayer, isNew, skin)
    local PlayerData = ESX.GetPlayerData()
    print('Loaded:', PlayerData.identifier)
end)

-- Job changed
RegisterNetEvent('esx:setJob', function(job, lastJob)
    print('Job changed from', lastJob.name, 'to', job.name)
end)

-- Account changed (money)
RegisterNetEvent('esx:setAccountMoney', function(account)
    print(account.name, 'updated to', account.money)
end)

-- Player death
AddEventHandler('esx:onPlayerDeath', function(data)
    print('Player died')
end)
```

### Player Events (Server)
```lua
-- Player loaded
RegisterNetEvent('esx:playerLoaded', function(playerId, xPlayer, isNew)
    print(xPlayer.getName(), 'connected')
end)

-- Player dropped
AddEventHandler('esx:playerDropped', function(playerId, reason)
    print('Player', playerId, 'left:', reason)
end)
```

---

## Notifications

```lua
-- Client
ESX.ShowNotification('Message here')
ESX.ShowAdvancedNotification('Title', 'Subtitle', 'Message', 'CHAR_BANK_MAZE', 1)
ESX.ShowHelpNotification('Press ~INPUT_CONTEXT~ to interact')

-- Server (to specific player)
TriggerClientEvent('esx:showNotification', source, 'Message')
```

---

## UI Elements (Client)

```lua
-- Text UI
ESX.TextUI('Press [E] to open')
ESX.HideUI()

-- Progress bar
ESX.Progressbar('Searching...', 5000, {
    FreezePlayer = true,
    animation = {
        type = 'anim',
        dict = 'anim@mp_player_intmenu@key_fob@',
        lib = 'fob_click'
    }
}, function()  -- onFinish
    print('Done!')
end, function()  -- onCancel
    print('Cancelled')
end)
```

---

## Utility Functions

```lua
-- Client
ESX.Game.GetPedMugshot(ped, transparent)
ESX.Game.GetVehicleInDirection()
ESX.Game.GetClosestVehicle(coords)
ESX.Game.GetClosestPed(coords)
ESX.Game.GetClosestPlayer(coords)
ESX.Game.GetPlayersInArea(coords, radius)
ESX.Game.GetVehiclesInArea(coords, radius)
ESX.Game.SpawnVehicle(model, coords, heading, cb)
ESX.Game.SpawnLocalVehicle(model, coords, heading, cb)
ESX.Game.DeleteVehicle(vehicle)
ESX.Game.SetVehicleProperties(vehicle, props)
ESX.Game.GetVehicleProperties(vehicle)
ESX.Game.Teleport(entity, coords, cb)

-- Server
ESX.GetPlayers()                      -- All player IDs
ESX.GetExtendedPlayers(key, val)      -- Filter by job, etc.
ESX.GetPlayerFromIdentifier(identifier)
ESX.GetPlayerFromCitizenId(citizenid)
ESX.RegisterUsableItem(itemName, cb)
ESX.CreatePickup(type, name, count, label, playerId, components, tintIndex)
ESX.OneSync.GetPlayersInArea(coords, radius)
ESX.OneSync.GetClosestPlayer(coords)
```

---

## Useable Items (Server)

```lua
ESX.RegisterUsableItem('bandage', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer.getInventoryItem('bandage').count > 0 then
        xPlayer.removeInventoryItem('bandage', 1)
        TriggerClientEvent('hospital:heal', source)
    end
end)
```

---

## Required Setup

```lua
-- fxmanifest.lua
dependencies {
    'es_extended'
}

shared_scripts {
    '@es_extended/imports.lua'  -- Optional, enables ESX object access
}
```

---

## Fetch Latest Docs

For the most current ESX documentation:
```
WebFetch(
    url: "https://docs.esx-framework.org/",
    prompt: "Find {SPECIFIC_TOPIC} documentation"
)
```
