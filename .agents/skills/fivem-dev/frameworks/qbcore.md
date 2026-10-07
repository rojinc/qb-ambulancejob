# QBCore Framework Reference

> Popular roleplay framework for FiveM

**Documentation:** https://docs.qbcore.org/qbcore-documentation/

## Core Access

```lua
-- Client & Server
local QBCore = exports['qb-core']:GetCoreObject()

-- Alternative (legacy)
local QBCore = nil
TriggerEvent('QBCore:GetObject', function(obj) QBCore = obj end)
```

---

## Player Data (Client)

```lua
local QBCore = exports['qb-core']:GetCoreObject()

-- Get player data
local PlayerData = QBCore.Functions.GetPlayerData()

-- Properties
PlayerData.citizenid      -- Unique character ID
PlayerData.charinfo       -- { firstname, lastname, birthdate, gender, etc. }
PlayerData.job            -- { name, label, grade, isboss, etc. }
PlayerData.gang           -- { name, label, grade, isboss }
PlayerData.money          -- { cash, bank, crypto }
PlayerData.metadata       -- { hunger, thirst, stress, etc. }
PlayerData.items          -- Inventory items
```

---

## Player Functions (Server)

```lua
local QBCore = exports['qb-core']:GetCoreObject()

-- Get player object
local Player = QBCore.Functions.GetPlayer(source)

-- Money
Player.Functions.GetMoney('cash')
Player.Functions.GetMoney('bank')
Player.Functions.AddMoney('cash', amount, 'reason')
Player.Functions.RemoveMoney('cash', amount, 'reason')
Player.Functions.SetMoney('cash', amount, 'reason')

-- Job
Player.Functions.SetJob('police', 0)  -- name, grade
Player.Functions.GetJob()             -- returns job table

-- Gang
Player.Functions.SetGang('ballas', 0)
Player.Functions.GetGang()

-- Inventory
Player.Functions.AddItem('item_name', count, slot, info)
Player.Functions.RemoveItem('item_name', count, slot)
Player.Functions.GetItemByName('item_name')
Player.Functions.GetItemsByName('item_name')  -- all stacks
Player.Functions.HasItem('item_name', amount)

-- Metadata
Player.Functions.SetMetaData('hunger', 100)
Player.Functions.GetMetaData('hunger')
```

---

## Callbacks

```lua
-- Server: Create callback
QBCore.Functions.CreateCallback('myresource:server:getData', function(source, cb, arg1)
    local Player = QBCore.Functions.GetPlayer(source)
    cb({
        money = Player.Functions.GetMoney('cash'),
        job = Player.Functions.GetJob()
    })
end)

-- Client: Trigger callback
QBCore.Functions.TriggerCallback('myresource:server:getData', function(result)
    print('Money:', result.money)
    print('Job:', result.job.name)
end, arg1)
```

---

## Events

### Player Events (Client)
```lua
-- Player loaded
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    local PlayerData = QBCore.Functions.GetPlayerData()
    print('Loaded as:', PlayerData.charinfo.firstname)
end)

-- Player unloaded (logout/switch char)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    -- Cleanup
end)

-- Job updated
RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    print('New job:', job.name, job.grade.name)
end)

-- Gang updated
RegisterNetEvent('QBCore:Client:OnGangUpdate', function(gang)
    print('New gang:', gang.name)
end)

-- Money updated
RegisterNetEvent('QBCore:Client:OnMoneyChange', function(moneyType, amount, action)
    print(action, amount, moneyType)  -- "add" 500 "cash"
end)
```

### Player Events (Server)
```lua
-- Player loaded
RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local Player = QBCore.Functions.GetPlayer(source)
end)

-- Player quit
AddEventHandler('QBCore:Server:PlayerDropped', function(Player, Reason)
    print(Player.PlayerData.citizenid, 'left:', Reason)
end)
```

---

## Notifications

```lua
-- Client
QBCore.Functions.Notify('Message here', 'success', 5000)
-- Types: 'success', 'primary', 'error', 'warning', 'info'

-- Server (to specific player)
TriggerClientEvent('QBCore:Notify', source, 'Message', 'success', 5000)
```

---

## Utility Functions

```lua
-- Client
QBCore.Functions.GetCoords(entity)
QBCore.Functions.GetPlate(vehicle)
QBCore.Functions.SpawnVehicle(model, cb, coords, isnetworked)
QBCore.Functions.DeleteVehicle(vehicle)
QBCore.Functions.Progressbar(name, label, duration, useWhileDead, canCancel, disableControls, animation, prop, propTwo, onFinish, onCancel)

-- Server
QBCore.Functions.GetPlayers()
QBCore.Functions.GetPlayerByCitizenId(citizenid)
QBCore.Functions.GetPlayerByPhone(phone)
QBCore.Functions.GetQBPlayers()  -- All QBCore player objects
QBCore.Functions.CreateUseableItem(name, cb)
QBCore.Functions.GetDutyCount('police')
```

---

## Useable Items (Server)

```lua
QBCore.Functions.CreateUseableItem('bandage', function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player.Functions.RemoveItem('bandage', 1) then
        TriggerClientEvent('hospital:client:HealPlayer', source)
    end
end)
```

---

## Required Setup

```lua
-- fxmanifest.lua
dependencies {
    'qb-core'
}

shared_scripts {
    '@qb-core/shared/locale.lua'
}
```

---

## Fetch Latest Docs

For the most current QBCore documentation:
```
WebFetch(
    url: "https://docs.qbcore.org/qbcore-documentation/",
    prompt: "Find {SPECIFIC_TOPIC} documentation"
)
```
