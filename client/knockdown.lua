IsKnockedDown = false
KnockdownTime = 0
IsBeingRevived = false
local isEnteringKnockdown = false

-- Functions

local function IsTargetKnockedDown(serverId)
    -- Set by the server as a replicated state bag, so no server call is needed
    return Player(serverId).state.isKnockedDown == true
end

function SetKnockdown(bool)
    local ped = PlayerPedId()
    if bool then
        -- Stops a second call from starting another knockdown timer
        if IsKnockedDown or isEnteringKnockdown then return end
        isEnteringKnockdown = true
        while GetEntitySpeed(ped) > 0.5 or IsPedRagdoll(ped) do Wait(10) end
        -- Revived while falling, so don't go down after all
        if not isEnteringKnockdown then return end
        TriggerServerEvent('InteractSound_SV:PlayOnSource', 'demo', 0.1)
        KnockdownTime = Config.KnockdownTime

        ResurrectPlayer(ped)
        SetEntityHealth(ped, 150)
        -- Forget the hit that knocked the player down, so it doesn't count as new damage
        ClearEntityLastDamageEntity(ped)

        if IsPedInAnyVehicle(ped, false) then
            LoadAnimDict('veh@low@front_ps@idle_duck')
            TaskPlayAnim(ped, 'veh@low@front_ps@idle_duck', 'sit', 1.0, 8.0, -1, 1, -1, false, false, false)
        end
        -- Ground animations are handled by crawl.lua

        IsKnockedDown = true
        isEnteringKnockdown = false
        -- Set the status first, the server only accepts alerts from players that are down
        TriggerServerEvent('hospital:server:SetKnockdownStatus', true)
        TriggerServerEvent('hospital:server:ambulanceAlert', Lang:t('info.civ_down'))

        -- Knockdown timer thread
        CreateThread(function()
            while IsKnockedDown do
                if KnockdownTime - 1 > 0 then
                    KnockdownTime = KnockdownTime - 1
                    Wait(1000)
                else
                    SetKnockdown(false)
                    SetLaststand(true)
                    break -- Exit loop immediately
                end
            end
        end)
    else
        isEnteringKnockdown = false
        IsKnockedDown = false
        IsBeingRevived = false
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

            Wait(100)
        else
            Wait(1000)
        end
    end
end)

-- Thread to maintain idle animation while being revived (minigame)
CreateThread(function()
    while true do
        if IsBeingRevived and IsKnockedDown then
            local ped = PlayerPedId()
            if not IsPedInAnyVehicle(ped, false) then
                -- Keep the idle animation playing while the minigame is active
                if not IsEntityPlayingAnim(ped, 'dead', 'dead_d', 3) then
                    LoadAnimDict('dead')
                    TaskPlayAnim(ped, 'dead', 'dead_d', 1.0, 1.0, -1, 1, 0, false, false, false)
                end
            end
        end
        Wait(100)
    end
end)

-- Export for qb-target to check if player is knocked down
exports('IsPlayerKnockedDown', function(entity)
    local targetPlayer = NetworkGetPlayerIndexFromPed(entity)
    if targetPlayer == -1 then return false end
    return IsTargetKnockedDown(GetPlayerServerId(targetPlayer))
end)

-- Event: Someone starts reviving you
RegisterNetEvent('hospital:client:BeingRevived', function()
    if not IsKnockedDown then return end
    IsBeingRevived = true
    QBCore.Functions.Notify(Lang:t('success.being_helped'), 'primary')
end)

-- Event: The helper left or walked away before finishing
RegisterNetEvent('hospital:client:ReviveCancelled', function()
    IsBeingRevived = false
end)

-- Event: Revive was cancelled or failed
RegisterNetEvent('hospital:client:ReviveFailed', function()
    IsBeingRevived = false
    if not IsKnockedDown then return end
    QBCore.Functions.Notify(Lang:t('error.revive_went_wrong'), 'error')
    SetKnockdown(false)
    SetLaststand(true)
end)

-- Event: Revive successful (knockdown specific - doesn't reset hunger/water/stress)
RegisterNetEvent('hospital:client:ReviveSuccess', function()
    IsBeingRevived = false
    local player = PlayerPedId()

    if IsKnockedDown then
        -- Resurrect the player without resetting hunger/water/stress
        local pos = GetEntityCoords(player, true)
        NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, GetEntityHeading(player), true, false)

        SetKnockdown(false)
        SetLaststand(false)
        SetEntityInvincible(player, false)

        -- Restore health only, don't reset hunger/water/stress
        SetEntityMaxHealth(player, 200)
        SetEntityHealth(player, 200)
        ClearPedBloodDamage(player)
        SetPlayerSprint(PlayerId(), true)
        ResetPedMovementClipset(player, 0.0)

        -- Update server status
        TriggerServerEvent('hospital:server:SetDeathStatus', false)
        TriggerServerEvent('hospital:server:SetLaststandStatus', false)
    end
end)

local function PlayReviveMinigame()
    if GetResourceState('qb-minigames') == 'started' then
        return exports['qb-minigames']:Skillbar()
    end

    -- Fallback when qb-minigames isn't running: a short progress bar
    local p = promise.new()
    QBCore.Functions.Progressbar('hospital_revive_knockdown', Lang:t('progress.revive'), 5000, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function()
        p:resolve(true)
    end, function()
        p:resolve(false)
    end)
    return Citizen.Await(p)
end

-- Event: Attempt to revive a knocked down player
RegisterNetEvent('hospital:client:ReviveKnockedDown', function(targetId)
    local ped = PlayerPedId()
    local animDict = 'anim@amb@business@weed@weed_inspecting_lo_med_hi@'
    local animName = 'weed_spraybottle_crouch_spraying_01_inspector'

    -- Load and play reviver animation in background
    CreateThread(function()
        LoadAnimDict(animDict)
        TaskPlayAnim(ped, animDict, animName, 1.0, 8.0, -1, 1, 0, false, false, false)
    end)

    local success = PlayReviveMinigame()
    ClearPedTasks(ped)
    if success then
        TriggerServerEvent('hospital:server:ReviveKnockedDownSuccess', targetId)
    else
        TriggerServerEvent('hospital:server:ReviveKnockedDownFailed', targetId)
    end
end)

-- Add qb-target interaction for knocked down players
CreateThread(function()
    if GetResourceState('qb-target') == 'missing' then
        print('^3[qb-ambulancejob] qb-target is not installed, knocked down players can only be revived by EMS^7')
        return
    end

    exports['qb-target']:AddGlobalPlayer({
        options = {
            {
                icon = 'fas fa-hand-holding-medical',
                label = Lang:t('text.revive'),
                action = function(entity)
                    local targetPlayer = NetworkGetPlayerIndexFromPed(entity)
                    if targetPlayer == -1 then return end
                    local targetServerId = GetPlayerServerId(targetPlayer)
                    TriggerServerEvent('hospital:server:AttemptReviveKnockedDown', targetServerId)
                end,
                canInteract = function(entity)
                    if isDead or InLaststand or IsKnockedDown then return false end
                    if not entity or not DoesEntityExist(entity) or not IsPedAPlayer(entity) then
                        return false
                    end
                    local targetPlayer = NetworkGetPlayerIndexFromPed(entity)
                    if targetPlayer == -1 or targetPlayer == PlayerId() then return false end
                    return IsTargetKnockedDown(GetPlayerServerId(targetPlayer))
                end
            }
        },
        distance = 2.5
    })
end)
