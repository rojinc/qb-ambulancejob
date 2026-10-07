# GTA V Asset Discovery

> Finding props, vehicles, peds, and other game assets for FiveM

## PlebMasters Forge

**URL:** https://forge.plebmasters.de/

The primary resource for discovering GTA V assets.

### Categories

| Category | What You'll Find |
|----------|-----------------|
| Objects | Props, furniture, world objects |
| Vehicles | Cars, bikes, planes, boats |
| Peds | Character models, animals |
| Weapons | Weapon models |
| Clothes | Clothing components by ID |
| Vehicle Mods | Mod kits, parts |
| Ped Decorations | Tattoos, etc. |
| MLO Interiors | Interior coordinates |
| IPLs | Map additions |
| YMAPS | Map modifications |
| Animations | Animation dictionaries |
| Timecycle Mods | Visual effects |
| AnimPost FX | Screen effects |

---

## Using Discovered Assets

### Objects/Props
```lua
-- Request and spawn a prop
local model = 'prop_laptop_01a'
local hash = GetHashKey(model)

RequestModel(hash)
while not HasModelLoaded(hash) do
    Wait(10)
end

local prop = CreateObject(hash, coords.x, coords.y, coords.z, true, true, true)

-- Cleanup when done
SetModelAsNoLongerNeeded(hash)

-- With ox_lib
lib.requestModel(model, 5000)  -- With timeout
local prop = CreateObject(hash, coords.x, coords.y, coords.z, true, true, true)
```

### Common Props
```lua
-- Laptops
'prop_laptop_01a'
'prop_laptop_02_closed'
'hei_prop_heist_laptop'

-- Furniture
'prop_table_01'
'prop_chair_01a'
'prop_bench_01a'

-- Electronics
'prop_tv_flat_01'
'prop_phone_ing'
'prop_cs_tablet'

-- Containers
'prop_box_wood01a'
'prop_money_bag_01'
'prop_cs_cardbox_01'
```

---

### Vehicles
```lua
-- Spawn a vehicle
local model = 'adder'  -- Vehicle spawn name
local hash = GetHashKey(model)

RequestModel(hash)
while not HasModelLoaded(hash) do
    Wait(10)
end

local vehicle = CreateVehicle(hash, coords.x, coords.y, coords.z, heading, true, false)

SetModelAsNoLongerNeeded(hash)

-- Set as networked (multiplayer visible)
local netId = NetworkGetNetworkIdFromEntity(vehicle)
SetNetworkIdExistsOnAllMachines(netId, true)
```

### Common Vehicles
```lua
-- Sports
'adder', 'zentorno', 'turismor', 't20', 'osiris'

-- Sedans
'sultan', 'kuruma', 'schafter2', 'tailgater'

-- SUVs
'baller', 'cavalcade', 'granger', 'dubsta'

-- Motorcycles
'bati', 'akuma', 'sanchez', 'hakuchou'

-- Emergency
'police', 'police2', 'police3', 'policeb'
'ambulance', 'firetruk'

-- Aircraft
'buzzard', 'frogger', 'maverick', 'jet'
```

---

### Peds
```lua
-- Spawn a ped
local model = 'a_m_y_hipster_01'
local hash = GetHashKey(model)

RequestModel(hash)
while not HasModelLoaded(hash) do
    Wait(10)
end

local ped = CreatePed(4, hash, coords.x, coords.y, coords.z, heading, true, true)
-- Type 4 = civilian, 5 = cop, 6 = medic, etc.

SetModelAsNoLongerNeeded(hash)

-- Make ped not flee
SetBlockingOfNonTemporaryEvents(ped, true)
SetPedFleeAttributes(ped, 0, false)
```

### Common Peds
```lua
-- Male civilians
'a_m_y_hipster_01'
'a_m_m_business_01'
'a_m_y_downtown_01'
'a_m_y_beachvesp_01'

-- Female civilians
'a_f_y_hipster_01'
'a_f_m_business_02'
'a_f_y_beach_01'

-- Workers
's_m_y_construct_01'
's_m_m_doctor_01'
's_m_y_chef_01'
's_m_y_waiter_01'

-- Emergency
's_m_y_cop_01'
's_m_y_sheriff_01'
's_m_m_paramedic_01'
's_m_y_fireman_01'

-- Animals
'a_c_cat_01'
'a_c_dog_01'
'a_c_husky'
```

---

### Weapons
```lua
-- Give weapon to ped
local weapon = 'WEAPON_PISTOL'
local hash = GetHashKey(weapon)

GiveWeaponToPed(ped, hash, 100, false, true)
-- 100 = ammo, false = hidden, true = equip now

-- Remove weapon
RemoveWeaponFromPed(ped, hash)

-- Check if has weapon
if HasPedGotWeapon(ped, hash, false) then
    -- Has weapon
end
```

### Common Weapons
```lua
-- Pistols
'WEAPON_PISTOL'
'WEAPON_COMBATPISTOL'
'WEAPON_APPISTOL'
'WEAPON_HEAVYPISTOL'

-- SMGs
'WEAPON_MICROSMG'
'WEAPON_SMG'
'WEAPON_COMBATPDW'

-- Rifles
'WEAPON_ASSAULTRIFLE'
'WEAPON_CARBINERIFLE'
'WEAPON_SPECIALCARBINE'

-- Shotguns
'WEAPON_PUMPSHOTGUN'
'WEAPON_SAWNOFFSHOTGUN'

-- Heavy
'WEAPON_RPG'
'WEAPON_MINIGUN'

-- Melee
'WEAPON_BAT'
'WEAPON_KNIFE'
'WEAPON_NIGHTSTICK'

-- Throwable
'WEAPON_GRENADE'
'WEAPON_SMOKEGRENADE'
'WEAPON_MOLOTOV'
```

---

### Animations
```lua
-- Play animation
local dict = 'amb@world_human_hang_out_street@female_hold_arm@base'
local anim = 'base'

RequestAnimDict(dict)
while not HasAnimDictLoaded(dict) do
    Wait(10)
end

TaskPlayAnim(ped, dict, anim, 8.0, -8.0, -1, 1, 0, false, false, false)
-- 8.0 = blend in, -8.0 = blend out, -1 = duration (infinite)
-- 1 = flag (loop), 0 = playback rate

-- Stop animation
StopAnimTask(ped, dict, anim, 1.0)

-- Clear all anims
ClearPedTasks(ped)
```

### Common Animation Dicts
```lua
-- Idle/Standing
'amb@world_human_hang_out_street@male_a@idle_a'
'amb@world_human_leaning@male@wall@back@hands_together@idle_a'

-- Using phone
'cellphone@in_car@ps'
'amb@world_human_stand_mobile@male@text@base'

-- Drinking
'mp_player_intdrink'
'amb@world_human_drinking@coffee@male@idle_a'

-- Sitting
'timetable@ron@ig_3_couch'
'timetable@amanda@ig_2'

-- Working
'anim@heists@prison_heiststation@cop_reactions'
'mp_ped_interaction'

-- With ox_lib
lib.requestAnimDict(dict, 5000)  -- With timeout
```

---

## Alternative Resources

### GTAMods Wiki
https://gta.fandom.com/wiki/
- Comprehensive lists of vehicles, weapons, peds
- Internal names and stats

### GTA Fandom
https://gta.fandom.com/
- Lore and context for assets
- DLC content lists

### FiveM Forum
https://forum.cfx.re/c/development/
- Community discoveries
- Custom asset packs

### GitHub Repositories
Search for "fivem props", "gta5 models" for community-maintained lists

---

## Search Tips for PlebMasters

1. **Be specific** - Search "laptop" not "computer"
2. **Use categories** - Filter by Objects, Vehicles, etc.
3. **Check hash** - Some props have similar names but different hashes
4. **Test in-game** - Some props may not work as expected
5. **Note DLC** - Some assets require specific DLC to be loaded

---

## Fetch from PlebMasters

```
WebFetch(
    url: "https://forge.plebmasters.de/",
    prompt: "Search for {ASSET_TYPE} that looks like {DESCRIPTION}.
             Return the model name and any relevant info."
)
```

Asset types: objects, vehicles, peds, weapons, clothes, animations
