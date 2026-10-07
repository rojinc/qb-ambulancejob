local PlayerJob = {}
local onDuty = false
local currentGarage = 0

-- Functions

local function GetVehicleFromNetId(netId)
    if not netId then return 0 end
    local timeout = GetGameTimer() + 5000
    while not NetworkDoesEntityExistWithNetworkId(netId) and GetGameTimer() < timeout do
        Wait(10)
    end
    return NetToVeh(netId)
end

local function SetFullFuel(veh)
    if GetResourceState(Config.FuelResource) == 'started' then
        exports[Config.FuelResource]:SetFuel(veh, 100.0)
    end
end

local function IsJobVehicle(veh)
    local model = GetEntityModel(veh)
    if model == joaat(Config.Helicopter) then return true end
    for _, vehicles in pairs(Config.AuthorizedVehicles) do
        for vehicleName in pairs(vehicles) do
            if model == joaat(vehicleName) then return true end
        end
    end
    return false
end

function TakeOutVehicle(vehicleInfo)
    local coords = Config.Locations['vehicle'][currentGarage]
    -- The server checks the job, duty, grade and distance before spawning
    QBCore.Functions.TriggerCallback('hospital:server:SpawnVehicle', function(netId)
        local veh = GetVehicleFromNetId(netId)
        if veh == 0 then return end
        SetVehicleNumberPlateText(veh, Lang:t('info.amb_plate') .. tostring(math.random(1000, 9999)))
        SetEntityHeading(veh, coords.w)
        SetFullFuel(veh)
        TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
        if Config.VehicleSettings[vehicleInfo] ~= nil then
            QBCore.Shared.SetDefaultVehicleExtras(veh, Config.VehicleSettings[vehicleInfo].extras)
        end
        TriggerEvent('vehiclekeys:client:SetOwner', QBCore.Functions.GetPlate(veh))
        SetVehicleEngineOn(veh, true, true)
    end, vehicleInfo, currentGarage, false)
end

local function getAuthorizedVehicles(grade)
    local accessibleVehicles = {}
    for availableGrade, vehicles in pairs(Config.AuthorizedVehicles) do
        if grade >= availableGrade then
            for vehicleName, vehicleLabel in pairs(vehicles) do
                accessibleVehicles[vehicleName] = vehicleLabel
            end
        end
    end
    return accessibleVehicles
end

function MenuGarage()
    local vehicleMenu = {
        {
            header = Lang:t('menu.amb_vehicles'),
            isMenuHeader = true
        }
    }

    local authorizedVehicles = getAuthorizedVehicles(QBCore.Functions.GetPlayerData().job.grade.level)
    for veh, label in pairs(authorizedVehicles) do
        vehicleMenu[#vehicleMenu + 1] = {
            header = label,
            txt = '',
            params = {
                event = 'ambulance:client:TakeOutVehicle',
                args = {
                    vehicle = veh
                }
            }
        }
    end
    vehicleMenu[#vehicleMenu + 1] = {
        header = Lang:t('menu.close'),
        txt = '',
        params = {
            event = 'qb-menu:client:closeMenu'
        }

    }
    exports['qb-menu']:openMenu(vehicleMenu)
end

-- Events

RegisterNetEvent('ambulance:client:TakeOutVehicle', function(data)
    local vehicle = data.vehicle
    TakeOutVehicle(vehicle)
end)

-- The doctor count is kept up to date by the server from the job and duty data
RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerJob = JobInfo
    onDuty = PlayerJob.onduty
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    exports.spawnmanager:setAutoSpawn(false)
    CreateThread(function()
        Wait(5000)
        -- Get the ped after the wait, it can change while the character loads
        local ped = PlayerPedId()
        local player = PlayerId()
        SetEntityMaxHealth(ped, 200)
        SetEntityHealth(ped, 200)
        SetPlayerHealthRechargeMultiplier(player, 0.0)
        SetPlayerHealthRechargeLimit(player, 0.0)
    end)
    CreateThread(function()
        Wait(1000)
        QBCore.Functions.GetPlayerData(function(PlayerData)
            PlayerJob = PlayerData.job
            onDuty = PlayerData.job.onduty
            SetPedArmour(PlayerPedId(), PlayerData.metadata['armor'] or 0)
            if (not PlayerData.metadata['inlaststand'] and not PlayerData.metadata['isknockeddown'] and PlayerData.metadata['isdead']) then
                deathTime = Config.ReviveInterval
                OnDeath()
                DeathTimer()
            elseif (PlayerData.metadata['isknockeddown'] and not PlayerData.metadata['inlaststand'] and not PlayerData.metadata['isdead']) then
                SetKnockdown(true)
            elseif (PlayerData.metadata['inlaststand'] and not PlayerData.metadata['isdead']) then
                SetLaststand(true)
            else
                TriggerServerEvent('hospital:server:SetDeathStatus', false)
                TriggerServerEvent('hospital:server:SetLaststandStatus', false)
                TriggerServerEvent('hospital:server:SetKnockdownStatus', false)
            end
        end)
    end)
end)

RegisterNetEvent('QBCore:Client:SetDuty', function(duty)
    onDuty = duty
end)

function Status()
    if isStatusChecking then
        local statusMenu = {
            {
                header = Lang:t('menu.status'),
                isMenuHeader = true
            }
        }
        for _, v in pairs(statusChecks) do
            statusMenu[#statusMenu + 1] = {
                header = v.label,
                txt = '',
                params = {
                    event = 'hospital:client:TreatWounds',
                }
            }
        end
        statusMenu[#statusMenu + 1] = {
            header = Lang:t('menu.close'),
            txt = '',
            params = {
                event = 'qb-menu:client:closeMenu'
            }
        }
        exports['qb-menu']:openMenu(statusMenu)
    end
end

local function StatusMessage(text)
    TriggerEvent('chat:addMessage', {
        color = { 255, 0, 0 },
        multiline = false,
        args = { Lang:t('info.status'), text }
    })
end

RegisterNetEvent('hospital:client:CheckStatus', function()
    local player, distance = QBCore.Functions.GetClosestPlayer()
    if player ~= -1 and distance < 5.0 then
        local playerId = GetPlayerServerId(player)
        QBCore.Functions.TriggerCallback('hospital:GetPlayerStatus', function(result)
            if not result then return end
            statusChecks = {}
            local isHealthy = true
            for k, v in pairs(result) do
                if k == 'BLEED' then
                    isHealthy = false
                    StatusMessage(Lang:t('info.is_status', { status = Config.BleedingStates[v].label }))
                elseif k == 'WEAPONWOUNDS' then
                    for _, weapon in pairs(v) do
                        isHealthy = false
                        local weaponInfo = QBCore.Shared.Weapons[weapon]
                        if weaponInfo then
                            StatusMessage(weaponInfo.damagereason)
                        end
                    end
                else
                    isHealthy = false
                    statusChecks[#statusChecks + 1] = {
                        bone = Config.BoneIndexes[k],
                        label = v.label .. ' (' .. Config.WoundStates[v.severity] .. ')'
                    }
                end
            end

            if isHealthy then
                QBCore.Functions.Notify(Lang:t('success.healthy_player'), 'success')
                return
            end
            isStatusChecking = true
            statusCheckTime = 60
            Status()
        end, playerId)
    else
        QBCore.Functions.Notify(Lang:t('error.no_player'), 'error')
    end
end)

RegisterNetEvent('hospital:client:RevivePlayer', function()
    local hasItem = QBCore.Functions.HasItem('firstaid')
    if hasItem then
        local player, distance = QBCore.Functions.GetClosestPlayer()
        if player ~= -1 and distance < 5.0 then
            local playerId = GetPlayerServerId(player)
            QBCore.Functions.Progressbar('hospital_revive', Lang:t('progress.revive'), 5000, false, true, {
                disableMovement = false,
                disableCarMovement = false,
                disableMouse = false,
                disableCombat = true,
            }, {
                animDict = healAnimDict,
                anim = healAnim,
                flags = 33,
            }, {}, {}, function() -- Done
                StopAnimTask(PlayerPedId(), healAnimDict, 'exit', 1.0)
                QBCore.Functions.Notify(Lang:t('success.revived'), 'success')
                TriggerServerEvent('hospital:server:RevivePlayer', playerId)
            end, function() -- Cancel
                StopAnimTask(PlayerPedId(), healAnimDict, 'exit', 1.0)
                QBCore.Functions.Notify(Lang:t('error.canceled'), 'error')
            end)
        else
            QBCore.Functions.Notify(Lang:t('error.no_player'), 'error')
        end
    else
        QBCore.Functions.Notify(Lang:t('error.no_firstaid'), 'error')
    end
end)

RegisterNetEvent('hospital:client:TreatWounds', function()
    local hasItem = QBCore.Functions.HasItem('bandage')
    if hasItem then
        local player, distance = QBCore.Functions.GetClosestPlayer()
        if player ~= -1 and distance < 5.0 then
            local playerId = GetPlayerServerId(player)
            QBCore.Functions.Progressbar('hospital_healwounds', Lang:t('progress.healing'), 5000, false, true, {
                disableMovement = false,
                disableCarMovement = false,
                disableMouse = false,
                disableCombat = true,
            }, {
                animDict = healAnimDict,
                anim = healAnim,
                flags = 33,
            }, {}, {}, function() -- Done
                StopAnimTask(PlayerPedId(), healAnimDict, 'exit', 1.0)
                QBCore.Functions.Notify(Lang:t('success.helped_player'), 'success')
                TriggerServerEvent('hospital:server:TreatWounds', playerId)
            end, function() -- Cancel
                StopAnimTask(PlayerPedId(), healAnimDict, 'exit', 1.0)
                QBCore.Functions.Notify(Lang:t('error.canceled'), 'error')
            end)
        else
            QBCore.Functions.Notify(Lang:t('error.no_player'), 'error')
        end
    else
        QBCore.Functions.Notify(Lang:t('error.no_bandage'), 'error')
    end
end)

local function UseElevator(destination, index)
    local coords = Config.Locations[destination][index]
    if not coords then return end
    local ped = PlayerPedId()
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(10) end
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    if coords.w then
        SetEntityHeading(ped, coords.w)
    end
    Wait(100)
    DoScreenFadeIn(1000)
end

-- Works out which elevator the player is using: qb-target passes its option table,
-- the zone controls pass the index, anything else falls back to the closest one
local function GetElevatorIndex(data, location)
    if type(data) == 'table' and data.index then return data.index end
    if type(data) == 'number' then return data end

    local coords = GetEntityCoords(PlayerPedId())
    local closest, lowestDist = 1, nil
    for i = 1, #Config.Locations[location] do
        local v = Config.Locations[location][i]
        local dist = #(coords - vector3(v.x, v.y, v.z))
        if not lowestDist or dist < lowestDist then
            closest, lowestDist = i, dist
        end
    end
    return closest
end

local check = false
local function EMSControls(variable, index)
    CreateThread(function()
        check = true
        while check do
            if IsControlJustPressed(0, 38) then
                exports['qb-core']:KeyPressed(38)
                if variable == 'sign' then
                    TriggerEvent('EMSToggle:Duty')
                elseif variable == 'stash' then
                    TriggerServerEvent('qb-ambulancejob:server:stash')
                elseif variable == 'storeheli' then
                    TriggerEvent('qb-ambulancejob:storeheli')
                elseif variable == 'takeheli' then
                    TriggerEvent('qb-ambulancejob:pullheli')
                elseif variable == 'roof' then
                    TriggerEvent('qb-ambulancejob:elevator_main', index)
                elseif variable == 'main' then
                    TriggerEvent('qb-ambulancejob:elevator_roof', index)
                end
            end
            Wait(1)
        end
    end)
end

-- Stores the vehicle the player is driving, but only if it is a job vehicle
local function StoreJobVehicle(ped)
    local veh = GetVehiclePedIsIn(ped, false)
    if IsJobVehicle(veh) and GetPedInVehicleSeat(veh, -1) == ped then
        QBCore.Functions.DeleteVehicle(veh)
    end
end

local CheckVehicle = false
local function EMSVehicle(k)
    CheckVehicle = true
    CreateThread(function()
        while CheckVehicle do
            if IsControlJustPressed(0, 38) then
                exports['qb-core']:KeyPressed(38)
                CheckVehicle = false
                local ped = PlayerPedId()
                if IsPedInAnyVehicle(ped, false) then
                    StoreJobVehicle(ped)
                else
                    currentGarage = k
                    MenuGarage()
                end
            end
            Wait(1)
        end
    end)
end

local CheckHeli = false
local function EMSHelicopter(k)
    CheckHeli = true
    CreateThread(function()
        while CheckHeli do
            if IsControlJustPressed(0, 38) then
                exports['qb-core']:KeyPressed(38)
                CheckHeli = false
                local ped = PlayerPedId()
                if IsPedInAnyVehicle(ped, false) then
                    StoreJobVehicle(ped)
                else
                    local coords = Config.Locations['helicopter'][k]
                    QBCore.Functions.TriggerCallback('hospital:server:SpawnVehicle', function(netId)
                        local veh = GetVehicleFromNetId(netId)
                        if veh == 0 then return end
                        SetVehicleNumberPlateText(veh, Lang:t('info.heli_plate') .. tostring(math.random(1000, 9999)))
                        SetEntityHeading(veh, coords.w)
                        SetVehicleLivery(veh, 1) -- Ambulance Livery
                        SetFullFuel(veh)
                        TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
                        TriggerEvent('vehiclekeys:client:SetOwner', QBCore.Functions.GetPlate(veh))
                        SetVehicleEngineOn(veh, true, true, false)
                    end, Config.Helicopter, k, true)
                end
            end
            Wait(1)
        end
    end)
end

-- On the roof: take the elevator down to the main floor
RegisterNetEvent('qb-ambulancejob:elevator_roof', function(data)
    UseElevator('main', GetElevatorIndex(data, 'roof'))
end)

-- On the main floor: take the elevator up to the roof
RegisterNetEvent('qb-ambulancejob:elevator_main', function(data)
    UseElevator('roof', GetElevatorIndex(data, 'main'))
end)

RegisterNetEvent('EMSToggle:Duty', function()
    onDuty = not onDuty
    TriggerServerEvent('QBCore:ToggleDuty')
    TriggerServerEvent('police:server:UpdateBlips')
end)

CreateThread(function()
    for i = 1, #Config.Locations['vehicle'] do
        local v = Config.Locations['vehicle'][i]
        local boxZone = BoxZone:Create(vector3(v.x, v.y, v.z), 5, 5, {
            name = 'vehicle' .. i,
            debugPoly = false,
            heading = 70,
            minZ = v.z - 2,
            maxZ = v.z + 2,
        })
        boxZone:onPlayerInOut(function(isPointInside)
            if isPointInside and PlayerJob.name == 'ambulance' and onDuty then
                exports['qb-core']:DrawText(Lang:t('text.veh_button'), 'left')
                EMSVehicle(i)
            else
                CheckVehicle = false
                exports['qb-core']:HideText()
            end
        end)
    end

    for i = 1, #Config.Locations['helicopter'] do
        local v = Config.Locations['helicopter'][i]
        local boxZone = BoxZone:Create(vector3(v.x, v.y, v.z), 5, 5, {
            name = 'helicopter' .. i,
            debugPoly = false,
            heading = 70,
            minZ = v.z - 2,
            maxZ = v.z + 2,
        })
        boxZone:onPlayerInOut(function(isPointInside)
            if isPointInside and PlayerJob.name == 'ambulance' and onDuty then
                exports['qb-core']:DrawText(Lang:t('text.heli_button'), 'left')
                EMSHelicopter(i)
            else
                CheckHeli = false
                exports['qb-core']:HideText()
            end
        end)
    end
end)

-- Convar turns into a boolean
if Config.UseTarget then
    CreateThread(function()
        for i = 1, #Config.Locations['duty'] do
            local v = Config.Locations['duty'][i]
            exports['qb-target']:AddBoxZone('duty' .. i, vector3(v.x, v.y, v.z), 1.5, 1, {
                name = 'duty' .. i,
                debugPoly = false,
                heading = -20,
                minZ = v.z - 2,
                maxZ = v.z + 2,
            }, {
                options = {
                    {
                        type = 'client',
                        event = 'EMSToggle:Duty',
                        icon = 'fa fa-clipboard',
                        label = Lang:t('text.duty'),
                        job = 'ambulance'
                    }
                },
                distance = 1.5
            })
        end
        for i = 1, #Config.Locations['stash'] do
            local v = Config.Locations['stash'][i]
            exports['qb-target']:AddBoxZone('stash' .. i, vector3(v.x, v.y, v.z), 1, 1, {
                name = 'stash' .. i,
                debugPoly = false,
                heading = -20,
                minZ = v.z - 2,
                maxZ = v.z + 2,
            }, {
                options = {
                    {
                        type = 'server',
                        event = 'qb-ambulancejob:server:stash',
                        icon = 'fa fa-hand',
                        label = Lang:t('text.pstash'),
                        job = 'ambulance'
                    }
                },
                distance = 1.5
            })
        end
        for i = 1, #Config.Locations['roof'] do
            local v = Config.Locations['roof'][i]
            exports['qb-target']:AddBoxZone('roof' .. i, vector3(v.x, v.y, v.z), 2, 2, {
                name = 'roof' .. i,
                debugPoly = false,
                heading = -20,
                minZ = v.z - 2,
                maxZ = v.z + 2,
            }, {
                options = {
                    {
                        type = 'client',
                        event = 'qb-ambulancejob:elevator_roof',
                        icon = 'fas fa-hand-point-up',
                        label = Lang:t('text.elevator'),
                        job = 'ambulance',
                        index = i,
                    },
                },
                distance = 8
            })
        end
        for i = 1, #Config.Locations['main'] do
            local v = Config.Locations['main'][i]
            exports['qb-target']:AddBoxZone('main' .. i, vector3(v.x, v.y, v.z), 1.5, 1.5, {
                name = 'main' .. i,
                debugPoly = false,
                heading = -20,
                minZ = v.z - 2,
                maxZ = v.z + 2,
            }, {
                options = {
                    {
                        type = 'client',
                        event = 'qb-ambulancejob:elevator_main',
                        icon = 'fas fa-hand-point-up',
                        label = Lang:t('text.elevator'),
                        job = 'ambulance',
                        index = i,
                    },
                },
                distance = 8
            })
        end
    end)
else
    CreateThread(function()
        local signPoly = {}
        for i = 1, #Config.Locations['duty'] do
            local v = Config.Locations['duty'][i]
            signPoly[#signPoly + 1] = BoxZone:Create(vector3(v.x, v.y, v.z), 1.5, 1, {
                name = 'sign' .. i,
                debugPoly = false,
                heading = -20,
                minZ = v.z - 2,
                maxZ = v.z + 2,
            })
        end

        local signCombo = ComboZone:Create(signPoly, { name = 'signcombo', debugPoly = false })
        signCombo:onPlayerInOut(function(isPointInside)
            if isPointInside and PlayerJob.name == 'ambulance' then
                if not onDuty then
                    exports['qb-core']:DrawText(Lang:t('text.onduty_button'), 'left')
                    EMSControls('sign')
                else
                    exports['qb-core']:DrawText(Lang:t('text.offduty_button'), 'left')
                    EMSControls('sign')
                end
            else
                check = false
                exports['qb-core']:HideText()
            end
        end)

        local stashPoly = {}
        for i = 1, #Config.Locations['stash'] do
            local v = Config.Locations['stash'][i]
            stashPoly[#stashPoly + 1] = BoxZone:Create(vector3(v.x, v.y, v.z), 1, 1, {
                name = 'stash' .. i,
                debugPoly = false,
                heading = -20,
                minZ = v.z - 2,
                maxZ = v.z + 2,
            })
        end

        local stashCombo = ComboZone:Create(stashPoly, { name = 'stashCombo', debugPoly = false })
        stashCombo:onPlayerInOut(function(isPointInside)
            if isPointInside and PlayerJob.name == 'ambulance' then
                if onDuty then
                    exports['qb-core']:DrawText(Lang:t('text.pstash_button'), 'left')
                    EMSControls('stash')
                end
            else
                check = false
                exports['qb-core']:HideText()
            end
        end)

        local roofPoly = {}
        for i = 1, #Config.Locations['roof'] do
            local v = Config.Locations['roof'][i]
            roofPoly[#roofPoly + 1] = BoxZone:Create(vector3(v.x, v.y, v.z), 2, 2, {
                name = 'roof' .. i,
                debugPoly = false,
                heading = 70,
                minZ = v.z - 2,
                maxZ = v.z + 2,
                data = { index = i },
            })
        end

        local roofCombo = ComboZone:Create(roofPoly, { name = 'roofCombo', debugPoly = false })
        roofCombo:onPlayerInOut(function(isPointInside, _, zone)
            if isPointInside and zone and PlayerJob.name == 'ambulance' then
                if onDuty then
                    exports['qb-core']:DrawText(Lang:t('text.elevator_main'), 'left')
                    EMSControls('main', zone.data.index)
                else
                    exports['qb-core']:DrawText(Lang:t('error.not_on_duty'), 'left')
                end
            else
                check = false
                exports['qb-core']:HideText()
            end
        end)

        local mainPoly = {}
        for i = 1, #Config.Locations['main'] do
            local v = Config.Locations['main'][i]
            mainPoly[#mainPoly + 1] = BoxZone:Create(vector3(v.x, v.y, v.z), 1.5, 1.5, {
                name = 'main' .. i,
                debugPoly = false,
                heading = 70,
                minZ = v.z - 2,
                maxZ = v.z + 2,
                data = { index = i },
            })
        end

        local mainCombo = ComboZone:Create(mainPoly, { name = 'mainPoly', debugPoly = false })
        mainCombo:onPlayerInOut(function(isPointInside, _, zone)
            if isPointInside and zone and PlayerJob.name == 'ambulance' then
                if onDuty then
                    exports['qb-core']:DrawText(Lang:t('text.elevator_roof'), 'left')
                    EMSControls('roof', zone.data.index)
                else
                    exports['qb-core']:DrawText(Lang:t('error.not_on_duty'), 'left')
                end
            else
                check = false
                exports['qb-core']:HideText()
            end
        end)
    end)
end
