# Framework Auto-Detection

> Automatically detect the active framework from project files

## Detection Priority

### 1. Check fxmanifest.lua Dependencies

```lua
-- Search for these patterns in fxmanifest.lua

-- QBox (highest priority if present)
dependency 'qbx_core'
shared_script '@qbx_core/import.lua'

-- QBCore
dependency 'qb-core'
shared_script '@qb-core/shared/locale.lua'

-- ESX Legacy
dependency 'es_extended'
dependency 'esx_core'
shared_script '@es_extended/imports.lua'
```

### 2. Check Code Patterns

```lua
-- QBox patterns
lib.callback  -- ox_lib integration

-- QBCore patterns
exports['qb-core']:GetCoreObject()
QBCore.Functions
QBCore.Player

-- ESX patterns
exports.es_extended:getSharedObject()
ESX.GetPlayerData()
xPlayer:getMoney()
TriggerEvent('esx:getSharedObject', ...)
```

### 3. Check Config Files

Look for framework references in `config.lua` or `shared/config.lua`

---

## Detection Function

```lua
local function DetectFramework()
    -- Check resource states
    local qbx = GetResourceState('qbx_core')
    local qb = GetResourceState('qb-core')
    local esx = GetResourceState('es_extended')

    if qbx == 'started' or qbx == 'starting' then
        return 'qbox'
    elseif qb == 'started' or qb == 'starting' then
        return 'qbcore', exports['qb-core']:GetCoreObject()
    elseif esx == 'started' or esx == 'starting' then
        return 'esx', exports.es_extended:getSharedObject()
    end

    return nil, nil
end
```

---

## Framework Compatibility Notes

### QBox ↔ QBCore
- QBox maintains **backwards compatibility** with QBCore
- QBCore resources often work on QBox without changes
- QBox uses `qbx_core` resource name vs `qb-core`
- QBox prefers ox_lib for utilities

### ESX vs QB Family
- Different event naming conventions
- Different player object structure
- ESX uses `xPlayer`, QB uses `Player.Functions`
- Money handling differs significantly

---

## Multi-Framework Support Pattern

```lua
-- bridge.lua - Framework abstraction layer
local Bridge = {}

local frameworkType, core = DetectFramework()
Bridge.Type = frameworkType
Bridge.Core = core

-- Abstract common operations
function Bridge.GetPlayerMoney(source)
    if Bridge.Type == 'qbox' or Bridge.Type == 'qbcore' then
        local Player = Bridge.Core.Functions.GetPlayer(source)
        return Player.Functions.GetMoney('cash')
    elseif Bridge.Type == 'esx' then
        local xPlayer = Bridge.Core.GetPlayerFromId(source)
        return xPlayer.getMoney()
    end
end

function Bridge.AddMoney(source, amount)
    if Bridge.Type == 'qbox' or Bridge.Type == 'qbcore' then
        local Player = Bridge.Core.Functions.GetPlayer(source)
        Player.Functions.AddMoney('cash', amount)
    elseif Bridge.Type == 'esx' then
        local xPlayer = Bridge.Core.GetPlayerFromId(source)
        xPlayer.addMoney(amount)
    end
end

return Bridge
```

---

## Grep Commands for Detection

```bash
# Find framework dependencies
grep -r "dependency.*qbx_core\|dependency.*qb-core\|dependency.*es_extended" .

# Find framework imports
grep -r "GetCoreObject\|getSharedObject" .

# Find framework events
grep -r "QBCore\.\|ESX\.\|qbx" .
```
