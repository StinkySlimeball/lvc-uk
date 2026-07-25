--[[
---------------------------------------------------
LUXART VEHICLE CONTROL V3 (FOR FIVEM) - UK EDITION
---------------------------------------------------
FILE: cl_cvs.lua
PURPOSE: "CVS" lighting controller panel. Toggles per-vehicle
		 lighting extras, arms the siren, and provides scene /
		 all-on macros. Operable by mouse click or keybind.
---------------------------------------------------
]]
CVS = { }

--	Independent lighting buttons (map to vehicle extras in CVS_EXTRAS).
local LIGHT_BUTTONS = { 'front_blues', 'rear_reds', 'front_whites', 'rear_blues' }

--	Per-vehicle button states, keyed by vehicle entity.
local cvs_state = { }
local cvs_extra_state = {}
local cvs_focus = false

---------------------------------------------------------------------
--[[Ensure a state table exists for the given vehicle.]]
local function EnsureState(vehicle)
	if cvs_state[vehicle] == nil then
		cvs_state[vehicle] = {
			front_blues  = false,
			rear_reds    = false,
			front_whites = false,
			rear_blues   = false,
			at_scene     = false,
			all_on       = false,
		}
	end
	return cvs_state[vehicle]
end

--[[Resolve the CVS extras profile for a vehicle (falls back to DEFAULT).]]
local function GetProfile(vehicle)
	if CVS_EXTRAS == nil then
		return { }
	end
	return UTIL:GetProfileFromTable('CVS', CVS_EXTRAS, vehicle, true) or { }
end

---------------------------------------------------------------------
--[[Push a single button's active state to the NUI panel.]]
function CVS:UpdateButtonUI(button, state)
	SendNUIMessage({
		_type  = 'cvs:setButtonState',
		button = button,
		state  = (type(state) == 'string') and state or (state and true or false),
	})
end

--[[Re-send every button state for a vehicle (e.g. after a vehicle change).]]
function CVS:RefreshUI(vehicle)
	local st = EnsureState(vehicle)
	for _, button in ipairs(LIGHT_BUTTONS) do
		CVS:UpdateButtonUI(button, st[button])
	end
	CVS:UpdateButtonUI('at_scene', st.at_scene)
	CVS:UpdateButtonUI('all_on', st.all_on)
	CVS:UpdateButtonUI('siren_arm', IsVehicleSirenOn(vehicle))
end

--	Whether the CVS panel is currently shown on this client's screen.
local cvs_panel_visible = true

--[[Show or hide the CVS controller panel on this client's screen.]]
function CVS:SetPanelVisible(visible)
	cvs_panel_visible = visible and true or false
	SendNUIMessage({ _type = 'cvs:setPanel', visible = cvs_panel_visible })
	return cvs_panel_visible
end

--	Exports so other resources can control the panel on the local client.
--		exports.lvc:ToggleCvsPanel()          -> toggles and returns the new visibility (boolean)
--		exports.lvc:SetCvsPanel(true / false) -> sets and returns the new visibility (boolean)
--		exports.lvc:IsCvsPanelVisible()       -> returns the current visibility (boolean)
exports('ToggleCvsPanel', function()
	return CVS:SetPanelVisible(not cvs_panel_visible)
end)

exports('SetCvsPanel', function(visible)
	return CVS:SetPanelVisible(visible)
end)

exports('IsCvsPanelVisible', function()
	return cvs_panel_visible
end)

--[[Play a CVS controller sound file (path relative to lvc/UI/sounds/, with extension).]]
function CVS:PlaySound(file)
	if file ~= nil and file ~= '' then
		AUDIO:Play(file, cvs_sound_volume or 0.7, true)
	end
end

--[[Resolves a CVS sound for a vehicle, honouring the optional per-vehicle overrides in
	CVS_SOUNDS and falling back to the matching global SETTINGS.lua value.]]
local CVS_SOUND_FALLBACKS = {
	all_on = 'cvs_sound_all_on',
	scene  = 'cvs_sound_scene',
	action = 'cvs_sound_action',
	leave  = 'cvs_sound_leave',
}
local function GetCvsSound(vehicle, key)
	if CVS_SOUNDS ~= nil then
		local profile_tbl = UTIL:GetProfileFromTable('CVS_SOUNDS', CVS_SOUNDS, vehicle, true)
		if profile_tbl ~= nil and profile_tbl[key] ~= nil and profile_tbl[key] ~= '' then
			return profile_tbl[key]
		end
	end
	return _G[CVS_SOUND_FALLBACKS[key]]
end

---------------------------------------------------------------------
--[[Set a single lighting button on/off, applying its configured extras.]]
function CVS:SetLight(vehicle, button, state)
	local st = EnsureState(vehicle)
	st[button] = state

	local extra_id = GetProfile(vehicle)[button]
	if extra_id ~= nil then
		UTIL:TogVehicleExtras(vehicle, extra_id, state)
	end

	CVS:UpdateButtonUI(button, state)
end

--[[Collects the desired on/off state of every EXTRA id referenced by a list of buttons,
	deduped into a map (extra_id -> boolean) so each extra is only toggled ONCE for the
	whole group / mode. Supports the plain id, `toggle`, and `add` / `remove` layouts.]]
local function CollectExtraStates(profile, buttons, state)
	local desired = {}
	local function add_cfg(cfg, on)
		if type(cfg) == 'number' then
			desired[cfg] = on
		elseif type(cfg) == 'table' then
			if cfg.toggle == nil and cfg.add == nil and cfg.remove == nil then
				-- Plain array: { 4 } or { 4, 5 }
				for _, id in ipairs(cfg) do desired[id] = on end
			else
				if cfg.toggle ~= nil then
					if type(cfg.toggle) == 'table' then
						for _, id in ipairs(cfg.toggle) do desired[id] = on end
					else
						desired[cfg.toggle] = on
					end
				end
				if cfg.add ~= nil then
					if type(cfg.add) == 'table' then
						for _, id in ipairs(cfg.add) do desired[id] = on end
					else
						desired[cfg.add] = on
					end
				end
				if cfg.remove ~= nil then
					if type(cfg.remove) == 'table' then
						for _, id in ipairs(cfg.remove) do desired[id] = not on end
					else
						desired[cfg.remove] = not on
					end
				end
			end
		end
	end
	for _, button in ipairs(buttons) do
		add_cfg(profile[button], state)
	end
	return desired
end

--[[Apply a GROUP of buttons' EXTRAS at once (used by the at_scene / all_on macros).
	The individual panel buttons are NOT lit/toggled here - only the extras they map to
	are applied, with every unique extra id toggled only ONCE. So two buttons sharing an
	extra (e.g. both set to 4) don't fight each other or flip it twice for the mode.]]
function CVS:SetLightGroup(vehicle, buttons, state)
	local profile = GetProfile(vehicle)
	local desired = CollectExtraStates(profile, buttons, state)
	for extra_id, on in pairs(desired) do
		UTIL:TogVehicleExtras(vehicle, extra_id, on)
	end
end

--[[Apply a COMPLETE lighting state in one pass: the given buttons ON and every other
	light button OFF. Every unique extra id is toggled EXACTLY once (ON wins for ids
	shared by multiple buttons), which avoids the same-frame OFF->ON that GTA ignores
	for extras referenced by more than one button. Also syncs the panel + stored state.]]
function CVS:ApplyLightSet(vehicle, onButtons)
    local profile = GetProfile(vehicle)
    local st = EnsureState(vehicle)

    if cvs_extra_state[vehicle] == nil then
        cvs_extra_state[vehicle] = {}
    end

    local previous = cvs_extra_state[vehicle]

    -- Build a lookup table of the buttons wanted in the new stage.
    local onSet = {}

    for _, button in ipairs(onButtons or {}) do
        onSet[button] = true
    end

    -- Start with every configured lighting extra switched off.
    local desired = CollectExtraStates(
        profile,
        LIGHT_BUTTONS,
        false
    )

    -- Work out the extras required by the new stage.
    local onMap = CollectExtraStates(
        profile,
        onButtons or {},
        true
    )

    -- Copy the complete required state, including false values.
    for extra_id, state in pairs(onMap) do
        desired[extra_id] = state
    end

    -- Turn on newly required extras first.
    for extra_id, state in pairs(desired) do
        if state == true and previous[extra_id] ~= true then
            UTIL:TogVehicleExtras(vehicle, extra_id, true)
            previous[extra_id] = true
        end
    end

    Wait(50)

    -- Turn off extras that are no longer required.
    for extra_id, state in pairs(desired) do
        if state == false and previous[extra_id] ~= false then
            UTIL:TogVehicleExtras(vehicle, extra_id, false)
            previous[extra_id] = false
        end
    end

    -- Sync the stored button states and panel.
    for _, button in ipairs(LIGHT_BUTTONS) do
        local state = onSet[button] == true

        st[button] = state
        CVS:UpdateButtonUI(button, state)
    end
end

--[[Toggle the vehicle siren master (arms/disarms the siren controls).]]
function CVS:ToggleSirenArm(vehicle, silent)
	local armed = not IsVehicleSirenOn(vehicle)
	SetVehicleSiren(vehicle, armed)
	if trailer ~= nil and trailer ~= 0 then
		SetVehicleSiren(trailer, armed)
	end
	HUD:SetItemState('switch', armed)
	if not silent then
		if armed then
			AUDIO:Play('On', AUDIO.on_volume)
		else
			AUDIO:Play('Off', AUDIO.off_volume)
		end
	end
	CVS:UpdateButtonUI('siren_arm', armed)
end

--[[Siren Arm button (G): toggles the main siren TONE on/off.
	Only usable while in 999 mode (the master is armed by 999). Pass silent = true
	to suppress the horn confirmation.]]
function CVS:ToggleSiren(vehicle, silent)
	local st = EnsureState(vehicle)
	if not st.all_on then
		return	-- siren is only usable in 999 mode
	end
	if state_lxsiren[vehicle] == nil then
		state_lxsiren[vehicle] = 0
	end

	if state_lxsiren[vehicle] == 0 then
		--	START the main siren tone (master already armed by 999)
		HUD:SetItemState('siren', true)
		local tone = UTIL:GetToneAtPos(2)
		local tone_option = UTIL:GetToneOption(tone)
		if tone_option == 3 or tone_option == 4 then
			tone = UTIL:GetNextSirenTone(tone, vehicle, true)
		end
		ChangeMainSirenStage(vehicle, tone, silent)
	else
		--	STOP the main siren tone
		HUD:SetItemState('siren', false)
		ChangeMainSirenStage(vehicle, 0, silent)
	end
end

--[[Stops the main siren tone and disarms the master. Used when leaving 999 mode
	so the siren is cut off whenever the lighting mode changes.]]
function CVS:CutSiren(vehicle)
	if state_lxsiren[vehicle] ~= nil and state_lxsiren[vehicle] ~= 0 then
		ChangeMainSirenStage(vehicle, 0, true)
	end
	HUD:SetItemState('siren', false)
	if IsVehicleSirenOn(vehicle) then
		SetVehicleSiren(vehicle, false)
		if trailer ~= nil and trailer ~= 0 then
			SetVehicleSiren(trailer, false)
		end
		HUD:SetItemState('switch', false)
	end
	CVS:UpdateButtonUI('siren_arm', false)
end

--[[Scene mode: kill everything, then enable the configured scene lights.]]
function CVS:ToggleScene(vehicle)
    local st = EnsureState(vehicle)
    local newstate = not st.at_scene
    st.at_scene = newstate

    local scene = GetProfile(vehicle).at_scene
        or { 'rear_reds', 'rear_blues' }

    if newstate then
        -- Stop the audible siren tone only.
        -- Do not call CVS:CutSiren here because it disables SetVehicleSiren.
        if state_lxsiren[vehicle] ~= nil and state_lxsiren[vehicle] ~= 0 then
            ChangeMainSirenStage(vehicle, 0, true)
        end

        HUD:SetItemState('siren', false)
		CVS:UpdateButtonUI('siren_arm', false)
		HUD:SetItemState('switch', false)

        -- Keep the light master enabled.
        if not IsVehicleSirenOn(vehicle) then
            SetVehicleSiren(vehicle, true)
        end

        CVS:ApplyLightSet(vehicle, scene)

        st.all_on = false
        CVS:UpdateButtonUI('all_on', 'scene')
    else
        CVS:CutSiren(vehicle)
        CVS:ApplyLightSet(vehicle, {})
        CVS:UpdateButtonUI('all_on', false)
    end

    CVS:UpdateButtonUI('at_scene', newstate)
end

--[[All lights on (999): enable every configured light and arm the siren; toggling off kills all.]]
function CVS:ToggleAllOn(vehicle)
	local st = EnsureState(vehicle)
	local newstate = not st.all_on
	st.all_on = newstate

	if newstate then
		local list = GetProfile(vehicle).all_on or LIGHT_BUTTONS
		CVS:ApplyLightSet(vehicle, list)
		if not IsVehicleSirenOn(vehicle) then
			CVS:ToggleSirenArm(vehicle, true)
		end
	else
		CVS:CutSiren(vehicle)
		CVS:ApplyLightSet(vehicle, {})
		st.at_scene = false
		CVS:UpdateButtonUI('at_scene', false)
	end

	CVS:UpdateButtonUI('all_on', newstate)
end

---------------------------------------------------------------------
--[[Cycles through the CVS modes: 999 -> At Scene -> Cancel (all off) -> ...
	Updates the panel lights and plays the matching mode sound each step.]]
function CVS:CycleModes(vehicle)
	local st = EnsureState(vehicle)
	if st.at_scene then
		--	At Scene -> Cancel (everything off)
		CVS:ToggleScene(vehicle)
		CVS:CutSiren(vehicle)
		CVS:PlaySound(GetCvsSound(vehicle, 'leave'))
	elseif st.all_on then
		--	999 -> At Scene. ToggleScene turns the 999 lights off and the scene lights on
		--	in ONE deduped pass, so we must NOT call ToggleAllOn first (that would disable
		--	then re-enable shared extras in the same frame, which GTA ignores).
		CVS:ToggleScene(vehicle)
		CVS:PlaySound(GetCvsSound(vehicle, 'scene'))
	else
		--	Off -> 999
		CVS:ToggleAllOn(vehicle)
		CVS:PlaySound(GetCvsSound(vehicle, 'all_on'))
	end
end

---------------------------------------------------------------------
--[[Central dispatcher for a button press (from click or keybind).]]
function CVS:Press(button)
	if not player_is_emerg_driver or veh == nil then
		return
	end
	if key_lock then
		return
	end

	if button == 'siren_arm' then
		CVS:ToggleSiren(veh)
	elseif button == 'at_scene' then
		CVS:ToggleScene(veh)
		if EnsureState(veh).at_scene then
			CVS:PlaySound(GetCvsSound(veh, 'scene'))
		else
			CVS:PlaySound(GetCvsSound(veh, 'leave'))
		end
	elseif button == 'all_on' then
		CVS:ToggleAllOn(veh)
		if EnsureState(veh).all_on then
			CVS:PlaySound(GetCvsSound(veh, 'all_on'))
		else
			CVS:PlaySound(GetCvsSound(veh, 'leave'))
		end
	else
		local st = EnsureState(veh)
		CVS:SetLight(veh, button, not st[button])
		CVS:PlaySound(GetCvsSound(veh, 'action'))
	end
end

---------------------------------------------------------------------
--[[NUI callback for mouse clicks on the panel.]]
RegisterNUICallback('cvs:buttonClick', function(data, cb)
	if data ~= nil and data.button ~= nil then
		CVS:Press(data.button)
	end
	cb('ok')
end)

---------------------------------------------------------------------
--[[Register a command + keymapping for each button. Most keys are unbound by default;
	the siren defaults to G and the mode-cycle defaults to Q.]]
local CVS_BUTTONS = {
	{ cmd = '_cvs_front_blues',  button = 'front_blues',  desc = 'CVS: Front Blues',        key = '' },
	{ cmd = '_cvs_rear_reds',    button = 'rear_reds',    desc = 'CVS: Rear Reds',          key = 'K' },
	{ cmd = '_cvs_front_whites', button = 'front_whites', desc = 'CVS: Front Whites',       key = '' },
	{ cmd = '_cvs_rear_blues',   button = 'rear_blues',   desc = 'CVS: Rear Blues',         key = '' },
	{ cmd = '_cvs_siren_arm',    button = 'siren_arm',    desc = 'CVS: Siren Arm',          key = 'G' },
}

CreateThread(function()
	for _, b in ipairs(CVS_BUTTONS) do
		RegisterCommand(b.cmd, function()
			CVS:Press(b.button)
		end)
		RegisterKeyMapping(b.cmd, b.desc, 'keyboard', b.key or '')
	end

	--	Cycle through the lighting modes (999 -> At Scene -> Cancel). This is the ONLY mode
	--	keybind and is shown in the FiveM key bindings so it can be rebound. Defaults to Q.
	RegisterCommand('_cvs_cycle_modes', function()
		if player_is_emerg_driver and veh ~= nil and not key_lock then
			CVS:CycleModes(veh)
		end
	end)
	RegisterKeyMapping('_cvs_cycle_modes', 'CVS: Cycle Modes (999 / At Scene / Cancel)', 'keyboard', 'Q')

	--	Toggle the mouse cursor so the panel can be clicked.
	RegisterCommand('_cvs_cursor', function()
		if not player_is_emerg_driver then
			return
		end
		cvs_focus = not cvs_focus
		SetNuiFocus(cvs_focus, cvs_focus)
	end)
	RegisterKeyMapping('_cvs_cursor', 'CVS: Toggle mouse cursor', 'keyboard', '')
end)

---------------------------------------------------------------------
--[[Send static labels once the panel is ready.]]
CreateThread(function()
	Wait(1000)
	SendNUIMessage({ _type = 'cvs:setDisplay', text = cvs_display_label or '999' })
	SendNUIMessage({ _type = 'cvs:setFooter', text = cvs_footer_label or '' })
end)

--[[Keep the Siren Arm indicator in sync with the actual siren state.]]
CreateThread(function()
	local last_state = nil
	while true do
		if player_is_emerg_driver and veh ~= nil then
			local on = IsVehicleSirenOn(veh)
			if on ~= last_state then
				CVS:UpdateButtonUI('siren_arm', on)
				last_state = on
			end
			Wait(300)
		else
			last_state = nil
			Wait(1000)
		end
	end
end)

--[[Refresh the panel to the new vehicle's stored states on vehicle change.]]
AddEventHandler('lvc:onVehicleChange', function()
	Wait(250)
	SendNUIMessage({ _type = 'cvs:setDisplay', text = cvs_display_label or '999' })
	SendNUIMessage({ _type = 'cvs:setFooter', text = cvs_footer_label or '' })
	if veh ~= nil then
		CVS:RefreshUI(veh)
	end
end)
