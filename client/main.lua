QBCore = exports['qb-core']:GetCoreObject()

local getOutDict = 'switch@franklin@bed'
local getOutAnim = 'sleep_getup_rubeyes'
local canLeaveBed = true
local bedOccupying = nil
local bedObject = nil
local bedOccupyingData = nil
local doctorCount = 0
local CurrentDamageList = {}
local cam = nil
local playerArmor = nil
local legInjuryTimer, armInjuryTimer, headInjuryTimer = 0, 0, 0
inBedDict = 'anim@gangops@morgue@table@'
inBedAnim = 'body_search'
isInHospitalBed = false
isBleeding = 0
bleedTickTimer, advanceBleedTimer = 0, 0
fadeOutTimer, blackoutTimer = 0, 0
playerHealth = nil
isDead = false
isStatusChecking = false
statusChecks = {}
statusCheckTime = 0
healAnimDict = 'mini@cpr@char_a@cpr_str'
healAnim = 'cpr_pumpchest'
injured = {}

local BodyParts = {
    ['HEAD'] = { label = Lang:t('body.head'), causeLimp = false, isDamaged = false, severity = 0 },
    ['NECK'] = { label = Lang:t('body.neck'), causeLimp = false, isDamaged = false, severity = 0 },
    ['SPINE'] = { label = Lang:t('body.spine'), causeLimp = true, isDamaged = false, severity = 0 },
    ['UPPER_BODY'] = { label = Lang:t('body.upper_body'), causeLimp = false, isDamaged = false, severity = 0 },
    ['LOWER_BODY'] = { label = Lang:t('body.lower_body'), causeLimp = true, isDamaged = false, severity = 0 },
    ['LARM'] = { label = Lang:t('body.left_arm'), causeLimp = false, isDamaged = false, severity = 0 },
    ['LHAND'] = { label = Lang:t('body.left_hand'), causeLimp = false, isDamaged = false, severity = 0 },
    ['LFINGER'] = { label = Lang:t('body.left_fingers'), causeLimp = false, isDamaged = false, severity = 0 },
    ['LLEG'] = { label = Lang:t('body.left_leg'), causeLimp = true, isDamaged = false, severity = 0 },
    ['LFOOT'] = { label = Lang:t('body.left_foot'), causeLimp = true, isDamaged = false, severity = 0 },
    ['RARM'] = { label = Lang:t('body.right_arm'), causeLimp = false, isDamaged = false, severity = 0 },
    ['RHAND'] = { label = Lang:t('body.right_hand'), causeLimp = false, isDamaged = false, severity = 0 },
    ['RFINGER'] = { label = Lang:t('body.right_fingers'), causeLimp = false, isDamaged = false, severity = 0 },
    ['RLEG'] = { label = Lang:t('body.right_leg'), causeLimp = true, isDamaged = false, severity = 0 },
    ['RFOOT'] = { label = Lang:t('body.right_foot'), causeLimp = true, isDamaged = false, severity = 0 },
}

-- Functions

function LoadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return end
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end
end

-- Brings the player back to life where they are, keeping them in their vehicle seat
function ResurrectPlayer(ped)
    local pos = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local veh = GetVehiclePedIsIn(ped, false)
    local seat
    if veh ~= 0 then
        -- GetEntityModel already returns the model hash
        for i = -1, GetVehicleModelNumberOfSeats(GetEntityModel(veh)) - 2 do
            if GetPedInVehicleSeat(veh, i) == ped then
                seat = i
                break
            end
        end
    end

    NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z + 0.5, heading, true, false)
    if seat then
        SetPedIntoVehicle(ped, veh, seat)
    end
end

local function GetDamagingWeapon(ped)
    for k, v in pairs(Config.Weapons) do
        if HasPedBeenDamagedByWeapon(ped, k, 0) then
            return v
        end
    end

    return nil
end

local function IsDamagingEvent(damageDone, weapon)
    local luck = math.random(100)
    local multi = damageDone / Config.HealthDamage

    return luck < (Config.HealthDamage * multi) or (damageDone >= Config.ForceInjury or multi > Config.MaxInjuryChanceMulti or Config.ForceInjuryWeapons[weapon])
end

local function SyncInjuries()
    TriggerServerEvent('hospital:server:SyncInjuries', {
        limbs = BodyParts,
        isBleeding = tonumber(isBleeding)
    })
end

local function DoLimbAlert()
    if not isDead and not InLaststand and not IsKnockedDown then
        if #injured > 0 then
            local limbDamageMsg = ''
            if #injured <= Config.AlertShowInfo then
                for k, v in pairs(injured) do
                    limbDamageMsg = limbDamageMsg .. Lang:t('info.pain_message', { limb = v.label, severity = Config.WoundStates[v.severity] })
                    if k < #injured then
                        limbDamageMsg = limbDamageMsg .. ' | '
                    end
                end
            else
                limbDamageMsg = Lang:t('info.many_places')
            end
            QBCore.Functions.Notify(limbDamageMsg, 'primary')
        end
    end
end

function DoBleedAlert()
    if not isDead and not IsKnockedDown and tonumber(isBleeding) > 0 then
        QBCore.Functions.Notify(Lang:t('info.bleed_alert', { bleedstate = Config.BleedingStates[tonumber(isBleeding)].label }), 'error', 5000)
    end
end

function ApplyBleed(level)
    if isBleeding ~= 4 then
        if isBleeding + level > 4 then
            isBleeding = 4
        else
            isBleeding = isBleeding + level
        end
        DoBleedAlert()
    end
end

local function IsInjuryCausingLimp()
    for _, v in pairs(BodyParts) do
        if v.causeLimp and v.isDamaged then
            return true
        end
    end
    return false
end

local function ProcessRunStuff(ped)
    if IsInjuryCausingLimp() then
        RequestAnimSet('move_m@injured')
        while not HasAnimSetLoaded('move_m@injured') do
            Wait(0)
        end
        SetPedMovementClipset(ped, 'move_m@injured', 1)
        SetPlayerSprint(PlayerId(), false)
    end
end

function ResetPartial()
    for _, v in pairs(BodyParts) do
        if v.isDamaged and v.severity <= 2 then
            v.isDamaged = false
            v.severity = 0
        end
    end

    -- Go backwards so removing an entry doesn't skip the next one
    for i = #injured, 1, -1 do
        if injured[i].severity <= 2 then
            table.remove(injured, i)
        end
    end

    if isBleeding <= 2 then
        isBleeding = 0
        bleedTickTimer = 0
        advanceBleedTimer = 0
        fadeOutTimer = 0
        blackoutTimer = 0
    end

    SyncInjuries()
    ProcessRunStuff(PlayerPedId())
    DoLimbAlert()
    DoBleedAlert()
end

local function ResetAll()
    isBleeding = 0
    bleedTickTimer = 0
    advanceBleedTimer = 0
    fadeOutTimer = 0
    blackoutTimer = 0
    injured = {}
    ClearPainkillers()

    for _, v in pairs(BodyParts) do
        v.isDamaged = false
        v.severity = 0
    end

    CurrentDamageList = {}
    SyncInjuries()
    TriggerServerEvent('hospital:server:SetWeaponDamage', CurrentDamageList)

    ProcessRunStuff(PlayerPedId())
    DoLimbAlert()
    DoBleedAlert()
end

local function SetBedCam()
    if not bedOccupyingData then return end
    isInHospitalBed = true
    canLeaveBed = false
    local player = PlayerPedId()

    DoScreenFadeOut(1000)

    while not IsScreenFadedOut() do
        Wait(100)
    end

    if IsPedDeadOrDying(player) then
        local pos = GetEntityCoords(player, true)
        NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, GetEntityHeading(player), true, false)
    end

    bedObject = GetClosestObjectOfType(bedOccupyingData.coords.x, bedOccupyingData.coords.y, bedOccupyingData.coords.z, 1.0, bedOccupyingData.model, false, false, false)
    FreezeEntityPosition(bedObject, true)

    SetEntityCoords(player, bedOccupyingData.coords.x, bedOccupyingData.coords.y, bedOccupyingData.coords.z + 0.02)

    Wait(500)
    FreezeEntityPosition(player, true)

    LoadAnimDict(inBedDict)

    TaskPlayAnim(player, inBedDict, inBedAnim, 8.0, 1.0, -1, 1, 0, 0, 0, 0)
    SetEntityHeading(player, bedOccupyingData.coords.w)

    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', 1)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 1, true, true)
    AttachCamToPedBone(cam, player, 31085, 0, 1.0, 1.0, true)
    SetCamFov(cam, 90.0)
    local heading = GetEntityHeading(player)
    heading = (heading > 180) and heading - 180 or heading + 180
    SetCamRot(cam, -45.0, 0.0, heading, 2)

    DoScreenFadeIn(1000)

    Wait(1000)
    FreezeEntityPosition(player, true)
end

local function ClearBedState()
    if cam then
        RenderScriptCams(false, true, 200, true, true)
        DestroyCam(cam, false)
        cam = nil
    end
    bedOccupying = nil
    bedObject = nil
    bedOccupyingData = nil
    isInHospitalBed = false
end

local function LeaveBed()
    local player = PlayerPedId()

    LoadAnimDict(getOutDict)

    FreezeEntityPosition(player, false)
    SetEntityInvincible(player, false)
    SetEntityHeading(player, bedOccupyingData.coords.w + 90)
    TaskPlayAnim(player, getOutDict, getOutAnim, 100.0, 1.0, -1, 8, -1, 0, 0, 0)
    Wait(4000)
    ClearPedTasks(player)
    TriggerServerEvent('hospital:server:LeaveBed')
    FreezeEntityPosition(bedObject, true)
    ClearBedState()

    QBCore.Functions.GetPlayerData(function(PlayerData)
        if PlayerData.metadata['injail'] > 0 then
            TriggerEvent('prison:client:Enter', PlayerData.metadata['injail'])
        end
    end)
end

local function IsInDamageList(damage)
    local retval = false
    if CurrentDamageList then
        for k, _ in pairs(CurrentDamageList) do
            if CurrentDamageList[k] == damage then
                retval = true
            end
        end
    end
    return retval
end

local function CheckWeaponDamage(ped)
    local detected = false
    for k, v in pairs(QBCore.Shared.Weapons) do
        if HasPedBeenDamagedByWeapon(ped, k, 0) then
            detected = true
            if not IsInDamageList(k) then
                TriggerEvent('chat:addMessage', {
                    color = { 255, 0, 0 },
                    multiline = false,
                    args = { Lang:t('info.status'), v.damagereason }
                })
                CurrentDamageList[#CurrentDamageList + 1] = k
            end
        end
    end
    if detected then
        TriggerServerEvent('hospital:server:SetWeaponDamage', CurrentDamageList)
    end
    ClearEntityLastDamageEntity(ped)
end

local function ApplyImmediateEffects(ped, bone, weapon, damageDone)
    local armor = GetPedArmour(ped)
    if Config.MinorInjurWeapons[weapon] and damageDone < Config.DamageMinorToMajor then
        if Config.CriticalAreas[Config.Bones[bone]] then
            if armor <= 0 then
                ApplyBleed(1)
            end
        end

        if Config.StaggerAreas[Config.Bones[bone]] and (Config.StaggerAreas[Config.Bones[bone]].armored or armor <= 0) then
            if math.random(100) <= math.ceil(Config.StaggerAreas[Config.Bones[bone]].minor) then
                SetPedToRagdoll(ped, 1500, 2000, 3, true, true, false)
            end
        end
    elseif Config.MajorInjurWeapons[weapon] or (Config.MinorInjurWeapons[weapon] and damageDone >= Config.DamageMinorToMajor) then
        if Config.CriticalAreas[Config.Bones[bone]] then
            if armor > 0 and Config.CriticalAreas[Config.Bones[bone]].armored then
                if math.random(100) <= math.ceil(Config.MajorArmoredBleedChance) then
                    ApplyBleed(1)
                end
            else
                ApplyBleed(1)
            end
        else
            if armor > 0 then
                if math.random(100) < (Config.MajorArmoredBleedChance) then
                    ApplyBleed(1)
                end
            else
                if math.random(100) < (Config.MajorArmoredBleedChance * 2) then
                    ApplyBleed(1)
                end
            end
        end

        if Config.StaggerAreas[Config.Bones[bone]] and (Config.StaggerAreas[Config.Bones[bone]].armored or armor <= 0) then
            if math.random(100) <= math.ceil(Config.StaggerAreas[Config.Bones[bone]].major) then
                SetPedToRagdoll(ped, 1500, 2000, 3, true, true, false)
            end
        end
    end
end

local function CheckDamage(ped, bone, weapon, damageDone)
    if weapon == nil then return end

    if Config.Bones[bone] and not isDead and not InLaststand then
        -- Only apply immediate effects (ragdoll/stagger) if not knocked down
        if not IsKnockedDown then
            ApplyImmediateEffects(ped, bone, weapon, damageDone)
        end

        if not BodyParts[Config.Bones[bone]].isDamaged then
            BodyParts[Config.Bones[bone]].isDamaged = true
            BodyParts[Config.Bones[bone]].severity = math.random(1, 3)
            injured[#injured + 1] = {
                part = Config.Bones[bone],
                label = BodyParts[Config.Bones[bone]].label,
                severity = BodyParts[Config.Bones[bone]].severity
            }
        else
            if BodyParts[Config.Bones[bone]].severity < 4 then
                BodyParts[Config.Bones[bone]].severity = BodyParts[Config.Bones[bone]].severity + 1

                for _, v in pairs(injured) do
                    if v.part == Config.Bones[bone] then
                        v.severity = BodyParts[Config.Bones[bone]].severity
                    end
                end
            end
        end

        -- Don't sync injuries or alert while knocked down
        if not IsKnockedDown then
            SyncInjuries()
            ProcessRunStuff(ped)
        end
    end
end

local function GetInjuryEffects()
    local leg, leftArm, rightArm, head = false, false, false, false
    for _, v in pairs(injured) do
        local part, severity = v.part, v.severity
        if ((part == 'LLEG' or part == 'RLEG') and severity > 1) or ((part == 'LFOOT' or part == 'RFOOT') and severity > 2) then
            leg = true
        elseif ((part == 'LARM' or part == 'LHAND') and severity > 1) or (part == 'LFINGER' and severity > 2) then
            leftArm = true
        elseif ((part == 'RARM' or part == 'RHAND') and severity > 1) or (part == 'RFINGER' and severity > 2) then
            rightArm = true
        elseif part == 'HEAD' and severity > 2 then
            head = true
        end
    end
    return leg, leftArm, rightArm, head
end

local function DisableArmControls(ped, isLeftArm)
    CreateThread(function()
        local endTime = GetGameTimer() + Config.ArmInjuryDisableTime
        while GetGameTimer() < endTime do
            if IsPedInAnyVehicle(ped, true) then
                DisableControlAction(0, 63, true) -- veh turn left
            end

            if IsPlayerFreeAiming(PlayerId()) then
                if isLeftArm then
                    DisablePlayerFiring(PlayerId(), true) -- Disable weapon firing
                else
                    DisableControlAction(0, 25, true) -- Disable aiming
                end
            end

            Wait(0)
        end
    end)
end

local function DoHeadInjuryEffect(ped)
    -- Runs in its own thread so the damage loop keeps tracking damage
    CreateThread(function()
        SetFlash(0, 0, 100, 10000, 100)

        DoScreenFadeOut(100)
        while not IsScreenFadedOut() do
            Wait(0)
        end

        if not IsPedRagdoll(ped) and IsPedOnFoot(ped) and not IsPedSwimming(ped) then
            ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.08) -- change this float to increase/decrease camera shake
            SetPedToRagdoll(ped, 5000, 1, 2)
        end

        Wait(5000)
        DoScreenFadeIn(250)
    end)
end

local function ProcessDamage(ped)
    if isDead or InLaststand or onPainKillers or IsKnockedDown then return end

    -- The injury timers in the config are in seconds, so track real time instead of loop ticks
    local now = GetGameTimer()
    local hasLegInjury, hasLeftArmInjury, hasRightArmInjury, hasHeadInjury = GetInjuryEffects()

    if not hasLegInjury then
        legInjuryTimer = now
    elseif now - legInjuryTimer >= Config.LegInjuryTimer * 1000 then
        legInjuryTimer = now
        if not IsPedRagdoll(ped) and IsPedOnFoot(ped) then
            local injuryChance = (IsPedRunning(ped) or IsPedSprinting(ped)) and Config.LegInjuryChance.Running or Config.LegInjuryChance.Walking
            if math.random(100) <= injuryChance then
                ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.08) -- change this float to increase/decrease camera shake
                SetPedToRagdollWithFall(ped, 1500, 2000, 1, GetEntityForwardVector(ped), 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
            end
        end
    end

    if not hasLeftArmInjury and not hasRightArmInjury then
        armInjuryTimer = now
    elseif now - armInjuryTimer >= Config.ArmInjuryTimer * 1000 then
        armInjuryTimer = now
        if hasLeftArmInjury then
            DisableArmControls(ped, true)
        end
        if hasRightArmInjury then
            DisableArmControls(ped, false)
        end
    end

    if not hasHeadInjury then
        headInjuryTimer = now
    elseif now - headInjuryTimer >= Config.HeadInjuryTimer * 1000 then
        headInjuryTimer = now
        if math.random(100) <= Config.HeadInjuryChance then
            DoHeadInjuryEffect(ped)
        end
    end
end

-- Events

RegisterNetEvent('hospital:client:ambulanceAlert', function(coords, text)
    local street1, street2 = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street1name = GetStreetNameFromHashKey(street1)
    local street2name = GetStreetNameFromHashKey(street2)
    QBCore.Functions.Notify({ text = text, caption = street1name .. ' ' .. street2name }, 'ambulance')
    PlaySound(-1, 'Lose_1st', 'GTAO_FM_Events_Soundset', 0, 0, 1)
    local transG = 250
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    local blip2 = AddBlipForCoord(coords.x, coords.y, coords.z)
    local blipText = Lang:t('info.ems_alert', { text = text })
    SetBlipSprite(blip, 153)
    SetBlipSprite(blip2, 161)
    SetBlipColour(blip, 1)
    SetBlipColour(blip2, 1)
    SetBlipDisplay(blip, 4)
    SetBlipDisplay(blip2, 8)
    SetBlipAlpha(blip, transG)
    SetBlipAlpha(blip2, transG)
    SetBlipScale(blip, 0.8)
    SetBlipScale(blip2, 2.0)
    SetBlipAsShortRange(blip, false)
    SetBlipAsShortRange(blip2, false)
    PulseBlip(blip2)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(blipText)
    EndTextCommandSetBlipName(blip)
    while transG > 0 do
        Wait(180 * 4)
        transG = transG - 1
        SetBlipAlpha(blip, transG)
        SetBlipAlpha(blip2, transG)
    end
    RemoveBlip(blip)
    RemoveBlip(blip2)
end)

RegisterNetEvent('hospital:client:Revive', function()
    local player = PlayerPedId()

    if isDead or InLaststand or IsKnockedDown then
        local pos = GetEntityCoords(player, true)
        NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, GetEntityHeading(player), true, false)
        isDead = false
        SetEntityInvincible(player, false)
    end
    -- Always clear these, it also cancels a knockdown or laststand that is still starting
    SetKnockdown(false)
    SetLaststand(false)

    if isInHospitalBed then
        LoadAnimDict(inBedDict)
        TaskPlayAnim(player, inBedDict, inBedAnim, 8.0, 1.0, -1, 1, 0, 0, 0, 0)
        SetEntityInvincible(player, true)
        canLeaveBed = true
    end

    TriggerServerEvent('hospital:server:RestoreWeaponDamage')
    SetEntityMaxHealth(player, 200)
    SetEntityHealth(player, 200)
    ClearPedBloodDamage(player)
    SetPlayerSprint(PlayerId(), true)
    ResetAll()
    ResetPedMovementClipset(player, 0.0)
    TriggerServerEvent('hud:server:RelieveStress', 100)
    TriggerServerEvent('hospital:server:SetDeathStatus', false)
    TriggerServerEvent('hospital:server:SetLaststandStatus', false)
    emsNotified = false
    QBCore.Functions.Notify(Lang:t('info.healthy'))
end)

RegisterNetEvent('hospital:client:SetPain', function()
    ApplyBleed(math.random(1, 4))
    if not BodyParts[Config.Bones[24816]].isDamaged then
        BodyParts[Config.Bones[24816]].isDamaged = true
        BodyParts[Config.Bones[24816]].severity = math.random(1, 4)
        injured[#injured + 1] = {
            part = Config.Bones[24816],
            label = BodyParts[Config.Bones[24816]].label,
            severity = BodyParts[Config.Bones[24816]].severity
        }
    end

    if not BodyParts[Config.Bones[40269]].isDamaged then
        BodyParts[Config.Bones[40269]].isDamaged = true
        BodyParts[Config.Bones[40269]].severity = math.random(1, 4)
        injured[#injured + 1] = {
            part = Config.Bones[40269],
            label = BodyParts[Config.Bones[40269]].label,
            severity = BodyParts[Config.Bones[40269]].severity
        }
    end

    SyncInjuries()
end)

RegisterNetEvent('hospital:client:KillPlayer', function()
    SetEntityHealth(PlayerPedId(), 0)
end)

RegisterNetEvent('hospital:client:HealInjuries', function(type)
    if type == 'full' then
        ResetAll()
    else
        ResetPartial()
    end
    TriggerServerEvent('hospital:server:RestoreWeaponDamage')
    QBCore.Functions.Notify(Lang:t('success.wounds_healed'), 'success')
end)

RegisterNetEvent('hospital:client:SendToBed', function(id, data, isRevive)
    if not data then return end
    bedOccupying = id
    bedOccupyingData = data
    SetBedCam()
    CreateThread(function()
        Wait(5)
        if isRevive then
            QBCore.Functions.Notify(Lang:t('success.being_helped'), 'success')
            Wait(Config.AIHealTimer * 1000)
            TriggerEvent('hospital:client:Revive')
        else
            canLeaveBed = true
        end
    end)
end)

RegisterNetEvent('hospital:client:SetBed', function(id, isTaken, hospitalIndex)
    local hospital = Config.Locations['hospital'][hospitalIndex]
    if hospital and hospital['beds'][id] then
        hospital['beds'][id].taken = isTaken
    end
end)

RegisterNetEvent('hospital:client:SetBed2', function(id, isTaken)
    if Config.Locations['jailbeds'][id] then
        Config.Locations['jailbeds'][id].taken = isTaken
    end
end)

RegisterNetEvent('hospital:client:RespawnAtHospital', function()
    -- The server picks the hospital (closest one when Config.RespawnAtNearestHospital is on)
    TriggerServerEvent('hospital:server:RespawnAtHospital')
    if GetResourceState('qb-policejob') == 'started' and exports['qb-policejob']:IsHandcuffed() then
        TriggerEvent('police:client:GetCuffed', -1)
    end
    TriggerEvent('police:client:DeEscort')
end)

RegisterNetEvent('hospital:client:SendBillEmail', function(amount, hospitalName)
    if GetResourceState('qb-phone') ~= 'started' then return end
    SetTimeout(math.random(2500, 4000), function()
        local gender = Lang:t('info.mr')
        if QBCore.Functions.GetPlayerData().charinfo.gender == 1 then
            gender = Lang:t('info.mrs')
        end
        local charinfo = QBCore.Functions.GetPlayerData().charinfo
        TriggerServerEvent('qb-phone:server:sendNewMail', {
            sender = hospitalName or Lang:t('info.pb_hospital'),
            subject = Lang:t('mail.subject'),
            message = Lang:t('mail.message', { gender = gender, lastname = charinfo.lastname, costs = amount }),
            button = {}
        })
    end)
end)

RegisterNetEvent('hospital:client:SetDoctorCount', function(amount)
    doctorCount = amount
end)

RegisterNetEvent('hospital:client:adminHeal', function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, 200)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    local ped = PlayerPedId()
    TriggerServerEvent('hospital:server:SetArmor')
    if bedOccupying then
        TriggerServerEvent('hospital:server:LeaveBed')
        FreezeEntityPosition(ped, false)
        ClearBedState()
    end
    -- The death state stays saved on the server, so logging out while dead doesn't revive the player
    isDead = false
    deathTime = 0
    InLaststand = false
    LaststandTime = 0
    IsKnockedDown = false
    KnockdownTime = 0
    IsBeingRevived = false
    SetEntityInvincible(ped, false)
    ResetAll()
end)

-- Threads

CreateThread(function()
    for i = 1, #Config.Locations['stations'] do
        local station = Config.Locations['stations'][i]
        local blip = AddBlipForCoord(station.coords.x, station.coords.y, station.coords.z)
        SetBlipSprite(blip, 61)
        SetBlipAsShortRange(blip, true)
        SetBlipScale(blip, 0.8)
        SetBlipColour(blip, 25)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(station.label)
        EndTextCommandSetBlipName(blip)
    end
end)

CreateThread(function()
    while true do
        local sleep = 1000
        if isInHospitalBed and canLeaveBed then
            sleep = 0
            exports['qb-core']:DrawText(Lang:t('text.bed_out'))
            if IsControlJustReleased(0, 38) then
                exports['qb-core']:KeyPressed(38)
                LeaveBed()
                exports['qb-core']:HideText()
            end
        end
        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        Wait((1000 * Config.MessageTimer))
        DoLimbAlert()
    end
end)

CreateThread(function()
    while true do
        Wait(1000)
        if isStatusChecking then
            statusCheckTime = statusCheckTime - 1
            if statusCheckTime <= 0 then
                statusChecks = {}
                isStatusChecking = false
            end
        end
    end
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local health = GetEntityHealth(ped)
        local armor = GetPedArmour(ped)

        if not playerHealth then
            playerHealth = health
        end

        if not playerArmor then
            playerArmor = armor
        end

        local armorDamaged = (playerArmor ~= armor and armor < (playerArmor - Config.ArmorDamage) and armor > 0) -- Players armor was damaged
        local healthDamaged = (playerHealth ~= health)                                                           -- Players health was damaged

        local damageDone = (playerHealth - health)

        if armorDamaged or healthDamaged then
            local hit, bone = GetPedLastDamageBone(ped)
            local bodypart = Config.Bones[bone]
            local weapon = GetDamagingWeapon(ped)

            if hit and bodypart ~= 'NONE' then
                local checkDamage = true
                if damageDone >= Config.HealthDamage then
                    if weapon then
                        if armorDamaged and (bodypart == 'SPINE' or bodypart == 'UPPER_BODY') or weapon == Config.WeaponClasses['NOTHING'] then
                            checkDamage = false -- Don't check damage if the it was a body shot and the weapon class isn't that strong
                            if armorDamaged then
                                TriggerServerEvent('hospital:server:SetArmor')
                            end
                        end

                        if checkDamage then
                            if IsDamagingEvent(damageDone, weapon) then
                                CheckDamage(ped, bone, weapon, damageDone)
                            end
                        end
                    end
                elseif Config.AlwaysBleedChanceWeapons[weapon] then
                    if armorDamaged and (bodypart == 'SPINE' or bodypart == 'UPPER_BODY') or weapon == Config.WeaponClasses['NOTHING'] then
                        checkDamage = false -- Don't check damage if the it was a body shot and the weapon class isn't that strong
                    end
                    if math.random(100) < Config.AlwaysBleedChance and checkDamage then
                        ApplyBleed(1)
                    end
                end
            end

            CheckWeaponDamage(ped)
        end

        playerHealth = health
        playerArmor = armor

        if not isInHospitalBed then
            ProcessDamage(ped)
        end
        Wait(100)
    end
end)

local listen = false
-- variable - 'checkin' or 'beds'
-- hospitalIndex - index referring to the key of the hospital key/value pairs
local function CheckInControls(variable, hospitalIndex, bedId)
    CreateThread(function()
        listen = true
        while listen do
            if IsControlJustPressed(0, 38) then
                exports['qb-core']:KeyPressed(38)
                if variable == 'checkin' then
                    TriggerEvent('qb-ambulancejob:checkin')
                    listen = false
                elseif variable == 'beds' then
                    TriggerEvent('qb-ambulancejob:beds', hospitalIndex, bedId)
                    listen = false
                end
            end
            Wait(1)
        end
    end)
end

RegisterNetEvent('qb-ambulancejob:checkin', function()
    local coords = GetEntityCoords(PlayerPedId())
    for i = 1, #Config.Locations['hospital'] do
        local distance = #(coords - Config.Locations['hospital'][i]['location'])
        if distance < 3 then
            if doctorCount >= Config.MinimalDoctors then
                TriggerServerEvent('hospital:server:SendDoctorAlert', i)
            else
                TriggerEvent('animations:client:EmoteCommandStart', { 'notepad' })
                QBCore.Functions.Progressbar('hospital_checkin', Lang:t('progress.checking_in'), 2000, false, true, {
                    disableMovement = true,
                    disableCarMovement = true,
                    disableMouse = false,
                    disableCombat = true,
                }, {
                    animDict = 'missheistdockssetup1clipboard@base',
                    anim = 'base',
                    flags = 33,
                }, {
                    model = 'prop_notepad_01',
                    bone = 18905,
                    coords = { x = 0.1, y = 0.02, z = 0.05 },
                    rotation = { x = 10.0, y = 0.0, z = 0.0 },
                }, {
                    model = 'prop_pencil_01',
                    bone = 58866,
                    coords = { x = 0.11, y = -0.02, z = 0.001 },
                    rotation = { x = -120.0, y = 0.0, z = 0.0 },
                }, function() -- Done
                    TriggerEvent('animations:client:EmoteCommandStart', { 'c' })
                    -- The server picks a free bed
                    TriggerServerEvent('hospital:server:SendToBed', nil, true, i)
                end)
            end
            return
        end
    end
end)

RegisterNetEvent('qb-ambulancejob:beds', function(hospitalIndex, bedId)
    -- qb-target passes its option table instead of the two values
    if type(hospitalIndex) == 'table' then
        bedId = hospitalIndex.bedId
        hospitalIndex = hospitalIndex.hospitalIndex
    end

    local hospital = Config.Locations['hospital'][hospitalIndex]
    local bed = hospital and hospital['beds'][bedId]
    if not bed or bed.taken then
        QBCore.Functions.Notify(Lang:t('error.beds_taken'), 'error')
        return
    end
    TriggerServerEvent('hospital:server:SendToBed', bedId, false, hospitalIndex)
end)

-- Convar turns into a boolean
if Config.UseTarget then
    CreateThread(function()
        for i = 1, #Config.Locations['checking'] do
            local v = Config.Locations['checking'][i]
            exports['qb-target']:AddBoxZone('checking' .. i, vector3(v.x, v.y, v.z), 3.5, 2, {
                name = 'checking' .. i,
                heading = -72,
                debugPoly = false,
                minZ = v.z - 2,
                maxZ = v.z + 2,
            }, {
                options = {
                    {
                        type = 'client',
                        icon = 'fa fa-clipboard',
                        event = 'qb-ambulancejob:checkin',
                        label = Lang:t('text.check'),
                    }
                },
                distance = 1.5
            })
        end

        for hospitalKey = 1, #Config.Locations['hospital'] do
            for bedKey = 1, #Config.Locations['hospital'][hospitalKey]['beds'] do
                local v = Config.Locations['hospital'][hospitalKey]['beds'][bedKey]
                local zoneName = 'beds' .. hospitalKey .. '_' .. bedKey
                exports['qb-target']:AddBoxZone(zoneName, vector3(v.coords.x, v.coords.y, v.coords.z), 2.5, 2.3, {
                    name = zoneName,
                    heading = -20,
                    debugPoly = false,
                    minZ = v.coords.z - 1,
                    maxZ = v.coords.z + 1,
                }, {
                    options = {
                        {
                            type = 'client',
                            event = 'qb-ambulancejob:beds',
                            icon = 'fas fa-bed',
                            label = Lang:t('text.lay_bed'),
                            hospitalIndex = hospitalKey,
                            bedId = bedKey,
                        }
                    },
                    distance = 1.5
                })
            end
        end
    end)
else
    CreateThread(function()
        local checkingPoly = {}
        for i = 1, #Config.Locations['checking'] do
            local v = Config.Locations['checking'][i]
            checkingPoly[#checkingPoly + 1] = BoxZone:Create(vector3(v.x, v.y, v.z), 3.5, 2, {
                heading = -72,
                name = 'checkin' .. i,
                debugPoly = false,
                minZ = v.z - 2,
                maxZ = v.z + 2,
            })
        end

        local checkingCombo = ComboZone:Create(checkingPoly, { name = 'checkingCombo', debugPoly = false })
        checkingCombo:onPlayerInOut(function(isPointInside)
            if isPointInside then
                if doctorCount >= Config.MinimalDoctors then
                    exports['qb-core']:DrawText(Lang:t('text.call_doc'), 'left')
                else
                    exports['qb-core']:DrawText(Lang:t('text.check_in'), 'left')
                end
                CheckInControls('checkin')
            else
                listen = false
                exports['qb-core']:HideText()
            end
        end)

        local bedPoly = {}
        for hospitalKey = 1, #Config.Locations['hospital'] do
            for bedKey = 1, #Config.Locations['hospital'][hospitalKey]['beds'] do
                local v = Config.Locations['hospital'][hospitalKey]['beds'][bedKey]
                bedPoly[#bedPoly + 1] = BoxZone:Create(vector3(v.coords.x, v.coords.y, v.coords.z), 2.5, 2.3, {
                    name = 'beds' .. hospitalKey .. '_' .. bedKey,
                    heading = -20,
                    debugPoly = false,
                    minZ = v.coords.z - 1,
                    maxZ = v.coords.z + 1,
                    data = {
                        hospitalIndex = hospitalKey,
                        bedId = bedKey,
                    },
                })
            end
        end

        local bedCombo = ComboZone:Create(bedPoly, { name = 'bedCombo', debugPoly = false })
        bedCombo:onPlayerInOut(function(isPointInside, _, zone)
            if isPointInside and zone and not isInHospitalBed then
                exports['qb-core']:DrawText(Lang:t('text.lie_bed'), 'left')
                CheckInControls('beds', zone.data.hospitalIndex, zone.data.bedId)
            else
                listen = false
                exports['qb-core']:HideText()
            end
        end)
    end)
end
