InLaststand = false
LaststandTime = 0
lastStandDict = 'combat@damage@writhe'
lastStandAnim = 'writhe_loop'
isEscorted = false
local isEscorting = false
local isEnteringLaststand = false

-- Functions

function SetLaststand(bool)
    local ped = PlayerPedId()
    if bool then
        -- Stops a second call from starting another bleed out timer
        if InLaststand or isEnteringLaststand then return end
        isEnteringLaststand = true
        while GetEntitySpeed(ped) > 0.5 or IsPedRagdoll(ped) do Wait(10) end
        -- Revived while falling, so don't go down after all
        if not isEnteringLaststand then return end
        TriggerServerEvent('InteractSound_SV:PlayOnSource', 'demo', 0.1)
        LaststandTime = Config.ReviveInterval
        ResurrectPlayer(ped)
        SetEntityHealth(ped, 150)
        if IsPedInAnyVehicle(ped, false) then
            LoadAnimDict('veh@low@front_ps@idle_duck')
            TaskPlayAnim(ped, 'veh@low@front_ps@idle_duck', 'sit', 1.0, 8.0, -1, 1, -1, false, false, false)
        else
            LoadAnimDict(lastStandDict)
            TaskPlayAnim(ped, lastStandDict, lastStandAnim, 1.0, 8.0, -1, 1, -1, false, false, false)
        end
        InLaststand = true
        isEnteringLaststand = false
        -- Set the status first, the server only accepts alerts from players that are down
        TriggerServerEvent('hospital:server:SetLaststandStatus', true)
        TriggerServerEvent('hospital:server:ambulanceAlert', Lang:t('info.civ_down'))
        CreateThread(function()
            while InLaststand do
                local player = PlayerId()
                if LaststandTime - 1 > 0 then
                    LaststandTime = LaststandTime - 1
                    Wait(1000)
                else
                    -- Player bled out, transition to death
                    QBCore.Functions.Notify(Lang:t('error.bled_out'), 'error')
                    SetLaststand(false)
                    local killer_2, killerWeapon = NetworkGetEntityKillerOfPlayer(player)
                    local killer = GetPedSourceOfDeath(ped)
                    if killer_2 ~= 0 and killer_2 ~= -1 then killer = killer_2 end
                    local killerId = NetworkGetPlayerIndexFromPed(killer)
                    local killerName = killerId ~= -1 and GetPlayerName(killerId) .. ' ' .. '(' .. GetPlayerServerId(killerId) .. ')' or Lang:t('info.self_death')
                    local weaponLabel = Lang:t('info.wep_unknown')
                    local weaponName = Lang:t('info.wep_unknown')
                    local weaponItem = QBCore.Shared.Weapons[killerWeapon]
                    if weaponItem then
                        weaponLabel = weaponItem.label
                        weaponName = weaponItem.name
                    end
                    TriggerServerEvent('qb-log:server:CreateLog', 'death', Lang:t('logs.death_log_title', { playername = GetPlayerName(player), playerid = GetPlayerServerId(player) }), 'red', Lang:t('logs.death_log_message', { killername = killerName, playername = GetPlayerName(player), weaponlabel = weaponLabel, weaponname = weaponName }))
                    deathTime = 0
                    OnDeath()
                    DeathTimer()
                    break
                end
            end
        end)
    else
        isEnteringLaststand = false
        if InLaststand then
            TaskPlayAnim(ped, lastStandDict, 'exit', 1.0, 8.0, -1, 1, -1, false, false, false)
        end
        InLaststand = false
        LaststandTime = 0
        TriggerServerEvent('hospital:server:SetLaststandStatus', false)
    end
end

-- Events

RegisterNetEvent('hospital:client:SetEscortingState', function(bool)
    isEscorting = bool
end)

RegisterNetEvent('hospital:client:isEscorted', function(bool)
    isEscorted = bool
end)

RegisterNetEvent('hospital:client:UseFirstAid', function()
    if not isEscorting then
        local player, distance = QBCore.Functions.GetClosestPlayer()
        if player ~= -1 and distance < 1.5 then
            local playerId = GetPlayerServerId(player)
            TriggerServerEvent('hospital:server:UseFirstAid', playerId)
        end
    else
        QBCore.Functions.Notify(Lang:t('error.impossible'), 'error')
    end
end)

RegisterNetEvent('hospital:client:CanHelp', function(helperId)
    if InLaststand then
        if LaststandTime <= Config.MinimumRevive then
            TriggerServerEvent('hospital:server:CanHelp', helperId, true)
        else
            TriggerServerEvent('hospital:server:CanHelp', helperId, false)
        end
    else
        TriggerServerEvent('hospital:server:CanHelp', helperId, false)
    end
end)

RegisterNetEvent('hospital:client:HelpPerson', function(targetId)
    local ped = PlayerPedId()
    QBCore.Functions.Progressbar('hospital_revive', Lang:t('progress.revive'), math.random(30000, 60000), false, true, {
        disableMovement = false,
        disableCarMovement = false,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = healAnimDict,
        anim = healAnim,
        flags = 1,
    }, {}, {}, function() -- Done
        ClearPedTasks(ped)
        QBCore.Functions.Notify(Lang:t('success.revived'), 'success')
        TriggerServerEvent('hospital:server:RevivePlayer', targetId)
    end, function() -- Cancel
        ClearPedTasks(ped)
        QBCore.Functions.Notify(Lang:t('error.canceled'), 'error')
    end)
end)
