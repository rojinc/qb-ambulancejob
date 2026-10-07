# ox_lib Guide

> Utility library for FiveM - callbacks, UI, zones, and more

**Documentation:** https://overextended.dev/ox_lib

## Setup

### fxmanifest.lua
```lua
dependencies {
    'ox_lib'
}

shared_scripts {
    '@ox_lib/init.lua'
}
```

---

## Callbacks

### Server Registration
```lua
lib.callback.register('myresource:getData', function(source, arg1, arg2)
    -- source = player source
    local result = doSomething(arg1, arg2)
    return result
end)
```

### Client Usage
```lua
-- Async with callback
lib.callback('myresource:getData', false, function(result)
    print(result)
end, arg1, arg2)

-- Await (synchronous, cleaner)
local result = lib.callback.await('myresource:getData', false, arg1, arg2)
print(result)
```

---

## Notifications

```lua
-- Client
lib.notify({
    title = 'Title',
    description = 'Message text',
    type = 'success',     -- success, error, warning, info
    duration = 5000,
    position = 'top',     -- top, top-right, top-left, bottom, bottom-right, bottom-left
    style = {
        backgroundColor = '#141517',
        color = '#C1C2C5'
    },
    icon = 'check',
    iconColor = '#00ff00'
})

-- Server (send to player)
TriggerClientEvent('ox_lib:notify', source, {
    title = 'Server Message',
    description = 'From server',
    type = 'info'
})
```

---

## Context Menu

```lua
lib.registerContext({
    id = 'main_menu',
    title = 'Main Menu',
    options = {
        {
            title = 'Option 1',
            description = 'Description here',
            icon = 'fa-solid fa-gear',
            onSelect = function()
                print('Selected option 1')
            end
        },
        {
            title = 'Submenu',
            icon = 'fa-solid fa-folder',
            menu = 'sub_menu'  -- Opens another context
        },
        {
            title = 'With Args',
            icon = 'fa-solid fa-user',
            onSelect = function(args)
                print('Args:', args.playerId)
            end,
            args = { playerId = 1 }
        },
        {
            title = 'Server Event',
            icon = 'fa-solid fa-server',
            serverEvent = 'myresource:serverAction',
            args = { data = 'value' }
        }
    }
})

-- Open menu
lib.showContext('main_menu')

-- Hide menu
lib.hideContext()
```

---

## Input Dialog

```lua
local input = lib.inputDialog('Dialog Title', {
    {
        type = 'input',
        label = 'Name',
        placeholder = 'Enter your name',
        required = true
    },
    {
        type = 'number',
        label = 'Amount',
        default = 1,
        min = 1,
        max = 100
    },
    {
        type = 'select',
        label = 'Choose Option',
        options = {
            { value = 'a', label = 'Option A' },
            { value = 'b', label = 'Option B' }
        }
    },
    {
        type = 'checkbox',
        label = 'Agree to terms'
    },
    {
        type = 'textarea',
        label = 'Description',
        placeholder = 'Enter description...',
        max = 200
    },
    {
        type = 'color',
        label = 'Pick a color',
        default = '#ff0000'
    },
    {
        type = 'date',
        label = 'Select date',
        default = true  -- Today
    }
})

if input then
    local name = input[1]
    local amount = input[2]
    local option = input[3]
    local agreed = input[4]
end
```

---

## Progress Bar/Circle

```lua
-- Progress bar
if lib.progressBar({
    duration = 5000,
    label = 'Doing something...',
    useWhileDead = false,
    canCancel = true,
    disable = {
        car = true,
        move = true,
        combat = true
    },
    anim = {
        dict = 'anim@mp_player_intmenu@key_fob@',
        clip = 'fob_click'
    },
    prop = {
        model = 'prop_cs_burger_01',
        bone = 60309,  -- Right hand
        pos = vec3(0.0, 0.0, 0.0),
        rot = vec3(0.0, 0.0, 0.0)
    }
}) then
    -- Completed
    print('Done!')
else
    -- Cancelled
    print('Cancelled')
end

-- Progress circle (mini)
if lib.progressCircle({
    duration = 2000,
    position = 'bottom',
    label = 'Loading...',
    canCancel = true
}) then
    print('Completed')
end
```

---

## Radial Menu

```lua
-- Register items
lib.addRadialItem({
    {
        id = 'police_menu',
        icon = 'shield',
        label = 'Police Menu',
        menu = 'police_submenu'  -- Opens submenu
    },
    {
        id = 'action1',
        icon = 'hand',
        label = 'Action',
        onSelect = function()
            print('Action selected')
        end
    }
})

-- Register submenu
lib.registerRadial({
    id = 'police_submenu',
    items = {
        {
            icon = 'siren',
            label = 'Toggle Siren',
            onSelect = function()
                -- Toggle siren
            end
        }
    }
})

-- Remove item
lib.removeRadialItem('police_menu')
```

---

## Zones

```lua
-- Box zone
local zone = lib.zones.box({
    coords = vec3(100.0, 200.0, 30.0),
    size = vec3(10.0, 10.0, 5.0),
    rotation = 45,
    debug = true,  -- Show zone in game
    inside = function(self)
        -- Called every frame while inside
        lib.showTextUI('Press [E] to interact')
    end,
    onEnter = function(self)
        print('Entered zone')
    end,
    onExit = function(self)
        print('Exited zone')
        lib.hideTextUI()
    end
})

-- Sphere zone
local zone = lib.zones.sphere({
    coords = vec3(100.0, 200.0, 30.0),
    radius = 5.0,
    debug = true,
    onEnter = function() end,
    onExit = function() end
})

-- Poly zone
local zone = lib.zones.poly({
    points = {
        vec3(100.0, 200.0, 30.0),
        vec3(110.0, 200.0, 30.0),
        vec3(110.0, 210.0, 30.0),
        vec3(100.0, 210.0, 30.0)
    },
    thickness = 4,
    debug = true
})

-- Remove zone
zone:remove()
```

---

## Points (Optimized Markers)

```lua
local point = lib.points.new({
    coords = vec3(100.0, 200.0, 30.0),
    distance = 50,  -- Activation distance
    onEnter = function(self)
        print('Near point')
    end,
    onExit = function(self)
        print('Left point area')
    end,
    nearby = function(self)
        -- Called when within distance
        DrawMarker(2, self.coords.x, self.coords.y, self.coords.z, ...)
    end
})

-- Remove point
point:remove()
```

---

## Text UI

```lua
-- Show text
lib.showTextUI('Press [E] to interact', {
    position = 'right-center',
    icon = 'hand',
    style = {
        borderRadius = 0,
        backgroundColor = '#48BB78',
        color = 'white'
    }
})

-- Hide text
lib.hideTextUI()

-- Check if showing
if lib.isTextUIOpen() then
    -- Text UI is visible
end
```

---

## Skillcheck

```lua
local success = lib.skillCheck({'easy', 'easy', 'medium'}, {'w', 'a', 's', 'd'})

-- Difficulty levels: 'easy', 'medium', 'hard'
-- Keys: any key names

if success then
    print('Skillcheck passed!')
else
    print('Skillcheck failed')
end
```

---

## Cache (Auto-updated Values)

```lua
-- These values are automatically cached and updated
local ped = cache.ped          -- PlayerPedId()
local playerId = cache.playerId
local serverId = cache.serverId
local coords = cache.coords    -- GetEntityCoords
local vehicle = cache.vehicle  -- Current vehicle or false
local seat = cache.seat        -- Seat index or false
local weapon = cache.weapon    -- Current weapon hash or false
```

---

## Requesters (With Timeout)

```lua
-- Request model with auto-timeout
lib.requestModel(modelHash, timeout)

-- Request anim dict
lib.requestAnimDict('anim_dict', timeout)

-- Request anim set
lib.requestAnimSet('anim_set', timeout)

-- Request texture dict
lib.requestStreamedTextureDict('texture_dict', timeout)

-- Request named ptfx
lib.requestNamedPtfxAsset('ptfx_name', timeout)
```

---

## Print/Debug

```lua
-- Pretty print tables
lib.print.info('Player data:', playerData)
lib.print.warn('Warning message')
lib.print.error('Error occurred:', err)
lib.print.debug('Debug info:', data)
```

---

## Fetch Documentation

For the most current ox_lib docs:
```
WebFetch(
    url: "https://overextended.dev/ox_lib",
    prompt: "Find {SPECIFIC_FEATURE} documentation"
)
```
