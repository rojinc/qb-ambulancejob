local QBCore = exports['qb-core']:GetCoreObject()
local PlayerInjuries = {}
local PlayerWeaponWounds = {}
local doctorCount = 0
local doctorCalled = {}
local BedOccupants = { hospital = {}, jail = {} } -- [bedId] = source of the player in that bed
local PlayerBeds = {}                             -- [source] = { type, hospital, id }
local FirstAidRequests = {}                       -- [helper source] = target source
local KnockdownRevives = {}                       -- [helper source] = target source
local Cooldowns = {}
local ConsumableItems = { bandage = true, ifaks = true, painkillers = true }

local BodyPartLabels = {
	['HEAD'] = 'body.head',
	['NECK'] = 'body.neck',
	['SPINE'] = 'body.spine',
	['UPPER_BODY'] = 'body.upper_body',
	['LOWER_BODY'] = 'body.lower_body',
	['LARM'] = 'body.left_arm',
	['LHAND'] = 'body.left_hand',
	['LFINGER'] = 'body.left_fingers',
	['LLEG'] = 'body.left_leg',
	['LFOOT'] = 'body.left_foot',
	['RARM'] = 'body.right_arm',
	['RHAND'] = 'body.right_hand',
	['RFINGER'] = 'body.right_fingers',
	['RLEG'] = 'body.right_leg',
	['RFOOT'] = 'body.right_foot',
}

-- Functions

local function IsOnDutyEMS(Player)
	return Player.PlayerData.job.name == 'ambulance' and Player.PlayerData.job.onduty
end

local function IsPlayerDown(Player)
	local metadata = Player.PlayerData.metadata
	return metadata['isdead'] or metadata['inlaststand'] or metadata['isknockeddown'] or false
end

local function GetPlayerCoords(src)
	return GetEntityCoords(GetPlayerPed(src))
end

local function IsNearCoords(src, coords, maxDistance)
	return #(GetPlayerCoords(src) - vector3(coords.x, coords.y, coords.z)) <= maxDistance
end

local function ArePlayersNear(src, target, maxDistance)
	return #(GetPlayerCoords(src) - GetPlayerCoords(target)) <= maxDistance
end

local function Clamp(value, min, max)
	value = math.floor(tonumber(value) or 0)
	return math.max(min, math.min(max, value))
end

local function IsOnCooldown(src, key, seconds)
	Cooldowns[src] = Cooldowns[src] or {}
	local now = os.time()
	if Cooldowns[src][key] and now - Cooldowns[src][key] < seconds then
		return true
	end
	Cooldowns[src][key] = now
	return false
end

local function SanitizeText(text)
	if type(text) ~= 'string' then return nil end
	return text:gsub('[<>]', ''):sub(1, 150)
end

local function LogSuspicious(src, reason)
	TriggerEvent('qb-log:server:CreateLog', 'ambulancejob', 'Suspicious Request', 'red', string.format('%s (%s) %s', GetPlayerName(src), src, reason))
end

local function GetDoctorCount()
	local amount = 0
	for _, v in pairs(QBCore.Functions.GetQBPlayers()) do
		if IsOnDutyEMS(v) then
			amount = amount + 1
		end
	end
	return amount
end

local function UpdateDoctorCount()
	local count = GetDoctorCount()
	if count ~= doctorCount then
		doctorCount = count
		TriggerClientEvent('hospital:client:SetDoctorCount', -1, doctorCount)
	end
end

local function AlertEMS(coords, text)
	for _, v in pairs(QBCore.Functions.GetQBPlayers()) do
		if IsOnDutyEMS(v) then
			TriggerClientEvent('hospital:client:ambulanceAlert', v.PlayerData.source, coords, text)
		end
	end
end

local function ResetNeeds(src)
	local Player = QBCore.Functions.GetPlayer(src)
	if not Player then return end
	Player.Functions.SetMetaData('hunger', 100)
	Player.Functions.SetMetaData('thirst', 100)
	TriggerClientEvent('hud:client:UpdateNeeds', src, 100, 100)
end

local function ChargeBill(src, Player, hospitalName)
	-- Only pay the hospital when the player was actually charged
	if not Player.Functions.RemoveMoney('bank', Config.BillCost, 'respawned-at-hospital') then return end
	if GetResourceState('qb-banking') == 'started' then
		exports['qb-banking']:AddMoney('ambulance', Config.BillCost, 'Player treatment')
	end
	TriggerClientEvent('hospital:client:SendBillEmail', src, Config.BillCost, hospitalName)
end

local function WipeInventory(src, Player)
	if not Config.WipeInventoryOnRespawn then return end
	Player.Functions.ClearInventory()
	MySQL.update('UPDATE players SET inventory = ? WHERE citizenid = ?', { json.encode({}), Player.PlayerData.citizenid })
	TriggerClientEvent('QBCore:Notify', src, Lang:t('error.possessions_taken'), 'error')
end

local function GetClosestHospital(src)
	if not Config.RespawnAtNearestHospital then return 1 end
	local coords = GetPlayerCoords(src)
	local closestHospital, lowestDist = 1, nil
	for i = 1, #Config.Locations['hospital'] do
		local dist = #(coords - Config.Locations['hospital'][i]['location'])
		if not lowestDist or dist < lowestDist then
			closestHospital, lowestDist = i, dist
		end
	end
	return closestHospital
end

-- Beds are tracked here so every player gets a free bed and leaving frees the right one

local function GetBeds(bedType, hospitalIndex)
	if bedType == 'jail' then
		return Config.Locations['jailbeds'], BedOccupants.jail
	end
	local hospital = Config.Locations['hospital'][hospitalIndex]
	if not hospital then return end
	BedOccupants.hospital[hospitalIndex] = BedOccupants.hospital[hospitalIndex] or {}
	return hospital['beds'], BedOccupants.hospital[hospitalIndex]
end

local function IsBedTaken(occupants, bedId)
	local occupant = occupants[bedId]
	return occupant ~= nil and QBCore.Functions.GetPlayer(occupant) ~= nil
end

local function SyncBed(bedType, hospitalIndex, bedId, isTaken)
	if bedType == 'jail' then
		TriggerClientEvent('hospital:client:SetBed2', -1, bedId, isTaken)
	else
		TriggerClientEvent('hospital:client:SetBed', -1, bedId, isTaken, hospitalIndex)
	end
end

local function FreeBed(src)
	local bed = PlayerBeds[src]
	if not bed then return end
	PlayerBeds[src] = nil
	local _, occupants = GetBeds(bed.type, bed.hospital)
	if occupants and occupants[bed.id] == src then
		occupants[bed.id] = nil
		SyncBed(bed.type, bed.hospital, bed.id, false)
	end
end

local function GetFreeBed(bedType, hospitalIndex)
	local beds, occupants = GetBeds(bedType, hospitalIndex)
	if not beds then return end
	for i = 1, #beds do
		if not IsBedTaken(occupants, i) then
			return i
		end
	end
	return 1 -- All beds are taken, use the first bed as a fallback
end

local function SendToBed(src, bedType, hospitalIndex, bedId, isRevive)
	local beds, occupants = GetBeds(bedType, hospitalIndex)
	if not beds or not beds[bedId] then return false end
	FreeBed(src)
	occupants[bedId] = src
	PlayerBeds[src] = { type = bedType, hospital = hospitalIndex, id = bedId }
	TriggerClientEvent('hospital:client:SendToBed', src, bedId, beds[bedId], isRevive)
	SyncBed(bedType, hospitalIndex, bedId, true)
	return true
end

local function CleanupPlayer(src)
	FreeBed(src)
	FirstAidRequests[src] = nil
	local target = KnockdownRevives[src]
	if target then
		KnockdownRevives[src] = nil
		TriggerClientEvent('hospital:client:ReviveCancelled', target)
	end
	for helper, revivedTarget in pairs(KnockdownRevives) do
		if revivedTarget == src then
			KnockdownRevives[helper] = nil
		end
	end
	SetTimeout(1000, UpdateDoctorCount)
end

-- Events

-- Compatibility with txAdmin Menu's heal options.
-- This is an admin only server side event that will pass the target player id or -1.
AddEventHandler('txAdmin:events:healedPlayer', function(eventData)
	if GetInvokingResource() ~= 'monitor' or type(eventData) ~= 'table' or type(eventData.id) ~= 'number' then
		return
	end

	TriggerClientEvent('hospital:client:Revive', eventData.id)
	TriggerClientEvent('hospital:client:HealInjuries', eventData.id, 'full')
	if eventData.id == -1 then
		for _, v in pairs(QBCore.Functions.GetQBPlayers()) do
			ResetNeeds(v.PlayerData.source)
		end
	else
		ResetNeeds(eventData.id)
	end
end)

RegisterNetEvent('hospital:server:SendToBed', function(bedId, isRevive, hospitalIndex)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	hospitalIndex = tonumber(hospitalIndex)
	local hospital = hospitalIndex and Config.Locations['hospital'][hospitalIndex]
	if not Player or not hospital then return end

	if isRevive then
		-- Checking in is only allowed at the desk and only when not enough doctors are on duty
		if not IsNearCoords(src, hospital['location'], 5.0) then return end
		if GetDoctorCount() >= Config.MinimalDoctors then
			TriggerClientEvent('QBCore:Notify', src, Lang:t('error.doctors_on_duty'), 'error')
			return
		end
		bedId = GetFreeBed('hospital', hospitalIndex)
	else
		bedId = tonumber(bedId)
		local _, occupants = GetBeds('hospital', hospitalIndex)
		local bed = bedId and hospital['beds'][bedId]
		if not bed or not IsNearCoords(src, bed.coords, 4.0) then return end
		if IsBedTaken(occupants, bedId) and occupants[bedId] ~= src then
			TriggerClientEvent('QBCore:Notify', src, Lang:t('error.beds_taken'), 'error')
			return
		end
	end

	if not SendToBed(src, 'hospital', hospitalIndex, bedId, isRevive == true) then return end
	ChargeBill(src, Player, hospital['name'])
	if isRevive then
		ResetNeeds(src)
	end
end)

RegisterNetEvent('hospital:server:RespawnAtHospital', function()
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	-- Only dead players can respawn, and only once per death
	if not Player or not Player.PlayerData.metadata['isdead'] or PlayerBeds[src] then return end

	local hospitalName
	if (Player.PlayerData.metadata['injail'] or 0) > 0 then
		SendToBed(src, 'jail', nil, GetFreeBed('jail'), true)
		hospitalName = Lang:t('info.jail_hospital')
	else
		local hospitalIndex = GetClosestHospital(src)
		SendToBed(src, 'hospital', hospitalIndex, GetFreeBed('hospital', hospitalIndex), true)
		hospitalName = Config.Locations['hospital'][hospitalIndex]['name']
	end

	WipeInventory(src, Player)
	ChargeBill(src, Player, hospitalName)
	ResetNeeds(src)
end)

RegisterNetEvent('hospital:server:ambulanceAlert', function(text)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	-- Only players that are down can send these alerts
	if not Player or not IsPlayerDown(Player) then return end
	if IsOnCooldown(src, 'alert', Config.AlertCooldown) then return end
	AlertEMS(GetPlayerCoords(src), SanitizeText(text) or Lang:t('info.civ_down'))
end)

RegisterNetEvent('hospital:server:LeaveBed', function()
	FreeBed(source)
end)

RegisterNetEvent('hospital:server:SyncInjuries', function(data)
	local src = source
	if type(data) ~= 'table' or type(data.limbs) ~= 'table' then return end

	-- Only keep known body parts with sane values, so bad data can't break the EMS status check
	local limbs = {}
	for part, labelKey in pairs(BodyPartLabels) do
		local limb = data.limbs[part]
		if type(limb) == 'table' then
			local isDamaged = limb.isDamaged == true
			limbs[part] = {
				label = Lang:t(labelKey),
				isDamaged = isDamaged,
				severity = isDamaged and Clamp(limb.severity, 1, 4) or 0,
			}
		end
	end

	PlayerInjuries[src] = {
		limbs = limbs,
		isBleeding = Clamp(data.isBleeding, 0, 4),
	}
end)

RegisterNetEvent('hospital:server:SetWeaponDamage', function(data)
	local src = source
	if type(data) ~= 'table' then return end
	local wounds = {}
	for _, weapon in pairs(data) do
		if QBCore.Shared.Weapons[weapon] then
			wounds[#wounds + 1] = weapon
		end
		if #wounds >= 25 then break end
	end
	PlayerWeaponWounds[src] = wounds
end)

RegisterNetEvent('hospital:server:RestoreWeaponDamage', function()
	PlayerWeaponWounds[source] = nil
end)

RegisterNetEvent('hospital:server:SetDeathStatus', function(isDead)
	local src = source
	if type(isDead) ~= 'boolean' then return end
	local Player = QBCore.Functions.GetPlayer(src)
	if Player then
		Player.Functions.SetMetaData('isdead', isDead)
	end
end)

RegisterNetEvent('hospital:server:SetLaststandStatus', function(bool)
	local src = source
	if type(bool) ~= 'boolean' then return end
	local Player = QBCore.Functions.GetPlayer(src)
	if Player then
		Player.Functions.SetMetaData('inlaststand', bool)
	end
end)

RegisterNetEvent('hospital:server:SetKnockdownStatus', function(bool)
	local src = source
	if type(bool) ~= 'boolean' then return end
	-- Replicated so other clients can check it without asking the server
	Player(src).state:set('isKnockedDown', bool, true)
	local QBPlayer = QBCore.Functions.GetPlayer(src)
	if QBPlayer then
		QBPlayer.Functions.SetMetaData('isknockeddown', bool)
	end
end)

-- Callback to check if player is knocked down
QBCore.Functions.CreateCallback('hospital:server:IsPlayerKnockedDown', function(_, cb, targetId)
	local Player = QBCore.Functions.GetPlayer(tonumber(targetId))
	if Player then
		cb(Player.PlayerData.metadata['isknockeddown'] or false)
	else
		cb(false)
	end
end)

-- Event: Player attempts to revive knocked down player
RegisterNetEvent('hospital:server:AttemptReviveKnockedDown', function(targetId)
	local src = source
	targetId = tonumber(targetId)
	local Player = QBCore.Functions.GetPlayer(src)
	local Target = targetId and QBCore.Functions.GetPlayer(targetId)
	if not Player or not Target or targetId == src then return end
	if IsPlayerDown(Player) or not Target.PlayerData.metadata['isknockeddown'] then return end
	if not ArePlayersNear(src, targetId, 3.0) then return end
	for helper, revivedTarget in pairs(KnockdownRevives) do
		if revivedTarget == targetId and helper ~= src then return end -- Someone else is already helping
	end

	KnockdownRevives[src] = targetId
	-- Notify the knocked down player
	TriggerClientEvent('hospital:client:BeingRevived', targetId, src)
	-- Start the minigame for the helper
	TriggerClientEvent('hospital:client:ReviveKnockedDown', src, targetId)
end)

-- Event: Revive minigame succeeded
RegisterNetEvent('hospital:server:ReviveKnockedDownSuccess', function(targetId)
	local src = source
	targetId = tonumber(targetId)
	-- Only the player that started this revive can finish it
	if not targetId or KnockdownRevives[src] ~= targetId then return end
	KnockdownRevives[src] = nil

	local Target = QBCore.Functions.GetPlayer(targetId)
	if not Target or not Target.PlayerData.metadata['isknockeddown'] then return end
	if not ArePlayersNear(src, targetId, 5.0) then
		TriggerClientEvent('hospital:client:ReviveCancelled', targetId)
		TriggerClientEvent('QBCore:Notify', src, Lang:t('error.too_far'), 'error')
		return
	end

	TriggerClientEvent('hospital:client:ReviveSuccess', targetId)
	TriggerClientEvent('QBCore:Notify', src, Lang:t('success.revived_knocked'), 'success')
end)

-- Event: Revive minigame failed
RegisterNetEvent('hospital:server:ReviveKnockedDownFailed', function(targetId)
	local src = source
	targetId = tonumber(targetId)
	-- Only the player that started this revive can fail it
	if not targetId or KnockdownRevives[src] ~= targetId then return end
	KnockdownRevives[src] = nil

	if QBCore.Functions.GetPlayer(targetId) then
		TriggerClientEvent('hospital:client:ReviveFailed', targetId)
		TriggerClientEvent('QBCore:Notify', src, Lang:t('error.revive_failed'), 'error')
	end
end)

RegisterNetEvent('hospital:server:SetArmor', function()
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	if Player then
		-- Read the armour from the ped instead of trusting a value sent by the client
		Player.Functions.SetMetaData('armor', GetPedArmour(GetPlayerPed(src)))
	end
end)

RegisterNetEvent('hospital:server:TreatWounds', function(playerId)
	local src = source
	playerId = tonumber(playerId)
	local Player = QBCore.Functions.GetPlayer(src)
	local Patient = playerId and QBCore.Functions.GetPlayer(playerId)
	if not Player or not Patient or playerId == src or not IsOnDutyEMS(Player) then return end
	if not ArePlayersNear(src, playerId, 10.0) then
		TriggerClientEvent('QBCore:Notify', src, Lang:t('error.too_far'), 'error')
		return
	end
	if not exports['qb-inventory']:RemoveItem(src, 'bandage', 1, false, 'hospital:server:TreatWounds') then
		TriggerClientEvent('QBCore:Notify', src, Lang:t('error.no_bandage'), 'error')
		return
	end
	TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items['bandage'], 'remove')
	TriggerClientEvent('hospital:client:HealInjuries', playerId, 'full')
end)

RegisterNetEvent('hospital:server:RevivePlayer', function(playerId, isOldMan)
	local src = source
	playerId = tonumber(playerId)
	local Player = QBCore.Functions.GetPlayer(src)
	local Patient = playerId and QBCore.Functions.GetPlayer(playerId)
	if not Player or not Patient or playerId == src then return end

	if IsOnDutyEMS(Player) then
		if not IsPlayerDown(Patient) then return end
	elseif FirstAidRequests[src] ~= playerId or not Patient.PlayerData.metadata['inlaststand'] then
		-- Civilians can only finish a first aid request they started, on a player that is bleeding out
		LogSuspicious(src, 'tried to revive player ' .. playerId .. ' without a valid first aid request')
		TriggerClientEvent('QBCore:Notify', src, Lang:t('error.cant_help'), 'error')
		return
	end
	FirstAidRequests[src] = nil

	if not ArePlayersNear(src, playerId, 10.0) then
		TriggerClientEvent('QBCore:Notify', src, Lang:t('error.too_far'), 'error')
		return
	end
	if not QBCore.Functions.HasItem(src, 'firstaid', 1) then
		TriggerClientEvent('QBCore:Notify', src, Lang:t('error.no_firstaid'), 'error')
		return
	end
	if isOldMan and not Player.Functions.RemoveMoney('cash', 5000, 'revived-player') then
		TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_enough_money'), 'error')
		return
	end

	exports['qb-inventory']:RemoveItem(src, 'firstaid', 1, false, 'hospital:server:RevivePlayer')
	TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items['firstaid'], 'remove')
	TriggerClientEvent('hospital:client:Revive', playerId)
	ResetNeeds(playerId)
end)

RegisterNetEvent('hospital:server:SendDoctorAlert', function(hospitalIndex)
	local src = source
	hospitalIndex = tonumber(hospitalIndex)
	local hospital = hospitalIndex and Config.Locations['hospital'][hospitalIndex]
	if not hospital or not IsNearCoords(src, hospital['location'], 5.0) then return end

	if doctorCalled[hospitalIndex] then
		TriggerClientEvent('QBCore:Notify', src, Lang:t('error.doctor_already_called'), 'error')
		return
	end

	doctorCalled[hospitalIndex] = true
	for _, v in pairs(QBCore.Functions.GetQBPlayers()) do
		if IsOnDutyEMS(v) then
			TriggerClientEvent('QBCore:Notify', v.PlayerData.source, Lang:t('info.dr_needed', { hospital = hospital['name'] }), 'ambulance')
		end
	end
	TriggerClientEvent('QBCore:Notify', src, Lang:t('info.doctor_called'), 'primary')
	SetTimeout(Config.DocCooldown * 60000, function()
		doctorCalled[hospitalIndex] = nil
	end)
end)

RegisterNetEvent('hospital:server:UseFirstAid', function(targetId)
	local src = source
	targetId = tonumber(targetId)
	local Player = QBCore.Functions.GetPlayer(src)
	local Target = targetId and QBCore.Functions.GetPlayer(targetId)
	if not Player or not Target or targetId == src then return end
	if not QBCore.Functions.HasItem(src, 'firstaid', 1) or not ArePlayersNear(src, targetId, 3.0) then return end

	FirstAidRequests[src] = targetId
	TriggerClientEvent('hospital:client:CanHelp', targetId, src)
end)

RegisterNetEvent('hospital:server:CanHelp', function(helperId, canHelp)
	local src = source
	helperId = tonumber(helperId)
	-- Only answer a first aid request that was really made on this player
	if not helperId or FirstAidRequests[helperId] ~= src then return end

	if canHelp then
		TriggerClientEvent('hospital:client:HelpPerson', helperId, src)
	else
		FirstAidRequests[helperId] = nil
		TriggerClientEvent('QBCore:Notify', helperId, Lang:t('error.cant_help'), 'error')
	end
end)

RegisterNetEvent('qb-ambulancejob:server:stash', function()
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	if not Player or Player.PlayerData.job.name ~= 'ambulance' then return end
	if not Player.PlayerData.job.onduty then
		TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_on_duty'), 'error')
		return
	end

	for i = 1, #Config.Locations['stash'] do
		if IsNearCoords(src, Config.Locations['stash'][i], 3.0) then
			exports['qb-inventory']:OpenInventory(src, 'ambulancestash_' .. Player.PlayerData.citizenid)
			return
		end
	end
end)

-- Keep the doctor count in sync with the real job and duty data

AddEventHandler('QBCore:Server:OnJobUpdate', function()
	UpdateDoctorCount()
end)

AddEventHandler('QBCore:Server:SetDuty', function()
	UpdateDoctorCount()
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
	local src = Player.PlayerData.source
	UpdateDoctorCount()
	TriggerClientEvent('hospital:client:SetDoctorCount', src, doctorCount)
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
	Player(src).state:set('isKnockedDown', false, true)
	CleanupPlayer(src)
end)

AddEventHandler('playerDropped', function()
	local src = source
	CleanupPlayer(src)
	PlayerInjuries[src] = nil
	PlayerWeaponWounds[src] = nil
	Cooldowns[src] = nil
end)

CreateThread(function()
	while true do
		UpdateDoctorCount()
		Wait(60000)
	end
end)

-- Callbacks

QBCore.Functions.CreateCallback('hospital:GetDoctors', function(_, cb)
	cb(GetDoctorCount())
end)

QBCore.Functions.CreateCallback('hospital:GetPlayerStatus', function(source, cb, playerId)
	playerId = tonumber(playerId)
	local Player = QBCore.Functions.GetPlayer(source)
	local Patient = playerId and QBCore.Functions.GetPlayer(playerId)
	-- Only on duty EMS standing next to the patient can check them
	if not Player or not Patient or not IsOnDutyEMS(Player) or not ArePlayersNear(source, playerId, 10.0) then
		return cb(nil)
	end

	local injuries = {}
	injuries['WEAPONWOUNDS'] = {}
	local playerInjuries = PlayerInjuries[playerId]
	if playerInjuries then
		if playerInjuries.isBleeding > 0 then
			injuries['BLEED'] = playerInjuries.isBleeding
		end
		for part, limb in pairs(playerInjuries.limbs) do
			if limb.isDamaged then
				injuries[part] = limb
			end
		end
	end
	for k, v in pairs(PlayerWeaponWounds[playerId] or {}) do
		injuries['WEAPONWOUNDS'][k] = v
	end
	cb(injuries)
end)

QBCore.Functions.CreateCallback('hospital:GetPlayerBleeding', function(source, cb)
	local src = source
	if PlayerInjuries[src] and PlayerInjuries[src].isBleeding then
		cb(PlayerInjuries[src].isBleeding)
	else
		cb(nil)
	end
end)

-- Removes a healing item before its effect is applied on the client
QBCore.Functions.CreateCallback('hospital:server:ConsumeItem', function(source, cb, itemName)
	if not ConsumableItems[itemName] or not QBCore.Functions.GetPlayer(source) then
		return cb(false)
	end
	cb(exports['qb-inventory']:RemoveItem(source, itemName, 1, false, 'hospital:server:ConsumeItem') == true)
end)

local function GetAuthorizedVehicles(grade)
	local vehicles = {}
	for availableGrade, list in pairs(Config.AuthorizedVehicles) do
		if grade >= availableGrade then
			for vehicleName in pairs(list) do
				vehicles[vehicleName] = true
			end
		end
	end
	return vehicles
end

QBCore.Functions.CreateCallback('hospital:server:SpawnVehicle', function(source, cb, model, garageIndex, isHelicopter)
	local Player = QBCore.Functions.GetPlayer(source)
	garageIndex = tonumber(garageIndex)
	local coords = garageIndex and Config.Locations[isHelicopter and 'helicopter' or 'vehicle'][garageIndex]
	if not Player or not IsOnDutyEMS(Player) or not coords or not IsNearCoords(source, coords, 10.0) then
		return cb(nil)
	end

	if isHelicopter then
		model = Config.Helicopter
	elseif type(model) ~= 'string' or not GetAuthorizedVehicles(Player.PlayerData.job.grade.level)[model] then
		return cb(nil)
	end

	local veh = QBCore.Functions.SpawnVehicle(source, model, coords, true)
	cb(NetworkGetNetworkIdFromEntity(veh))
end)

-- Commands

local function CanUseEMSCommand(src)
	local Player = QBCore.Functions.GetPlayer(src)
	if not Player or Player.PlayerData.job.name ~= 'ambulance' then
		TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_ems'), 'error')
		return false
	end
	if not Player.PlayerData.job.onduty then
		TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_on_duty'), 'error')
		return false
	end
	return true
end

QBCore.Commands.Add('911e', Lang:t('info.ems_report'), { { name = 'message', help = Lang:t('info.message_sent') } }, false, function(source, args)
	local src = source
	if IsOnCooldown(src, 'call', Config.AlertCooldown) then
		TriggerClientEvent('QBCore:Notify', src, Lang:t('error.alert_cooldown'), 'error')
		return
	end
	local message = args[1] and SanitizeText(table.concat(args, ' ')) or Lang:t('info.civ_call')
	AlertEMS(GetPlayerCoords(src), message)
end)

QBCore.Commands.Add('status', Lang:t('info.check_health'), {}, false, function(source, _)
	if CanUseEMSCommand(source) then
		TriggerClientEvent('hospital:client:CheckStatus', source)
	end
end)

QBCore.Commands.Add('heal', Lang:t('info.heal_player'), {}, false, function(source, _)
	if CanUseEMSCommand(source) then
		TriggerClientEvent('hospital:client:TreatWounds', source)
	end
end)

QBCore.Commands.Add('revivep', Lang:t('info.revive_player'), {}, false, function(source, _)
	if CanUseEMSCommand(source) then
		TriggerClientEvent('hospital:client:RevivePlayer', source)
	end
end)

QBCore.Commands.Add('revive', Lang:t('info.revive_player_a'), { { name = 'id', help = Lang:t('info.player_id') } }, false, function(source, args)
	local src = source
	if args[1] then
		local Player = QBCore.Functions.GetPlayer(tonumber(args[1]))
		if Player then
			TriggerClientEvent('hospital:client:Revive', Player.PlayerData.source)
			ResetNeeds(Player.PlayerData.source)
		else
			TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_online'), 'error')
		end
	else
		TriggerClientEvent('hospital:client:Revive', src)
		ResetNeeds(src)
	end
end, 'admin')

QBCore.Commands.Add('setpain', Lang:t('info.pain_level'), { { name = 'id', help = Lang:t('info.player_id') } }, false, function(source, args)
	local src = source
	if args[1] then
		local Player = QBCore.Functions.GetPlayer(tonumber(args[1]))
		if Player then
			TriggerClientEvent('hospital:client:SetPain', Player.PlayerData.source)
		else
			TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_online'), 'error')
		end
	else
		TriggerClientEvent('hospital:client:SetPain', src)
	end
end, 'admin')

QBCore.Commands.Add('kill', Lang:t('info.kill'), { { name = 'id', help = Lang:t('info.player_id') } }, false, function(source, args)
	local src = source
	if args[1] then
		local Player = QBCore.Functions.GetPlayer(tonumber(args[1]))
		if Player then
			TriggerClientEvent('hospital:client:KillPlayer', Player.PlayerData.source)
		else
			TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_online'), 'error')
		end
	else
		TriggerClientEvent('hospital:client:KillPlayer', src)
	end
end, 'admin')

QBCore.Commands.Add('aheal', Lang:t('info.heal_player_a'), { { name = 'id', help = Lang:t('info.player_id') } }, false, function(source, args)
	local src = source
	if args[1] then
		local Player = QBCore.Functions.GetPlayer(tonumber(args[1]))
		if Player then
			TriggerClientEvent('hospital:client:adminHeal', Player.PlayerData.source)
			ResetNeeds(Player.PlayerData.source)
		else
			TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_online'), 'error')
		end
	else
		TriggerClientEvent('hospital:client:adminHeal', src)
		ResetNeeds(src)
	end
end, 'admin')

-- Items

QBCore.Functions.CreateUseableItem('ifaks', function(source, item)
	local Player = QBCore.Functions.GetPlayer(source)
	if Player and Player.Functions.GetItemByName(item.name) ~= nil then
		TriggerClientEvent('hospital:client:UseIfaks', source)
	end
end)

QBCore.Functions.CreateUseableItem('bandage', function(source, item)
	local Player = QBCore.Functions.GetPlayer(source)
	if Player and Player.Functions.GetItemByName(item.name) ~= nil then
		TriggerClientEvent('hospital:client:UseBandage', source)
	end
end)

QBCore.Functions.CreateUseableItem('painkillers', function(source, item)
	local Player = QBCore.Functions.GetPlayer(source)
	if Player and Player.Functions.GetItemByName(item.name) ~= nil then
		TriggerClientEvent('hospital:client:UsePainkillers', source)
	end
end)

QBCore.Functions.CreateUseableItem('firstaid', function(source, item)
	local Player = QBCore.Functions.GetPlayer(source)
	if Player and Player.Functions.GetItemByName(item.name) ~= nil then
		TriggerClientEvent('hospital:client:UseFirstAid', source)
	end
end)

exports('GetDoctorCount', function() return GetDoctorCount() end)
