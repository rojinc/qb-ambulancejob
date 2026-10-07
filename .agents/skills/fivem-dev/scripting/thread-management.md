# Thread Management & Performance

> Citizen threads, performance optimization, and tick budgets in FiveM

## Understanding FiveM Threads

FiveM uses Citizen threads (coroutines) for async operations:

```lua
-- Create a thread
CreateThread(function()
    while true do
        -- Game loop
        Wait(0)  -- Yield to game (0 = every frame)
    end
end)

-- Alternative syntax
Citizen.CreateThread(function()
    -- Same as above
end)
```

---

## Wait() - The Most Important Function

```lua
Wait(ms)  -- Pause thread for ms milliseconds

-- Common values
Wait(0)     -- Every frame (~16ms at 60fps) - USE SPARINGLY
Wait(1)     -- Still very fast, slightly better
Wait(100)   -- 10 times per second - Good for most checks
Wait(500)   -- Twice per second - Good for UI updates
Wait(1000)  -- Once per second - Good for periodic tasks
Wait(5000)  -- Every 5 seconds - Good for background tasks
```

### Wait(0) Anti-Pattern
```lua
-- BAD: Unnecessary frame-by-frame check
CreateThread(function()
    while true do
        if IsControlJustPressed(0, 38) then  -- E key
            doAction()
        end
        Wait(0)  -- Every frame!
    end
end)

-- GOOD: Use keybind instead
RegisterKeyMapping('myaction', 'Do Action', 'keyboard', 'e')
RegisterCommand('myaction', function()
    doAction()
end, false)
```

---

## Adaptive Wait Pattern

```lua
-- Increase wait time when nothing is happening
CreateThread(function()
    while true do
        local sleep = 1000  -- Default: check every second

        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)

        for _, zone in ipairs(zones) do
            local distance = #(coords - zone.coords)

            if distance < 5.0 then
                -- In zone - need frequent updates
                sleep = 0
                handleZone(zone)
            elseif distance < 50.0 then
                -- Near zone - moderate checks
                sleep = math.min(sleep, 500)
            end
        end

        Wait(sleep)
    end
end)
```

---

## Distance-Based Optimization

```lua
-- Instead of checking all markers every frame
local markers = {}

CreateThread(function()
    while true do
        local playerCoords = GetEntityCoords(PlayerPedId())
        local nearestDist = math.huge

        for _, marker in ipairs(markers) do
            local dist = #(playerCoords - marker.coords)

            if dist < marker.drawDistance then
                DrawMarker(marker.type, marker.coords.x, marker.coords.y, marker.coords.z, ...)
            end

            if dist < nearestDist then
                nearestDist = dist
            end
        end

        -- Adaptive sleep based on nearest marker
        if nearestDist > 100.0 then
            Wait(1000)
        elseif nearestDist > 50.0 then
            Wait(500)
        elseif nearestDist > 20.0 then
            Wait(100)
        else
            Wait(0)  -- Only when very close
        end
    end
end)
```

---

## ox_lib Target vs Distance Checks

```lua
-- BAD: Manual distance check every frame
CreateThread(function()
    while true do
        local coords = GetEntityCoords(PlayerPedId())
        if #(coords - atmCoords) < 2.0 then
            DrawText3D(...)
            if IsControlJustPressed(0, 38) then
                openATM()
            end
        end
        Wait(0)
    end
end)

-- GOOD: ox_lib target (zone-based, optimized)
exports.ox_target:addBoxZone({
    coords = atmCoords,
    size = vec3(1, 1, 2),
    rotation = 0,
    options = {
        {
            name = 'atm_access',
            icon = 'fa-solid fa-money-bill',
            label = 'Access ATM',
            onSelect = function()
                openATM()
            end
        }
    }
})
```

---

## Caching

```lua
-- Cache frequently accessed values
local cache = {
    ped = nil,
    coords = nil,
    vehicle = nil,
    lastUpdate = 0
}

local function updateCache()
    cache.ped = PlayerPedId()
    cache.coords = GetEntityCoords(cache.ped)
    cache.vehicle = GetVehiclePedIsIn(cache.ped, false)
    cache.lastUpdate = GetGameTimer()
end

-- Update cache periodically
CreateThread(function()
    while true do
        updateCache()
        Wait(100)  -- Update 10 times per second
    end
end)

-- Use cached values everywhere
local function doSomething()
    local ped = cache.ped
    local coords = cache.coords
    -- Much faster than calling natives repeatedly
end
```

### ox_lib Cache (Built-in)
```lua
-- ox_lib provides automatic caching
local ped = cache.ped        -- Cached player ped
local coords = cache.coords  -- Cached coords
local vehicle = cache.vehicle or false  -- Current vehicle
local seat = cache.seat      -- Current seat index
local weapon = cache.weapon  -- Current weapon

-- These are automatically updated by ox_lib
```

---

## Thread Cleanup

```lua
local threadRunning = true

CreateThread(function()
    while threadRunning do
        -- Loop code
        Wait(100)
    end
end)

-- To stop the thread
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        threadRunning = false
    end
end)

-- Or for conditional threads
local menuOpen = false

local function startMenuThread()
    if menuOpen then return end
    menuOpen = true

    CreateThread(function()
        while menuOpen do
            -- Menu loop
            Wait(0)
        end
    end)
end

local function closeMenu()
    menuOpen = false
end
```

---

## SetTimeout vs Wait

```lua
-- Wait: Blocks current thread
CreateThread(function()
    print('Start')
    Wait(5000)
    print('After 5 seconds')
end)

-- SetTimeout: Non-blocking, creates new execution
SetTimeout(5000, function()
    print('After 5 seconds')
end)
print('Immediately after')

-- Use SetTimeout for one-off delayed actions
-- Use Wait for continuous loops
```

---

## Tick Budget Monitoring

```lua
-- Simple performance monitor
local lastTick = GetGameTimer()
local frameTimes = {}

CreateThread(function()
    while true do
        local now = GetGameTimer()
        local frameTime = now - lastTick
        lastTick = now

        table.insert(frameTimes, frameTime)
        if #frameTimes > 100 then
            table.remove(frameTimes, 1)
        end

        -- Calculate average
        local sum = 0
        for _, ft in ipairs(frameTimes) do
            sum = sum + ft
        end
        local avg = sum / #frameTimes

        if avg > 20 then  -- More than 20ms per frame = issue
            print('[PERF] High frame time:', avg, 'ms')
        end

        Wait(0)
    end
end)
```

---

## Best Practices Summary

| Do | Don't |
|-----|-------|
| Use ox_lib target for interactions | Distance check loops with Wait(0) |
| Use keybinds for input | IsControlJustPressed in loops |
| Cache PlayerPedId(), coords | Call natives repeatedly in loops |
| Adaptive Wait based on distance | Fixed Wait(0) everywhere |
| Use events for state changes | Poll for changes |
| SetTimeout for delayed one-offs | Wait in main thread for delays |
| Use statebags for sync | Event spam for state |

---

## Performance Checklist

- [ ] No unnecessary `Wait(0)` loops
- [ ] Distance checks use adaptive wait
- [ ] Player ped/coords are cached
- [ ] Using ox_lib target instead of manual checks
- [ ] Using keybinds instead of control checks
- [ ] Threads clean up on resource stop
- [ ] Large iterations are chunked/spread across frames
