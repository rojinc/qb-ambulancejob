# Client-Server Architecture

> Communication patterns between client and server in FiveM

## Architecture Overview

```
┌─────────────────┐         ┌─────────────────┐
│     CLIENT      │         │     SERVER      │
│   (Per Player)  │◄───────►│   (Authoritative)
│                 │ Events  │                 │
│ - Rendering     │ Exports │ - Data storage  │
│ - Input         │ States  │ - Validation    │
│ - Local state   │         │ - Game logic    │
└─────────────────┘         └─────────────────┘
```

## Golden Rules

1. **Server is authoritative** - Never trust client data
2. **Validate everything** - Check permissions, amounts, distances
3. **Minimize traffic** - Send only necessary data
4. **Use appropriate method** - Events vs Exports vs Statebags

---

## Events

### Client → Server
```lua
-- Client
TriggerServerEvent('myresource:server:buyItem', itemId, amount)

-- Server
RegisterNetEvent('myresource:server:buyItem', function(itemId, amount)
    local source = source  -- Always capture source first!

    -- Validate
    if type(itemId) ~= 'string' or type(amount) ~= 'number' then
        return print('Invalid data from', source)
    end

    if amount < 1 or amount > 100 then
        return print('Invalid amount from', source)
    end

    -- Process purchase
    processPurchase(source, itemId, amount)
end)
```

### Server → Client
```lua
-- Server to specific client
TriggerClientEvent('myresource:client:updateInventory', source, inventory)

-- Server to all clients
TriggerClientEvent('myresource:client:announcement', -1, message)

-- Client handler
RegisterNetEvent('myresource:client:updateInventory', function(inventory)
    -- Update local state
    PlayerInventory = inventory
    refreshUI()
end)
```

### Latent Events (Large Data)
```lua
-- For large payloads (inventory sync, etc.)
-- Server
TriggerLatentClientEvent('myresource:client:syncData', source, 50000, largeData)
-- 50000 = bytes per second rate limit

-- Client
TriggerLatentServerEvent('myresource:server:uploadData', 50000, largeData)
```

---

## Callbacks

### QBCore Style
```lua
-- Server
QBCore.Functions.CreateCallback('myresource:server:getShopItems', function(source, cb, shopId)
    local items = GetShopItems(shopId)
    cb(items)
end)

-- Client
QBCore.Functions.TriggerCallback('myresource:server:getShopItems', function(items)
    OpenShopUI(items)
end, shopId)
```

### ox_lib Style (Recommended)
```lua
-- Server
lib.callback.register('myresource:server:getShopItems', function(source, shopId)
    return GetShopItems(shopId)
end)

-- Client (callback)
lib.callback('myresource:server:getShopItems', false, function(items)
    OpenShopUI(items)
end, shopId)

-- Client (await - cleaner)
local items = lib.callback.await('myresource:server:getShopItems', false, shopId)
OpenShopUI(items)
```

### ESX Style
```lua
-- Server
ESX.RegisterServerCallback('myresource:getShopItems', function(source, cb, shopId)
    local items = GetShopItems(shopId)
    cb(items)
end)

-- Client
ESX.TriggerServerCallback('myresource:getShopItems', function(items)
    OpenShopUI(items)
end, shopId)
```

---

## Statebags (State Synchronization)

### Player State
```lua
-- Server: Set player state
Player(source).state:set('duty', true, true)  -- true = replicated

-- Client: Read own state
local onDuty = LocalPlayer.state.duty

-- Any side: Watch changes
AddStateBagChangeHandler('duty', nil, function(bagName, key, value, reserved, replicated)
    if bagName:find('player:') then
        local playerId = tonumber(bagName:match('player:(%d+)'))
        print('Player', playerId, 'duty changed to', value)
    end
end)
```

### Entity State
```lua
-- Server: Set entity state
local vehicle = GetVehiclePedIsIn(GetPlayerPed(source), false)
Entity(vehicle).state:set('owner', source, true)
Entity(vehicle).state:set('locked', false, true)

-- Client: Read entity state
local netId = NetworkGetNetworkIdFromEntity(vehicle)
local owner = Entity(vehicle).state.owner
```

### Global State
```lua
-- Server: Set global state
GlobalState:set('weatherType', 'RAIN', true)
GlobalState:set('serverTime', os.time(), true)

-- Any side: Read global state
local weather = GlobalState.weatherType
```

---

## Exports (Cross-Resource)

### Providing Exports
```lua
-- fxmanifest.lua
exports {
    'GetPlayerMoney',
    'AddPlayerMoney'
}

-- server/main.lua
function GetPlayerMoney(source)
    return playerData[source].money
end

function AddPlayerMoney(source, amount)
    playerData[source].money = playerData[source].money + amount
    return true
end

-- Or define inline
exports('GetPlayerMoney', function(source)
    return playerData[source].money
end)
```

### Using Exports
```lua
-- From another resource
local money = exports.myresource:GetPlayerMoney(source)
local success = exports['my-resource']:AddPlayerMoney(source, 500)
```

---

## Security Patterns

### Server-Side Validation
```lua
RegisterNetEvent('shop:server:purchase', function(itemId, quantity)
    local source = source
    local Player = QBCore.Functions.GetPlayer(source)

    -- 1. Validate input types
    if type(itemId) ~= 'string' or type(quantity) ~= 'number' then
        return DropPlayer(source, 'Invalid request')
    end

    -- 2. Validate item exists
    local item = Config.Items[itemId]
    if not item then
        return print('Invalid item:', itemId)
    end

    -- 3. Validate quantity
    if quantity < 1 or quantity > item.maxPurchase then
        return print('Invalid quantity')
    end

    -- 4. Check player can afford
    local totalCost = item.price * quantity
    if Player.Functions.GetMoney('cash') < totalCost then
        return TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            description = 'Not enough money'
        })
    end

    -- 5. Check inventory space
    if not exports.ox_inventory:CanCarryItem(source, itemId, quantity) then
        return TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            description = 'Inventory full'
        })
    end

    -- 6. Process transaction
    Player.Functions.RemoveMoney('cash', totalCost, 'shop-purchase')
    exports.ox_inventory:AddItem(source, itemId, quantity)
end)
```

### Rate Limiting
```lua
local cooldowns = {}

RegisterNetEvent('myresource:action', function()
    local source = source
    local now = GetGameTimer()

    if cooldowns[source] and now - cooldowns[source] < 1000 then
        return print('Rate limited:', source)
    end

    cooldowns[source] = now
    -- Process action
end)
```

### Distance Validation
```lua
RegisterNetEvent('atm:server:withdraw', function(atmCoords, amount)
    local source = source
    local playerPed = GetPlayerPed(source)
    local playerCoords = GetEntityCoords(playerPed)

    -- Check player is near ATM
    if #(playerCoords - atmCoords) > 3.0 then
        return print('Player too far from ATM:', source)
    end

    -- Process withdrawal
end)
```

---

## Communication Flow Examples

### Shop Purchase Flow
```
1. Client: Player opens shop UI
   └─► lib.callback.await('shop:getItems', shopId)

2. Server: Returns shop items
   └─► return Config.Shops[shopId].items

3. Client: Player selects item
   └─► TriggerServerEvent('shop:purchase', itemId, qty)

4. Server: Validates & processes
   └─► Checks money, inventory, processes
   └─► TriggerClientEvent('shop:purchaseResult', source, success)

5. Client: Shows result
   └─► lib.notify success/error
```

### Real-time Sync Flow
```
1. Server: State changes
   └─► GlobalState:set('activeEvent', eventData, true)

2. All Clients: Receive state
   └─► AddStateBagChangeHandler watches for changes
   └─► Updates local UI/state automatically
```
