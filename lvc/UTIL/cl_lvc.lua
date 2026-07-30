--[[
---------------------------------------------------
LUXART VEHICLE CONTROL V3 (FOR FIVEM)
---------------------------------------------------
Coded by Lt.Caine
ELS Clicks by Faction
Additional Modification by TrevorBarns
---------------------------------------------------
FILE: cl_lvc.lua
PURPOSE: Core Functionality and User Input
---------------------------------------------------
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
---------------------------------------------------
]]

--GLOBAL VARIABLES used in cl_ragemenu, UTILs, and plug-ins.
--	GENERAL VARIABLES
key_lock = false
playerped = nil
last_veh = nil
veh = nil
trailer = nil
player_is_emerg_driver = false
debug_mode = false

--	MAIN SIREN SETTINGS
tone_main_reset_standby 	= reset_to_standby_default
tone_airhorn_intrp 			= airhorn_interrupt_default
park_kill 					= park_kill_default

--LOCAL VARIABLES
local radio_wheel_active = false

local count_bcast_timer = 0
local delay_bcast_timer = 300

local count_sndclean_timer = 0
local delay_sndclean_timer = 400

local actv_ind_timer = false
local count_ind_timer = 0
local delay_ind_timer = 180

actv_lxsrnmute_temp = false
local srntone_temp = 0
local dsrn_mute = true
local lights_on = false
local new_tone = nil
local tone_mem_id = nil
local tone_mem_option = nil
local default_tone = nil
local default_tone_option = nil

state_indic = {}
state_lxsiren = {}
state_pwrcall = {}
state_airmanu = {}

--	Vehicles currently in the 200ms siren-cancel flourish. While set, the auto-broadcast
--	reports the siren as OFF so remote clients cancel immediately (and never pick up the
--	transient tone the local driver briefly hears).
local srn_cancelling = {}

actv_manu = nil
actv_horn = nil

local update_data = {}

local ind_state_o = 0
local ind_state_l = 1
local ind_state_r = 2
local ind_state_h = 3

local snd_lxsiren = {}
local snd_pwrcall = {}
local snd_airmanu = {}

--	Local fn forward declaration
local RegisterKeyMaps, MakeOrdinal, GetHornSoundForVeh

----------------THREADED FUNCTIONS----------------
-- Set check variable `player_is_emerg_driver` if player is driver of emergency vehicle.
-- Disables controls faster than previous thread.
CreateThread(function()
	if GetResourceState('lux_vehcontrol') ~= 'started' and GetResourceState('lux_vehcontrol') ~= 'starting' then
		if GetCurrentResourceName() == 'lvc' then
			if community_id ~= nil and community_id ~= '' then
				while true do
					playerped = GetPlayerPed(-1)
					--IS IN VEHICLE
					player_is_emerg_driver = false
					if IsPedInAnyVehicle(playerped, false) then
						veh = GetVehiclePedIsUsing(playerped)
						_, trailer = GetVehicleTrailerVehicle(veh)
						--IS DRIVER
						if GetPedInVehicleSeat(veh, -1) == playerped then
							--IS EMERGENCY VEHICLE
							if GetVehicleClass(veh) == 18 then
								player_is_emerg_driver = true
								DisableControlAction(0, 80, true) -- INPUT_VEH_CIN_CAM
								DisableControlAction(0, 86, true) -- INPUT_VEH_HORN
								DisableControlAction(0, 172, true) -- INPUT_CELLPHONE_UP
							end
						end
					end
					Wait(1)
				end
			else
				Wait(1000)
				HUD:ShowNotification(Lang:t('error.missing_community_id_frontend'), true)
				UTIL:Print(Lang:t('error.missing_community_id_console'), true)
			end
		else
			Wait(1000)
			HUD:ShowNotification(Lang:t('error.invalid_resource_name_frontend'), true)
			UTIL:Print(Lang:t('error.invalid_resource_name_console'), true)
		end
	else
		Wait(1000)
		HUD:ShowNotification(Lang:t('error.resource_conflict_frontend'), true)
		UTIL:Print(Lang:t('error.resource_conflict_console'), true)
	end
end)

--On resource start/restart
CreateThread(function()
	debug_mode = GetResourceMetadata(GetCurrentResourceName(), 'debug_mode', 0) == 'true'
	TriggerEvent('chat:addSuggestion', Lang:t('command.lock_command'), Lang:t('command.lock_desc'))
	SetNuiFocus( false )
	
	UTIL:FixOversizeKeys(SIREN_ASSIGNMENTS)
	RegisterKeyMaps()
	STORAGE:SetBackupTable()
end)

-- Auxiliary Control Handling
--	Handles radio wheel controls and default horn on siren change playback. 
CreateThread(function()
	while true do
		if player_is_emerg_driver then
			-- RADIO WHEEL
			if IsControlPressed(0, 243) and AUDIO.radio_masterswitch then
				while IsControlPressed(0, 243) do
					radio_wheel_active = true
					SetControlNormal(0, 85, 1.0)
					Wait(0)
				end
				Wait(100)
				radio_wheel_active = false
			else
				DisableControlAction(0, 85, true) -- INPUT_VEH_RADIO_WHEEL
				SetVehicleRadioEnabled(veh, false)
			end
		end
		Wait(0)
	end
end)

------ON VEHICLE EXIT EVENT TRIGGER------
CreateThread(function()
	while true do
		if player_is_emerg_driver then
			while playerped ~= nil and veh ~= nil do
				if GetIsTaskActive(playerped, 2) and GetVehiclePedIsIn(ped, true) then
					TriggerEvent('lvc:onVehicleExit')
					Wait(1000)
				end
				Wait(0)
			end
		end
		Wait(1000)
	end
end)

------VEHICLE CHANGE DETECTION AND TRIGGER------
CreateThread(function()
	while true do
		if player_is_emerg_driver and veh ~= nil then
			if last_veh == nil then
				TriggerEvent('lvc:onVehicleChange')
			else
				if last_veh ~= veh then
					TriggerEvent('lvc:onVehicleChange')
				end
			end
		end
		Wait(1000)
	end
end)

------------REGISTERED VEHICLE EVENTS------------
--Kill siren on Exit
RegisterNetEvent('lvc:onVehicleExit')
AddEventHandler('lvc:onVehicleExit', function()
	if park_kill_masterswitch and park_kill then
		local exit_veh = veh
		local old_state = state_lxsiren[exit_veh] or 0
		if not tone_main_reset_standby and old_state ~= 0 then
			UTIL:SetToneByID('MAIN_MEM', old_state)
		end
		if old_state ~= 0 then
			-- Play the same stop flourish as manual siren cancel.
			PlayHornSound(GetHornSoundForVeh(exit_veh, 'stop', siren_horn_stop_sound))
			local next_tone = UTIL:GetNextSirenTone(old_state, exit_veh, true)
			if next_tone ~= nil and next_tone ~= old_state then
				SetLxSirenStateForVeh(exit_veh, next_tone)
				TriggerServerEvent('lvc:SetLxSirenState_s', next_tone)
				CreateThread(function()
					Wait(200)
					SetLxSirenStateForVeh(exit_veh, 0)
					TriggerServerEvent('lvc:SetLxSirenState_s', 0)
				end)
			else
				SetLxSirenStateForVeh(exit_veh, 0)
				TriggerServerEvent('lvc:SetLxSirenState_s', 0)
			end
		else
			SetLxSirenStateForVeh(exit_veh, 0)
		end
		SetPowercallStateForVeh(exit_veh, 0)
		SetAirManuStateForVeh(exit_veh, 0)
		HUD:SetItemState('siren', false)
		HUD:SetItemState('horn', false)
		count_bcast_timer = delay_bcast_timer
	end
end)

RegisterNetEvent('lvc:onVehicleChange')
AddEventHandler('lvc:onVehicleChange', function()
	last_veh = veh
	UTIL:UpdateApprovedTones(veh)
	Wait(100)	--waiting for JS event handler
	STORAGE:ResetSettings()
	UTIL:BuildToneOptions()
	STORAGE:LoadSettings()
	HUD:RefreshHudItemStates()
	SetVehRadioStation(veh, 'OFF')
	Wait(500)
	SetVehRadioStation(veh, 'OFF')
end)

--------------REGISTERED COMMANDS---------------
--Toggle Debug Mode
RegisterCommand(Lang:t('command.debug_command'), function(source, args)
	debug_mode = not debug_mode
	HUD:ShowNotification(Lang:t('info.debug_mode_frontend', {state = debug_mode}), true)
	UTIL:Print(Lang:t('info.debug_mode_console', {state = debug_mode}), true)
	if debug_mode then
		TriggerEvent('lvc:onVehicleChange')
	end
end)

--[[Temp diagnostic: /lvcextra <id> <1|0>  — directly toggle an extra on your current vehicle.
	Use this to find the correct extra IDs for a vehicle model.
	e.g. /lvcextra 4 1  (enable extra 4)    /lvcextra 4 0  (disable extra 4)]]
RegisterCommand('lvcextra', function(source, args)
	local id    = tonumber(args[1])
	local state = args[2] == '1'
	if id ~= nil and veh ~= nil and DoesEntityExist(veh) then
		SetVehicleExtra(veh, id, not state)
		print('[LVC] lvcextra: extra ' .. id .. ' set to ' .. (state and 'ON' or 'OFF'))
	else
		print('[LVC] lvcextra: usage /lvcextra <extraId> <1|0>')
	end
end, false)

--Toggle LUX lock command
RegisterCommand(Lang:t('command.lock_command'), function(source, args)
	if player_is_emerg_driver then
		key_lock = not key_lock
		AUDIO:Play('Key_Lock', AUDIO.lock_volume, true)
		HUD:SetItemState('lock', key_lock)
		--if HUD is visible do not show notification
		if not HUD:GetHudState() then
			if key_lock then
				HUD:ShowNotification(Lang:t('info.locked'), true)
			else
				HUD:ShowNotification(Lang:t('info.unlocked'), true)
			end
		end
	end
end)

RegisterKeyMapping(Lang:t('command.lock_command'), Lang:t('control.lock_desc'), 'keyboard', lockout_default_hotkey)

------------------------------------------------
-------------------FUNCTIONS--------------------
------------------------------------------------
------------------------------------------------
--Dynamically Run RegisterCommand and KeyMapping functions for all 14 possible sirens
--Then at runtime 'slide' all sirens down removing any restricted sirens.
RegisterKeyMaps = function()
	for i, _ in ipairs(SIRENS) do
		if i ~= 1 then
			local command = '_lvc_siren_' .. i-1
			local description = Lang:t('control.siren_control_desc', {ord_num = MakeOrdinal(i-1)})

			RegisterCommand(command, function(source, args)
				if veh ~= nil and player_is_emerg_driver ~= nil then
					if IsVehicleSirenOn(veh) and player_is_emerg_driver and not key_lock then
						local proposed_tone = UTIL:GetToneAtPos(i)
						local tone_option = UTIL:GetToneOption(proposed_tone)
						if i-1 < #UTIL:GetApprovedTonesTable() then
							if tone_option ~= nil then
								if tone_option == 1 or tone_option == 3 then
									if ( state_lxsiren[veh] ~= proposed_tone or state_lxsiren[veh] == 0 ) then
										HUD:SetItemState('siren', true)
										ChangeMainSirenStage(veh, proposed_tone)
										count_bcast_timer = delay_bcast_timer
									else
										if state_pwrcall[veh] == 0 then
											HUD:SetItemState('siren', false)
										end
										ChangeMainSirenStage(veh, 0)
										count_bcast_timer = delay_bcast_timer
									end
								end
							else
								HUD:ShowNotification(Lang:t('error.reg_keymap_nil_1', {i = i, proposed_tone = proposed_tone, profile_name = UTIL:GetVehicleProfileName()}), true)
								HUD:ShowNotification(Lang:t('error.reg_keymap_nil_2'), true)
							end
						end
					end
				end
			end)

			--	Per-tone number keybinds removed. Commands remain registered so they can
			--	optionally be bound in the FiveM keybind settings, but no default key is set.
			RegisterKeyMapping(command, description, 'keyboard', '')
		end
	end
end

--Make number into ordinal number, used for FiveM RegisterKeys
MakeOrdinal = function(number)
	local sufixes = { 'th', 'st', 'nd', 'rd', 'th', 'th', 'th', 'th', 'th', 'th' }
	local mod = (number % 100)
	if mod == 11 or mod == 12 or mod == 13 then
		return number .. 'th'
	else
		return number..sufixes[(number % 10) + 1]
	end
end

--Broadcast local vehicle state to other resources
BroadcastPlayerVehicleState = function(vehicle)
	if veh == vehicle then
		update_data = {
			['state_lxsiren'] = state_lxsiren[veh],
			['state_indic'] = state_indic[veh],
			['state_pwrcall'] = state_pwrcall[veh],
			['state_airmanu'] = state_airmanu[veh],
			['actv_manu'] = actv_manu,
			['actv_horn'] = actv_horn
		}
		TriggerEvent('lvc:UpdateThirdParty', update_data)
	end
end	

---------------------------------------------------------------------
local function CleanupSounds()
	if count_sndclean_timer > delay_sndclean_timer then
		count_sndclean_timer = 0
		for k, v in pairs(state_lxsiren) do
			if v > 0 then
				if not DoesEntityExist(k) or IsEntityDead(k) then
					if snd_lxsiren[k] ~= nil then
						StopSound(snd_lxsiren[k])
						ReleaseSoundId(snd_lxsiren[k])
						snd_lxsiren[k] = nil
						state_lxsiren[k] = nil
					end
				end
			end
		end
		for k, v in pairs(state_pwrcall) do
			if v > 0 then
				if not DoesEntityExist(k) or IsEntityDead(k) then
					if snd_pwrcall[k] ~= nil then
						StopSound(snd_pwrcall[k])
						ReleaseSoundId(snd_pwrcall[k])
						snd_pwrcall[k] = nil
						state_pwrcall[k] = nil
					end
				end
			end
		end
		for k, v in pairs(state_airmanu) do
			if v == true then
				if not DoesEntityExist(k) or IsEntityDead(k) or IsVehicleSeatFree(k, -1) then
					if snd_airmanu[k] ~= nil then
						StopSound(snd_airmanu[k])
						ReleaseSoundId(snd_airmanu[k])
						snd_airmanu[k] = nil
						state_airmanu[k] = nil
					end
				end
			end
		end
	else
		count_sndclean_timer = count_sndclean_timer + 1
	end
end
---------------------------------------------------------------------
function TogIndicStateForVeh(vehicle, newstate)
	if DoesEntityExist(vehicle) and not IsEntityDead(vehicle) then
		if newstate == ind_state_o then
			SetVehicleIndicatorLights(vehicle, 0, false) -- R
			SetVehicleIndicatorLights(vehicle, 1, false) -- L
		elseif newstate == ind_state_l then
			SetVehicleIndicatorLights(vehicle, 0, false) -- R
			SetVehicleIndicatorLights(vehicle, 1, true) -- L
		elseif newstate == ind_state_r then
			SetVehicleIndicatorLights(vehicle, 0, true) -- R
			SetVehicleIndicatorLights(vehicle, 1, false) -- L
		elseif newstate == ind_state_h then
			SetVehicleIndicatorLights(vehicle, 0, true) -- R
			SetVehicleIndicatorLights(vehicle, 1, true) -- L
		end
		state_indic[vehicle] = newstate
		BroadcastPlayerVehicleState(vehicle)
	end
end

---------------------------------------------------------------------
function TogMuteDfltSrnForVeh(vehicle, toggle)
	if DoesEntityExist(vehicle) and not IsEntityDead(vehicle) then
		DisableVehicleImpactExplosionActivation(vehicle, toggle)
	end
end

---------------------------------------------------------------------
--	Cache of custom siren audio banks that have been requested.
local requested_banks = {}

--[[Ensures the custom audio bank for a tone is loaded before it is played (z_els style).]]
local function EnsureSirenBank(tone_id)
	local siren = SIRENS[tone_id]
	if siren ~= nil and siren.Bank ~= nil and siren.Bank ~= '' and not requested_banks[siren.Bank] then
		if RequestScriptAudioBank(siren.Bank, false) then
			requested_banks[siren.Bank] = true
		end
	end
end

--	Pre-load every configured custom siren bank on start so tones are ready when triggered.
CreateThread(function()
	for _, siren in ipairs(SIRENS) do
		if siren.Bank ~= nil and siren.Bank ~= '' then
			while not RequestScriptAudioBank(siren.Bank, false) do
				Wait(250)
			end
			requested_banks[siren.Bank] = true
		end
	end
end)

---------------------------------------------------------------------
function SetLxSirenStateForVeh(vehicle, newstate)
	if DoesEntityExist(vehicle) and not IsEntityDead(vehicle) then
		if newstate ~= state_lxsiren[vehicle] and newstate ~= nil then
			if snd_lxsiren[vehicle] ~= nil then
				StopSound(snd_lxsiren[vehicle])
				ReleaseSoundId(snd_lxsiren[vehicle])
				snd_lxsiren[vehicle] = nil
			end
			if newstate ~= 0 then
				EnsureSirenBank(newstate)
				snd_lxsiren[vehicle] = GetSoundId()
				PlaySoundFromEntity(snd_lxsiren[vehicle], SIRENS[newstate].String, vehicle, SIRENS[newstate].SoundSet or SIRENS[newstate].Ref, 0, 0)
				TogMuteDfltSrnForVeh(vehicle, true)
			end
			state_lxsiren[vehicle] = newstate
			BroadcastPlayerVehicleState(vehicle)
		end
	end
end

---------------------------------------------------------------------
--[[Plays a global horn sound (NUI) used for siren start / change / stop.
	Plays locally for the driver and broadcasts to nearby players so everyone hears it.]]
function PlayHornSound(file)
	if siren_horn_confirm_enabled and file ~= nil and file ~= '' then
		AUDIO:Play(file, siren_horn_volume or 0.7, true)
		TriggerServerEvent('lvc:PlayHorn_s', file)
	end
end

--[[Returns which main-siren stage (1 or 2) a tone id maps to for a vehicle, or nil.
	Position 2 in the approved tones = Stage 1, position 3 = Stage 2.]]
local function GetStageForTone(tone_id)
	local pos = UTIL:IndexOf(UTIL:GetApprovedTonesTable(), tone_id)
	if pos == 2 then
		return 1
	elseif pos == 3 then
		return 2
	end
	return nil
end

--[[Plays the optional per-vehicle NUI confirmation sound for a stage ('Stage1', 'Stage2', 'Off').
	Returns true if a custom sound was configured and played, false otherwise.]]
local function PlayStageSfx(vehicle, stage_key)
	if SIREN_STAGE_SFX == nil then
		return false
	end
	local profile_tbl = UTIL:GetProfileFromTable('STAGE_SFX', SIREN_STAGE_SFX, vehicle, true)
	if profile_tbl ~= nil and profile_tbl[stage_key] ~= nil then
		AUDIO:Play(profile_tbl[stage_key], AUDIO.upgrade_volume, true)
		return true
	end
	return false
end

--[[Resolves the horn start / stop sound for a vehicle, honouring the optional per-vehicle
	overrides in SIREN_HORN_SOUNDS and falling back to the global SETTINGS.lua value.]]
GetHornSoundForVeh = function(vehicle, key, fallback)
	if SIREN_HORN_SOUNDS ~= nil then
		local profile_tbl = UTIL:GetProfileFromTable('HORN_SOUNDS', SIREN_HORN_SOUNDS, vehicle, true)
		if profile_tbl ~= nil and profile_tbl[key] ~= nil and profile_tbl[key] ~= '' then
			return profile_tbl[key]
		end
	end
	return fallback
end

--[[Central handler for MAIN siren stage changes for the local vehicle.
	Fires the real vehicle horn (start / change once, stop twice) and plays the optional
	per-vehicle stage confirmation sound, falling back to the default upgrade / downgrade blip.
	Pass silent = true to change the stage without any horn or sound (e.g. park-kill on exit).]]
function ChangeMainSirenStage(vehicle, newstate, silent)
	local oldstate = state_lxsiren[vehicle] or 0
	if newstate == oldstate then
		return
	end

	if not silent and vehicle == veh and player_is_emerg_driver then
		if newstate == 0 then
			-- SIREN STOP
			if not PlayStageSfx(vehicle, 'Off') then
				PlayHornSound(GetHornSoundForVeh(vehicle, 'stop', siren_horn_stop_sound))
			end
			local next_tone = UTIL:GetNextSirenTone(oldstate, vehicle, true)
			if next_tone ~= nil and next_tone ~= oldstate then
				-- SIREN BLIP
				SetLxSirenStateForVeh(vehicle, next_tone)
				TriggerServerEvent('lvc:SetLxSirenState_s', next_tone)
				CreateThread(function()
					Wait(250)
					SetLxSirenStateForVeh(vehicle, 0)
					TriggerServerEvent('lvc:SetLxSirenState_s', 0)
				end)
			else
				-- No tone change available; cancel immediately.
				SetLxSirenStateForVeh(vehicle, 0)
				TriggerServerEvent('lvc:SetLxSirenState_s', 0)
			end
			return
		else
			-- SIREN START or STAGE CHANGE
			local stage = GetStageForTone(newstate)
			local played = false
			if stage == 1 then
				played = PlayStageSfx(vehicle, 'Stage1')
			elseif stage == 2 then
				played = PlayStageSfx(vehicle, 'Stage2')
			end
			if not played then
				PlayHornSound(GetHornSoundForVeh(vehicle, 'start', siren_horn_start_sound))
			end
			-- Immediately broadcast siren start to all clients (mirrors the explicit stop broadcast).
			TriggerServerEvent('lvc:SetLxSirenState_s', newstate)
		end
	end

	SetLxSirenStateForVeh(vehicle, newstate)
end

---------------------------------------------------------------------
function SetPowercallStateForVeh(vehicle, newstate)
	if DoesEntityExist(vehicle) and not IsEntityDead(vehicle) then
		if newstate ~= state_pwrcall[vehicle] and newstate ~= nil then
			if snd_pwrcall[vehicle] ~= nil then
				StopSound(snd_pwrcall[vehicle])
				ReleaseSoundId(snd_pwrcall[vehicle])
				snd_pwrcall[vehicle] = nil
			end
			if newstate ~= 0 then
				EnsureSirenBank(newstate)
				snd_pwrcall[vehicle] = GetSoundId()
				PlaySoundFromEntity(snd_pwrcall[vehicle], SIRENS[newstate].String, vehicle, SIRENS[newstate].SoundSet or SIRENS[newstate].Ref, 0, 0)
			end
			state_pwrcall[vehicle] = newstate
			BroadcastPlayerVehicleState(vehicle)
		end
	end
end

---------------------------------------------------------------------
function SetAirManuStateForVeh(vehicle, newstate)
	if DoesEntityExist(vehicle) and not IsEntityDead(vehicle) then
		if newstate ~= state_airmanu[vehicle] and newstate ~= nil then
			if snd_airmanu[vehicle] ~= nil then
				StopSound(snd_airmanu[vehicle])
				ReleaseSoundId(snd_airmanu[vehicle])
				snd_airmanu[vehicle] = nil
			end
			if newstate ~= 0 then
				EnsureSirenBank(newstate)
				snd_airmanu[vehicle] = GetSoundId()
				PlaySoundFromEntity(snd_airmanu[vehicle], SIRENS[newstate].String, vehicle, SIRENS[newstate].SoundSet or SIRENS[newstate].Ref, 0, 0)
			end
			state_airmanu[vehicle] = newstate
			BroadcastPlayerVehicleState(vehicle)
		end
	end
end

------------------------------------------------
----------------EVENT HANDLERS------------------
------------------------------------------------
RegisterNetEvent('lvc:TogIndicState_c')
AddEventHandler('lvc:TogIndicState_c', function(sender, newstate)
	local player_s = GetPlayerFromServerId(sender)
	local ped_s = GetPlayerPed(player_s)
	if DoesEntityExist(ped_s) and not IsEntityDead(ped_s) then
		if ped_s ~= GetPlayerPed(-1) then
			if IsPedInAnyVehicle(ped_s, false) then
				local vehicle = GetVehiclePedIsUsing(ped_s)
				TogIndicStateForVeh(vehicle, newstate)
			end
		end
	end
end)

---------------------------------------------------------------------
RegisterNetEvent('lvc:TogDfltSrnMuted_c')
AddEventHandler('lvc:TogDfltSrnMuted_c', function(sender)
	local player_s = GetPlayerFromServerId(sender)
	local ped_s = GetPlayerPed(player_s)
	if DoesEntityExist(ped_s) and not IsEntityDead(ped_s) then
		if ped_s ~= GetPlayerPed(-1) then
			if IsPedInAnyVehicle(ped_s, false) then
				local vehicle = GetVehiclePedIsUsing(ped_s)
				TogMuteDfltSrnForVeh(vehicle, true)
			end
		end
	end
end)

---------------------------------------------------------------------
RegisterNetEvent('lvc:SetLxSirenState_c')
AddEventHandler('lvc:SetLxSirenState_c', function(sender, newstate)
	local player_s = GetPlayerFromServerId(sender)
	local ped_s = GetPlayerPed(player_s)
	if DoesEntityExist(ped_s) and not IsEntityDead(ped_s) then
		if ped_s ~= GetPlayerPed(-1) then
			if IsPedInAnyVehicle(ped_s, false) then
				local vehicle = GetVehiclePedIsUsing(ped_s)
				SetLxSirenStateForVeh(vehicle, newstate)
			end
		end
	end
end)

---------------------------------------------------------------------
RegisterNetEvent('lvc:SetPwrcallState_c')
AddEventHandler('lvc:SetPwrcallState_c', function(sender, newstate)
	local player_s = GetPlayerFromServerId(sender)
	local ped_s = GetPlayerPed(player_s)
	if DoesEntityExist(ped_s) and not IsEntityDead(ped_s) then
		if ped_s ~= GetPlayerPed(-1) then
			if IsPedInAnyVehicle(ped_s, false) then
				local vehicle = GetVehiclePedIsUsing(ped_s)
				SetPowercallStateForVeh(vehicle, newstate)
			end
		end
	end
end)

---------------------------------------------------------------------
RegisterNetEvent('lvc:SetAirManuState_c')
AddEventHandler('lvc:SetAirManuState_c', function(sender, newstate)
	local player_s = GetPlayerFromServerId(sender)
	local ped_s = GetPlayerPed(player_s)
	if DoesEntityExist(ped_s) and not IsEntityDead(ped_s) then
		if ped_s ~= GetPlayerPed(-1) then
			if IsPedInAnyVehicle(ped_s, false) then
				local vehicle = GetVehiclePedIsUsing(ped_s)
				SetAirManuStateForVeh(vehicle, newstate)
			end
		end
	end
end)


---------------------------------------------------------------------
--[[Plays another player's horn wav locally, with volume scaled by distance.]]
RegisterNetEvent('lvc:PlayHorn_c')
AddEventHandler('lvc:PlayHorn_c', function(sender, file)
	if not siren_horn_confirm_enabled or file == nil or file == '' then
		return
	end
	local player_s = GetPlayerFromServerId(sender)
	local ped_s = GetPlayerPed(player_s)
	if DoesEntityExist(ped_s) and not IsEntityDead(ped_s) and ped_s ~= GetPlayerPed(-1) then
		local max_dist = siren_horn_hear_distance or 80.0
		local dist = #(GetEntityCoords(ped_s) - GetEntityCoords(GetPlayerPed(-1)))
		if dist <= max_dist then
			local vol = (siren_horn_volume or 0.7) * (1.0 - (dist / max_dist))
			if vol > 0.0 then
				AUDIO:Play(file, vol, true)
			end
		end
	end
end)


---------------------------------------------------------------------
CreateThread(function()
	while true do
		CleanupSounds()
		DistantCopCarSirens(false)
		----- IS IN VEHICLE -----
		if GetPedInVehicleSeat(veh, -1) == playerped then
			if state_indic[veh] == nil then
				state_indic[veh] = ind_state_o
			end

			-- INDIC AUTO CONTROL
			if actv_ind_timer == true then
				if state_indic[veh] == ind_state_l or state_indic[veh] == ind_state_r then
					if GetEntitySpeed(veh) < 6 then
						count_ind_timer = 0
					else
						if count_ind_timer > delay_ind_timer then
							count_ind_timer = 0
							actv_ind_timer = false
							state_indic[veh] = ind_state_o
							TogIndicStateForVeh(veh, state_indic[veh])
							count_bcast_timer = delay_bcast_timer
						else
							count_ind_timer = count_ind_timer + 1
						end
					end
				end
			end

			--- IS EMERG VEHICLE ---
			if GetVehicleClass(veh) == 18 then
				lights_on = IsVehicleSirenOn(veh)
				--  FORCE RADIO ENABLED PER FRAME
				if radio_masterswitch then
					SetVehicleRadioEnabled(veh, true)
				end

				if not IsEntityDead(veh) then
					TogMuteDfltSrnForVeh(veh, true)
					--- SET INIT TABLE VALUES ---
					if state_lxsiren[veh] == nil then
						state_lxsiren[veh] = 0
					end
					if state_pwrcall[veh] == nil then
						state_pwrcall[veh] = 0
					end
					if state_airmanu[veh] == nil then
							state_airmanu[veh] = 0
					end

					--- IF LIGHTS ARE OFF TURN OFF SIREN ---
					if not lights_on and state_lxsiren[veh] > 0 then
						--	SAVE TONE BEFORE TURNING OFF
						if not tone_main_reset_standby then
							UTIL:SetToneByID('MAIN_MEM', state_lxsiren[veh])
						end
						SetLxSirenStateForVeh(veh, 0)
						count_bcast_timer = delay_bcast_timer
					end
					if not lights_on and state_pwrcall[veh] > 0 then
						SetPowercallStateForVeh(veh, 0)
						count_bcast_timer = delay_bcast_timer
					end

					----- CONTROLS -----
					if not IsPauseMenuActive() and UpdateOnscreenKeyboard() ~= 0 and not radio_wheel_active then
						if not key_lock then
							-- POWERCALL
							if IsDisabledControlJustReleased(0, 172) and not IsMenuOpen() then
								if state_pwrcall[veh] == 0 then
									if lights_on then
										AUDIO:Play('Upgrade', AUDIO.upgrade_volume)
										HUD:SetItemState('siren', true)
										SetPowercallStateForVeh(veh, UTIL:GetToneID('AUX'))
										count_bcast_timer = delay_bcast_timer
									end
								else
									AUDIO:Play('Downgrade', AUDIO.downgrade_volume)
									if state_lxsiren[veh] == 0 then
										HUD:SetItemState('siren', false)
									end
									SetPowercallStateForVeh(veh, 0)
								end
								AUDIO:ResetActivityTimer()
								count_bcast_timer = delay_bcast_timer
							end
							-- CYCLE LX SRN TONES
							if state_lxsiren[veh] > 0 then
								if IsDisabledControlJustReleased(0, 80) then
									HUD:SetItemState('horn', false)
									ChangeMainSirenStage(veh, UTIL:GetNextSirenTone(state_lxsiren[veh], veh, true))
									count_bcast_timer = delay_bcast_timer
								elseif IsDisabledControlPressed(0, 80) then
									HUD:SetItemState('horn', true)
								end
							end

							-- MANU
							if state_lxsiren[veh] < 1 then
								if IsDisabledControlPressed(0, 80) then
									AUDIO:ResetActivityTimer()
									actv_manu = true
									HUD:SetItemState('siren', true)
								else
									if actv_manu then
										HUD:SetItemState('siren', false)
									end
									actv_manu = false
								end
							else
								if actv_manu then
									HUD:SetItemState('siren', false)
								end
								actv_manu = false
							end

							-- HORN
							if IsDisabledControlPressed(0, 86) then
								actv_horn = true
								AUDIO:ResetActivityTimer()
								HUD:SetItemState('horn', true)
							else
								if actv_horn or actv_manu then
									HUD:SetItemState('horn', false)
								end
								actv_horn = false
							end


							--AIRHORN AND MANU BUTTON SFX
							if AUDIO.airhorn_button_SFX then
								if IsDisabledControlJustPressed(0, 86) then
									AUDIO:Play('Press', AUDIO.upgrade_volume)
								end
								if IsDisabledControlJustReleased(0, 86) then
									AUDIO:Play('Release', AUDIO.upgrade_volume)
								end
							end
							if AUDIO.manu_button_SFX and state_lxsiren[veh] == 0 then
								if IsDisabledControlJustPressed(0, 80) then
									AUDIO:Play('Press', AUDIO.upgrade_volume)
								end
								if IsDisabledControlJustReleased(0, 80) then
									AUDIO:Play('Release', AUDIO.upgrade_volume)
								end
							end
						else
							if (IsDisabledControlJustReleased(0, 86) or
								IsDisabledControlJustReleased(0, 172) or
								IsDisabledControlJustReleased(0, 85)) then
									if locked_press_count % reminder_rate == 0 then
										AUDIO:Play('Locked_Press', AUDIO.lock_reminder_volume, true) -- lock reminder
										HUD:ShowNotification('~y~~h~Reminder:~h~ ~s~Your siren control box is ~r~locked~s~.', true)
									end
									locked_press_count = locked_press_count + 1
							end
						end
					end

					---- ADJUST HORN / MANU STATE ----
					local hmanu_state_new = 0
					if actv_horn == true and actv_manu == false then
						hmanu_state_new = UTIL:GetToneID('ARHRN')
					elseif actv_horn == false and actv_manu == true then
						hmanu_state_new = UTIL:GetToneID('PMANU')
					elseif actv_horn == true and actv_manu == true then
						hmanu_state_new = UTIL:GetToneID('SMANU')
					end
					if tone_airhorn_intrp then
						if hmanu_state_new == UTIL:GetToneID('ARHRN') then
							if state_lxsiren[veh] > 0 and actv_lxsrnmute_temp == false then
								srntone_temp = state_lxsiren[veh]
								SetLxSirenStateForVeh(veh, 0)
								actv_lxsrnmute_temp = true
							end
						else
							if actv_lxsrnmute_temp == true then
								SetLxSirenStateForVeh(veh, srntone_temp)
								actv_lxsrnmute_temp = false
							end
						end
					end

					if state_airmanu[veh] ~= hmanu_state_new then
						SetAirManuStateForVeh(veh, hmanu_state_new)
						count_bcast_timer = delay_bcast_timer
					end
				end
			else
				-- DISABLE SIREN AUDIO FOR ALL VEHICLES NOT VC_EMERGENCY (VEHICLES.META)
				TogMuteDfltSrnForVeh(veh, true)
			end

			--- IS ANY LAND VEHICLE ---
			if GetVehicleClass(veh) ~= 14 and GetVehicleClass(veh) ~= 15 and GetVehicleClass(veh) ~= 16 and GetVehicleClass(veh) ~= 21 then
				----- CONTROLS -----
				if not IsPauseMenuActive() then
					-- IND L
					if IsDisabledControlJustReleased(0, left_signal_key) then -- INPUT_VEH_PREV_RADIO_TRACK
						local cstate = state_indic[veh]
						if cstate == ind_state_l then
							state_indic[veh] = ind_state_o
							actv_ind_timer = false
						else
							state_indic[veh] = ind_state_l
							actv_ind_timer = true
						end
						TogIndicStateForVeh(veh, state_indic[veh])
						count_ind_timer = 0
						count_bcast_timer = delay_bcast_timer
					-- IND R
					elseif IsDisabledControlJustReleased(0, right_signal_key) then -- INPUT_VEH_NEXT_RADIO_TRACK
						local cstate = state_indic[veh]
						if cstate == ind_state_r then
							state_indic[veh] = ind_state_o
							actv_ind_timer = false
						else
							state_indic[veh] = ind_state_r
							actv_ind_timer = true
						end
						TogIndicStateForVeh(veh, state_indic[veh])
						count_ind_timer = 0
						count_bcast_timer = delay_bcast_timer
					-- IND H
					elseif IsControlPressed(0, hazard_key) then -- INPUT_FRONTEND_CANCEL / Backspace
						if GetLastInputMethod(0) then -- last input was with kb
							Wait(hazard_hold_duration)
							if IsControlPressed(0, hazard_key) then -- INPUT_FRONTEND_CANCEL / Backspace
								local cstate = state_indic[veh]
								if cstate == ind_state_h then
									state_indic[veh] = ind_state_o
									AUDIO:Play('Hazards_Off', AUDIO.hazards_volume, true) -- Hazards Off
								else
									state_indic[veh] = ind_state_h
									AUDIO:Play('Hazards_On', AUDIO.hazards_volume, true) -- Hazards On
								end
								TogIndicStateForVeh(veh, state_indic[veh])
								actv_ind_timer = false
								count_ind_timer = 0
								count_bcast_timer = delay_bcast_timer
								Wait(300)
							end
						end
					end
				end

				----- AUTO BROADCAST VEH STATES -----
				if count_bcast_timer > delay_bcast_timer then
					count_bcast_timer = 0
					--- IS EMERG VEHICLE ---
					if GetVehicleClass(veh) == 18 then
						TriggerServerEvent('lvc:TogDfltSrnMuted_s')
						TriggerServerEvent('lvc:SetLxSirenState_s', state_lxsiren[veh])
						TriggerServerEvent('lvc:SetPwrcallState_s', state_pwrcall[veh])
						TriggerServerEvent('lvc:SetAirManuState_s', state_airmanu[veh])
					end
					--- IS ANY OTHER VEHICLE ---
					TriggerServerEvent('lvc:TogIndicState_s', state_indic[veh])
				else
					count_bcast_timer = count_bcast_timer + 1
				end
			end
		end
		Wait(0)
	end
end)