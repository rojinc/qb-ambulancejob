# Lua Patterns for FiveM

> FiveM-specific Lua idioms and best practices

## Lua 5.4 Features

Enable in fxmanifest.lua:
```lua
lua54 'yes'
```

### Key Lua 5.4 Benefits
- `<const>` - Constant variables
- `<close>` - Auto-cleanup (like defer)
- Integer division `//`
- Better performance

```lua
-- Constants
local MAX_PLAYERS <const> = 64
local RESOURCE_NAME <const> = GetCurrentResourceName()

-- Close (auto-cleanup)
local file <close> = io.open('data.json')
-- File automatically closed when out of scope
```

---

## Variable Scoping

```lua
-- GOOD: Local variables
local function DoSomething()
    local data = {}
    return data
end

-- BAD: Global pollution
function DoSomething()  -- Implicitly global!
    data = {}           -- Implicitly global!
end

-- Module pattern
local MyModule = {}

function MyModule.PublicFunction()
end

local function privateFunction()
end

return MyModule
```

---

## Table Operations

```lua
-- Table creation
local t = {}
local t = { a = 1, b = 2 }
local t = { 'first', 'second', 'third' }

-- Safe access (nil check)
local value = t and t.nested and t.nested.deep
-- Or with Lua 5.4+
local value = t?.nested?.deep  -- Not in FiveM yet, use above

-- Table iteration
for key, value in pairs(t) do           -- All keys
    print(key, value)
end

for index, value in ipairs(t) do        -- Array (numeric keys 1..n)
    print(index, value)
end

-- Table length (arrays only)
local count = #t

-- Check if table is empty
local isEmpty = next(t) == nil
```

---

## String Operations

```lua
-- Concatenation (avoid in loops)
local str = 'Hello ' .. 'World'

-- Format (preferred)
local str = string.format('Player %s has %d money', name, amount)
local str = ('Player %s has %d money'):format(name, amount)

-- Pattern matching
local match = string.match(input, 'pattern')
local sub = string.sub(str, 1, 10)
local lower = string.lower(str)
local upper = string.upper(str)

-- Split string
local function split(str, sep)
    local result = {}
    for part in string.gmatch(str, '([^' .. sep .. ']+)') do
        result[#result + 1] = part
    end
    return result
end
```

---

## Nil Handling

```lua
-- Default values
local value = input or 'default'
local count = amount or 0

-- Nil check before access
if player and player.money then
    print(player.money.cash)
end

-- Safe function call
local function safeCall(fn, ...)
    if fn then return fn(...) end
end
```

---

## Functions

```lua
-- Named function
local function add(a, b)
    return a + b
end

-- Anonymous function
local multiply = function(a, b)
    return a * b
end

-- Variadic arguments
local function log(...)
    local args = {...}
    for i, v in ipairs(args) do
        print(v)
    end
end

-- Multiple returns
local function getPlayerInfo()
    return 'name', 100, true
end
local name, money, online = getPlayerInfo()

-- Closure
local function createCounter()
    local count = 0
    return function()
        count = count + 1
        return count
    end
end
```

---

## Error Handling

```lua
-- pcall for safe execution
local success, result = pcall(function()
    return riskyOperation()
end)

if success then
    print('Result:', result)
else
    print('Error:', result)
end

-- xpcall with error handler
local success, result = xpcall(function()
    return riskyOperation()
end, function(err)
    print('Error occurred:', err)
    print(debug.traceback())
end)

-- Assert
assert(player ~= nil, 'Player not found')
```

---

## FiveM-Specific Patterns

### Exports

```lua
-- Provide export (fxmanifest.lua)
exports {
    'GetPlayerMoney',
    'SetPlayerMoney'
}

-- Or in Lua
exports('GetPlayerMoney', function(source)
    return playerMoney[source]
end)

-- Use export
local money = exports.myresource:GetPlayerMoney(source)
local money = exports['my-resource']:GetPlayerMoney(source)
```

### Events

```lua
-- Register event
RegisterNetEvent('myresource:doSomething', function(data)
    local source = source  -- Capture source in server events
    print('Event from:', source)
end)

-- Trigger event
TriggerEvent('myresource:local', data)              -- Same script
TriggerServerEvent('myresource:server', data)       -- Client → Server
TriggerClientEvent('myresource:client', target, data)  -- Server → Client
TriggerClientEvent('myresource:client', -1, data)   -- Server → All clients
```

### Statebags

```lua
-- Set state (any side)
LocalPlayer.state:set('hunger', 100, true)  -- true = replicate
Entity(entity).state:set('owner', source, true)
GlobalState:set('serverTime', os.time(), true)

-- Get state
local hunger = LocalPlayer.state.hunger
local owner = Entity(entity).state.owner
local time = GlobalState.serverTime

-- Watch state changes
AddStateBagChangeHandler('hunger', nil, function(bagName, key, value)
    print(bagName, key, 'changed to', value)
end)
```

---

## JSON Handling

```lua
-- Encode
local jsonStr = json.encode({ name = 'John', age = 25 })

-- Decode
local data = json.decode(jsonStr)
print(data.name)

-- Safe decode
local success, data = pcall(json.decode, jsonStr)
if not success then
    print('Invalid JSON')
end
```

---

## Async Patterns

```lua
-- Promise-like with ox_lib
local p = promise.new()

-- Somewhere else
p:resolve(result)
-- or
p:reject(error)

-- Await result
local result = Citizen.Await(p)

-- Timeout pattern
local p = promise.new()
SetTimeout(5000, function()
    p:reject('timeout')
end)
```

---

## Performance Tips

```lua
-- Cache frequently used functions
local GetGameTimer = GetGameTimer
local Wait = Wait
local PlayerPedId = PlayerPedId

-- Avoid table creation in loops
local tempVec = vector3(0, 0, 0)  -- Reuse

-- Use local variables
local function heavyLoop()
    local ped = PlayerPedId()  -- Cache outside loop
    while true do
        -- Use cached ped
        Wait(0)
    end
end

-- String concat: use table.concat for many strings
local parts = {}
for i = 1, 1000 do
    parts[i] = 'item' .. i
end
local result = table.concat(parts, ', ')
```
