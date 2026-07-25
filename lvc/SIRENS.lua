--[[
---------------------------------------------------
LUXART VEHICLE CONTROL V3 (FOR FIVEM)
---------------------------------------------------
Coded by Lt.Caine
ELS Clicks by Faction
Additions by TrevorBarns
---------------------------------------------------
FILE: SIRENS.lua
PURPOSE: Associate specific sirens with specific
vehicles. Siren assignments. 
---------------------------------------------------
SIREN TONE TABLE: 
	ID- Generic Name	(SIREN STRING)									[vehicles.awc name]
	1 - Airhorn 		(SIRENS_AIRHORN)								[AIRHORN_EQD]
	2 - Wail 			(VEHICLES_HORNS_SIREN_1)						[SIREN_PA20A_WAIL]
	3 - Yelp 			(VEHICLES_HORNS_SIREN_2)						[SIREN_2]
	4 - Priority 		(VEHICLES_HORNS_POLICE_WARNING)					[POLICE_WARNING]
	5 - CustomA* 		(RESIDENT_VEHICLES_SIREN_WAIL_01)				[SIREN_WAIL_01]
	6 - CustomB* 		(RESIDENT_VEHICLES_SIREN_WAIL_02)				[SIREN_WAIL_02]
	7 - CustomC* 		(RESIDENT_VEHICLES_SIREN_WAIL_03)				[SIREN_WAIL_03]
	8 - CustomD* 		(RESIDENT_VEHICLES_SIREN_QUICK_01)				[SIREN_QUICK_01]
	9 - CustomE* 		(RESIDENT_VEHICLES_SIREN_QUICK_02)				[SIREN_QUICK_02]
	10 - CustomF* 		(RESIDENT_VEHICLES_SIREN_QUICK_03)				[SIREN_QUICK_03]
	11 - Powercall 		(VEHICLES_HORNS_AMBULANCE_WARNING)				[AMBULANCE_WARNING]
	12 - FireHorn	 	(VEHICLES_HORNS_FIRETRUCK_WARNING)				[FIRE_TRUCK_HORN]
	13 - Firesiren 		(RESIDENT_VEHICLES_SIREN_FIRETRUCK_WAIL_01)		[SIREN_FIRETRUCK_WAIL_01]
	14 - Firesiren2 	(RESIDENT_VEHICLES_SIREN_FIRETRUCK_QUICK_01)	[SIREN_FIRETRUCK_QUICK_01]
]]
-- CHANGE SIREN NAMES, AUDIONAME, AUDIOREF
--	UK NOTE: The `Name` fields below have been set to UK-style tone names. The `String` field is the in-game
--	audio bank that actually plays. If you are adding your own UK siren banks (audio), replace the `String`
--	value with your custom audio name so the correct sound plays for that tone.
--
--	CUSTOM SIRENS & SOUND BANKS:
--
--	z_els / DAT54 style (no soundset):
--		{ Name = 'UK Hi-Lo', String = 'custom_hilo', Ref = 0, Bank = 'dlc_lvc_sirens/hilo' }
--
--	SirenSharp style (Bank + SoundSet):
--		Each AWC (soundset) produces one AWC file named {soundset}.awc inside dlc_{dlcname}/.
--		The in-game tester (F8 console) prints the exact values you need:
--			Bank     = 'dlc_{dlcname}/{soundset}'  e.g. 'dlc_sirens/police'
--			String   = the siren name inside the AWC e.g. 'wail'
--			SoundSet = the soundset name (same as the AWC stem) e.g. 'police'
--			Ref      = leave 0 for SirenSharp entries (SoundSet is used instead)
--
--		Example (4 tones from one soundset):
--			{ Name = 'Police Bullhorn', String = 'bullhorn', SoundSet = 'police', Bank = 'dlc_sirens/police', Ref = 0 },
--			{ Name = 'Police Wail',     String = 'wail',     SoundSet = 'police', Bank = 'dlc_sirens/police', Ref = 0 },
--			{ Name = 'Police Yelp',     String = 'yelp',     SoundSet = 'police', Bank = 'dlc_sirens/police', Ref = 0 },
--			{ Name = 'Police Phaser',   String = 'phaser',   SoundSet = 'police', Bank = 'dlc_sirens/police', Ref = 0 },
--
--	Fields:
--		Name     = display name in the menu.
--		String   = the audioName  (sound name inside the .awc).
--		Ref      = the audioRef   (integer for built-in game sounds; leave 0 for SirenSharp).
--		SoundSet = soundset name  (SirenSharp only; overrides Ref as the audioRef string).
--		Bank     = script audio bank path to request, e.g. 'dlc_sirens/police'. Omit for built-in.
SIRENS = {
	--[[1]]   { Name = 'Airhorn',     String = 'SIRENS_AIRHORN',                           Ref = 1 }, --1
	--[[2]]   { Name = 'Wail',        String = 'VEHICLES_HORNS_SIREN_1',                   Ref = 2 }, --2
	--[[3]]   { Name = 'Yelp',        String = 'VEHICLES_HORNS_SIREN_2',                   Ref = 3 }, --3
	--[[4]]   { Name = 'Priority',    String = 'VEHICLES_HORNS_POLICE_WARNING',            Ref = 4 }, --4
	--[[5]]   { Name = 'Hi-Lo',       String = 'RESIDENT_VEHICLES_SIREN_WAIL_01',          Ref = 0 }, --5
	--[[6]]   { Name = 'Two-Tone',    String = 'RESIDENT_VEHICLES_SIREN_WAIL_02',          Ref = 0 }, --6
	--[[7]]   { Name = 'Rumbler',     String = 'RESIDENT_VEHICLES_SIREN_WAIL_03',          Ref = 0 }, --7
	--[[8]]   { Name = 'Wail 2',      String = 'RESIDENT_VEHICLES_SIREN_QUICK_01',         Ref = 0 }, --8
	--[[9]]   { Name = 'Yelp 2',      String = 'RESIDENT_VEHICLES_SIREN_QUICK_02',         Ref = 0 }, --9
	--[[10]]  { Name = 'Priority 2',  String = 'RESIDENT_VEHICLES_SIREN_QUICK_03',         Ref = 0 }, --10
	--[[11]]  { Name = 'Powercall',   String = 'VEHICLES_HORNS_AMBULANCE_WARNING',         Ref = 0 }, --11
	--[[12]]  { Name = 'Fire Horn',   String = 'VEHICLES_HORNS_FIRETRUCK_WARNING',         Ref = 0 }, --12
	--[[13]]  { Name = 'Fire Yelp',   String = 'RESIDENT_VEHICLES_SIREN_FIRETRUCK_WAIL_01',  Ref = 0 }, --13
	--[[14]]  { Name = 'Fire Wail',   String = 'RESIDENT_VEHICLES_SIREN_FIRETRUCK_QUICK_01', Ref = 0 }, --14

	-- =====================================================================
	-- CUSTOM AUDIO BANKS
	-- SoundSet = lowercase(AWC name) + '_soundset'
	-- Bank     = 'DLC_NAME/AWC_NAME'  (matches cfg.audioBanks with / instead of \)
	-- =====================================================================

	-- ---- DLC_RSG_RUM / RSG32RUMBLER -------------------------------------
	--[[15]]  { Name = 'RSG Bullhorn',     String = 'bullhorn', SoundSet = 'rsg32rumbler_soundset', Bank = 'DLC_RSG_RUM/RSG32RUMBLER',        Ref = 15 }, --15
	--[[16]]  { Name = 'RSG Wail',         String = 'wail',     SoundSet = 'rsg32rumbler_soundset', Bank = 'DLC_RSG_RUM/RSG32RUMBLER',        Ref = 16 }, --16
	--[[17]]  { Name = 'RSG Yelp',         String = 'yelp',     SoundSet = 'rsg32rumbler_soundset', Bank = 'DLC_RSG_RUM/RSG32RUMBLER',        Ref = 17 }, --17
	--[[18]]  { Name = 'RSG Phaser',       String = 'phaser',   SoundSet = 'rsg32rumbler_soundset', Bank = 'DLC_RSG_RUM/RSG32RUMBLER',        Ref = 18 }, --18

	-- ---- DLC_PREMIUM_HAZARD / PREMIUMHAZ --------------------------------
	--[[19]]  { Name = 'Hazard Bullhorn',  String = 'bullhorn', SoundSet = 'premiumhaz_soundset',   Bank = 'DLC_PREMIUM_HAZARD/PREMIUMHAZ',   Ref = 19 }, --19
	--[[20]]  { Name = 'Hazard Wail',      String = 'wail',     SoundSet = 'premiumhaz_soundset',   Bank = 'DLC_PREMIUM_HAZARD/PREMIUMHAZ',   Ref = 20 }, --20
	--[[21]]  { Name = 'Hazard Yelp',      String = 'yelp',     SoundSet = 'premiumhaz_soundset',   Bank = 'DLC_PREMIUM_HAZARD/PREMIUMHAZ',   Ref = 21 }, --21
	--[[22]]  { Name = 'Hazard Phaser',    String = 'phaser',   SoundSet = 'premiumhaz_soundset',   Bank = 'DLC_PREMIUM_HAZARD/PREMIUMHAZ',   Ref = 22 }, --22

	-- ---- DLC_MCS_32 / MCS32 ---------------------------------------------
	--[[23]]  { Name = 'MCS Bullhorn',     String = 'bullhorn', SoundSet = 'mcs32_soundset',        Bank = 'DLC_MCS_32/MCS32',                Ref = 23 }, --23
	--[[24]]  { Name = 'MCS Wail',         String = 'wail',     SoundSet = 'mcs32_soundset',        Bank = 'DLC_MCS_32/MCS32',                Ref = 24 }, --24
	--[[25]]  { Name = 'MCS Yelp',         String = 'yelp',     SoundSet = 'mcs32_soundset',        Bank = 'DLC_MCS_32/MCS32',                Ref = 25 }, --25
	--[[26]]  { Name = 'MCS Phaser',       String = 'phaser',   SoundSet = 'mcs32_soundset',        Bank = 'DLC_MCS_32/MCS32',                Ref = 26 }, --26

	-- ---- DLC_WHSIRENS / ALPHA -------------------------------------------
	--[[27]]  { Name = 'WH Alpha Bullhorn',String = 'bullhorn', SoundSet = 'alpha_soundset',        Bank = 'DLC_WHSIRENS/ALPHA',              Ref = 27 }, --27
	--[[28]]  { Name = 'WH Alpha Wail',    String = 'wail',     SoundSet = 'alpha_soundset',        Bank = 'DLC_WHSIRENS/ALPHA',              Ref = 28 }, --28
	--[[29]]  { Name = 'WH Alpha Yelp',    String = 'yelp',     SoundSet = 'alpha_soundset',        Bank = 'DLC_WHSIRENS/ALPHA',              Ref = 29 }, --29
	--[[30]]  { Name = 'WH Alpha Phaser',  String = 'phaser',   SoundSet = 'alpha_soundset',        Bank = 'DLC_WHSIRENS/ALPHA',              Ref = 30 }, --30

	-- ---- DLC_WHSIRENS / EURO --------------------------------------------
	--[[31]]  { Name = 'WH Euro Bullhorn', String = 'bullhorn', SoundSet = 'euro_soundset',         Bank = 'DLC_WHSIRENS/EURO',               Ref = 31 }, --31
	--[[32]]  { Name = 'WH Euro Wail',     String = 'wail',     SoundSet = 'euro_soundset',         Bank = 'DLC_WHSIRENS/EURO',               Ref = 32 }, --32
	--[[33]]  { Name = 'WH Euro Yelp',     String = 'yelp',     SoundSet = 'euro_soundset',         Bank = 'DLC_WHSIRENS/EURO',               Ref = 33 }, --33
	--[[34]]  { Name = 'WH Euro Phaser',   String = 'phaser',   SoundSet = 'euro_soundset',         Bank = 'DLC_WHSIRENS/EURO',               Ref = 34 }, --34

	-- ---- DLC_SBCONE / STANDBYCONE ---------------------------------------
	--[[35]]  { Name = 'SB Bullhorn',      String = 'bullhorn', SoundSet = 'standbycone_soundset',  Bank = 'DLC_SBCONE/STANDBYCONE',          Ref = 35 }, --35
	--[[36]]  { Name = 'SB Wail',          String = 'wail',     SoundSet = 'standbycone_soundset',  Bank = 'DLC_SBCONE/STANDBYCONE',          Ref = 36 }, --36
	--[[37]]  { Name = 'SB Yelp',          String = 'yelp',     SoundSet = 'standbycone_soundset',  Bank = 'DLC_SBCONE/STANDBYCONE',          Ref = 37 }, --37
	--[[38]]  { Name = 'SB Phaser',        String = 'phaser',   SoundSet = 'standbycone_soundset',  Bank = 'DLC_SBCONE/STANDBYCONE',          Ref = 38 }, --38
	--[[39]]  { Name = 'SB Hi-Lo',         String = 'hilo',     SoundSet = 'standbycone_soundset',  Bank = 'DLC_SBCONE/STANDBYCONE',          Ref = 39 }, --39
}

--=====================================================================
--	VEHICLE REGISTRY
--=====================================================================
--	Add a RegisterVehicle call below for each vehicle (see _TEMPLATE.lua for
--	all available options). Keep this file; VEHICLES/*.lua are no longer used.
SIREN_ASSIGNMENTS  = { }
CVS_EXTRAS         = { }
SIREN_HORN_SOUNDS  = { }
CVS_SOUNDS         = { }
SIREN_STAGE_SFX    = { }

function RegisterVehicle(model, config)
	if type(model) ~= 'string' or type(config) ~= 'table' then
		return
	end
	print('[LVC] RegisterVehicle: ' .. model)
	if config.tones ~= nil then
		SIREN_ASSIGNMENTS[model] = config.tones
	end
	if config.extras ~= nil then
		CVS_EXTRAS[model] = config.extras
	end
	if config.horn ~= nil then
		SIREN_HORN_SOUNDS[model] = config.horn
	end
	if config.sounds ~= nil then
		CVS_SOUNDS[model] = config.sounds
	end
	if config.stage_sfx ~= nil then
		SIREN_STAGE_SFX[model] = config.stage_sfx
	end
end

--=====================================================================
--	VEHICLE CONFIGS
--=====================================================================

RegisterVehicle('speedorun', {

	tones = { 23, 36, 37, 38, 39 },	-- MCS Bullhorn (airhorn), SB Wail (stage 1), SB Yelp (stage 2), SB Phaser

	extras = {
		front_blues  = {4},
		rear_reds    = {2},
		front_whites = nil,
		rear_blues   = {4},
		at_scene     = { 'rear_reds', 'front_blues', 'front_whites', 'rear_blues' },
		all_on       = { 'front_blues', 'front_whites', 'rear_blues' },
	},

	horn = {
		start = 'horn/CarHornOff.wav',
		stop  = 'horn/CarHornOff2.wav',
	},

	sounds = {
		all_on = 'cvs/999mode.wav',
		scene  = 'cvs/sceneMode.wav',
		action = 'cvs/optilink.wav',
		leave  = 'cvs/optilink.wav',
	},
})

RegisterVehicle('Vulcar60CX', {

	tones = { 27, 32, 33, 34 },	-- airhorn, wail (stage 1), yelp (stage 2), priority, powercall

	extras = {
		front_blues  = {2},
		rear_reds    = {4},
		front_whites = nil,
		rear_blues   = {2},
		at_scene     = { 'rear_reds', 'front_blues', 'front_whites', 'rear_blues' },
		all_on       = { 'front_blues', 'front_whites', 'rear_blues' },
	},

	horn = {
		start = 'horn/CarHornOff.wav',
		stop  = 'horn/CarHornOff2.wav',
	},

	sounds = {
		all_on = 'cvs/999mode.wav',
		scene  = 'cvs/sceneMode.wav',
		action = 'cvs/optilink.wav',
		leave  = 'cvs/leaveMode.wav',
	},
})

RegisterVehicle('speedobox', {

	tones = { 27, 32, 33, 34 },	-- airhorn, wail (stage 1), yelp (stage 2), priority, powercall

	extras = {
		front_blues  = {4},
		rear_reds    = {2},
		front_whites = nil,
		rear_blues   = {4},
		at_scene     = { 'rear_reds', 'front_blues', 'front_whites', 'rear_blues' },
		all_on       = { 'front_blues', 'front_whites', 'rear_blues' },
	},

	horn = {
		start = 'horn/CarHornOff.wav',
		stop  = 'horn/CarHornOff2.wav',
	},

	sounds = {
		all_on = 'cvs/999mode.wav',
		scene  = 'cvs/sceneMode.wav',
		action = 'cvs/optilink.wav',
		leave  = 'cvs/leaveMode.wav',
	},
})