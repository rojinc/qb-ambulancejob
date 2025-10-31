Knockdown = Knockdown or {}
IsKnockedDown = false
KnockdownTime = 0
IsBeingRevived = false

-- Functions

local function LoadAnimation(dict)
    while not HasAnimDictLoaded(dict) do
        RequestAnimDict(dict)
        Wait(100)
    end
end

function SetKnockdown(bool)
    local ped = PlayerPedId()
    if bool then
        Wait(1000)
        while GetEntitySpeed(ped) > 0.5 or IsPedRagdoll(ped) do Wait(10) end
        local pos = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        TriggerServerEvent('InteractSound_SV:PlayOnSource', 'demo', 0.1)
        KnockdownTime = Config.KnockdownTime

        if IsPedInAnyVehicle(ped) then
            local veh = GetVehiclePedIsIn(ped)
            local vehseats = GetVehicleModelNumberOfSeats(GetHashKey(GetEntityModel(veh)))
            for i = -1, vehseats do
                local occupant = GetPedInVehicleSeat(veh, i)
                if occupant == ped then
                    NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z + 0.5, heading, true, false)
                    SetPedIntoVehicle(ped, veh, i)
                end
            end
        else
            NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z + 0.5, heading, true, false)
        end

        SetEntityHealth(ped, 150)

        if IsPedInAnyVehicle(ped, false) then
            LoadAnimation('veh@low@front_ps@idle_duck')
            TaskPlayAnim(ped, 'veh@low@front_ps@idle_duck', 'sit', 1.0, 8.0, -1, 1, -1, false, false, false)
        end
        -- Ground animations are handled by crawl.lua

        IsKnockedDown = true
        TriggerServerEvent('hospital:server:ambulanceAlert', Lang:t('info.civ_down'))
        TriggerServerEvent('hospital:server:SetKnockdownStatus', true)

        -- Knockdown timer thread
        CreateThread(function()
            while IsKnockedDown do
                ped = PlayerPedId()
                local player = PlayerId()

                if KnockdownTime - 1 > 0 then
                    KnockdownTime = KnockdownTime - 1
                    Wait(1000)
                else
                    -- Time expired, move to bleeding state - immediately
                    QBCore.Functions.Notify(Lang:t('info.entering_bleeding'), 'error')
                    SetKnockdown(false)
                    SetLaststand(true)
                    break -- Exit loop immediately
                end
            end
        end)
    else
        IsKnockedDown = false
        KnockdownTime = 0
        TriggerServerEvent('hospital:server:SetKnockdownStatus', false)
    end
end

-- Damage detection during knockdown
CreateThread(function()
    while true do
        if IsKnockedDown then
            local ped = PlayerPedId()

            -- If player takes any damage while knocked down, immediately go to bleeding state
            if HasEntityBeenDamagedByAnyPed(ped) or HasEntityBeenDamagedByAnyVehicle(ped) then
                QBCore.Functions.Notify(Lang:t('info.damaged_bleeding'), 'error')
                SetKnockdown(false)
                SetLaststand(true)
                ClearEntityLastDamageEntity(ped)
            end

            -- Force unarmed
            SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)

            Wait(0)
        else
            Wait(1000)
        end
    end
end)

-- Export for qb-target to check if player is knocked down
exports('IsPlayerKnockedDown', function(entity)
    local player = PlayerId()
    local targetPlayer = NetworkGetPlayerIndexFromPed(entity)
    if targetPlayer == -1 then return false end

    local targetServerId = GetPlayerServerId(targetPlayer)
    local isKnockedDown = false

    QBCore.Functions.TriggerCallback('hospital:server:IsPlayerKnockedDown', function(result)
        isKnockedDown = result
    end, targetServerId)

    Wait(100)
    return isKnockedDown
end)

-- Event: Someone starts reviving you
RegisterNetEvent('hospital:client:BeingRevived', function(helperId)
    IsBeingRevived = true
    local helperName = GetPlayerName(GetPlayerFromServerId(helperId))
    QBCore.Functions.Notify('You are being helped by ' .. helperName, 'primary')
end)

-- Event: Revive was cancelled or failed
RegisterNetEvent('hospital:client:ReviveFailed', function()
    IsBeingRevived = false
    QBCore.Functions.Notify('Revive failed! Entering bleeding state...', 'error')
    SetKnockdown(false)
    SetLaststand(true)
end)

-- Event: Revive successful
RegisterNetEvent('hospital:client:ReviveSuccess', function()
    IsBeingRevived = false
    SetKnockdown(false)

    -- Play the idle animation while being fully revived
    local ped = PlayerPedId()
    LoadAnimation('dead')
    TaskPlayAnim(ped, 'dead', 'dead_d', 1.0, 1.0, -1, 1, 0, false, false, false)

    Wait(500) -- Brief moment to ensure animation starts
    TriggerEvent('hospital:client:Revive')
end)

-- Event: Attempt to revive a knocked down player
RegisterNetEvent('hospital:client:ReviveKnockedDown', function(targetId)
    local ped = PlayerPedId()

    -- Start ps-ui minigame
    local success = exports['ps-ui']:Circle(function(success)
        if success then
            TriggerServerEvent('hospital:server:ReviveKnockedDownSuccess', targetId)
        else
            TriggerServerEvent('hospital:server:ReviveKnockedDownFailed', targetId)
        end
    end, 2, 20) -- 2 circles, 20 second timer
end)

-- Add qb-target interaction for knocked down players
CreateThread(function()
    exports['qb-target']:AddGlobalPlayer({
        options = {
            {
                icon = 'fas fa-hand-holding-medical',
                label = 'Revive Player',
                action = function(entity)
                    local targetPlayer = NetworkGetPlayerIndexFromPed(entity)
                    if targetPlayer == -1 then return end
                    local targetServerId = GetPlayerServerId(targetPlayer)
                    TriggerServerEvent('hospital:server:AttemptReviveKnockedDown', targetServerId)
                end,
                canInteract = function(entity)
                    if not entity or not DoesEntityExist(entity) or not IsPedAPlayer(entity) then
                        return false
                    end
                    local targetPlayer = NetworkGetPlayerIndexFromPed(entity)
                    if targetPlayer == -1 or targetPlayer == PlayerId() then return false end

                    -- Check if target is knocked down via server
                    local targetServerId = GetPlayerServerId(targetPlayer)
                    local canRevive = false
                    QBCore.Functions.TriggerCallback('hospital:server:IsPlayerKnockedDown', function(result)
                        canRevive = result
                    end, targetServerId)
                    Wait(50)
                    return canRevive
                end
            }
        },
        distance = 2.5
    })
end)
