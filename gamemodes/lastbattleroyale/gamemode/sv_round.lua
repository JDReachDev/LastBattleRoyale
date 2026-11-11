
// server-side round system


TEAM_PLAYER = 1
TEAM_CONT = 2
TEAM_SPEC = 3

STATE_NONE = 1
STATE_PREPARING = 2
STATE_LIVE = 3
STATE_POST = 4

if GetGlobalInt("state") == 0 then
	SetGlobalInt( "state", STATE_NONE )
	SetGlobalInt( "round_num", -1 )
end

function GetRoundNum()
	return GetGlobalInt("round_num")
end

function SetRoundNum(num)
	return SetGlobalInt("round_num", num)
end

function GetState()
	return GetGlobalInt("state")
end

function SetState(num)
	SetGlobalInt("state", num)
end

local cvZoneSpeed = GetConVar("lbr_zone_speed")
local cvHeal = GetConVar("lbr_zone_heal")
local cvImplosion = GetConVar("lbr_event_implosion")
local cvNuke = GetConVar("lbr_event_nuke")

// lbr_zone_speed is "radius removed every tick", converted to units per second
function GetZoneSpeed()
	return cvZoneSpeed:GetFloat()
end

zoneisactive = false
canattack = false

local function MapCfg()
	return LBR.GetMapConfig() or {}
end

local function CatList( key, parent )
	local cfg = MapCfg()
	if parent then
		return istable( cfg[parent] ) and cfg[parent][key] or {}
	end
	return cfg[key] or {}
end

-------------- ROUND SYSTEM --------------

function Round_Check()
	if #player.GetAll() < MinPlayers() then return end
	return LBR.IsMapReady()
end

local nextNotConfiguredMsg = 0

function GM:Tick()
	local state = GetState()
	if state == STATE_NONE then
		SetGlobalInt( "LBR_MinPlayers", MinPlayers() )
		if #team.GetPlayers(TEAM_PLAYER) >= MinPlayers() and #team.GetPlayers(TEAM_PLAYER) >= math.floor(#player.GetAll() / 3) then
			if not LBR.IsMapReady() then
				if CurTime() > nextNotConfiguredMsg then
					nextNotConfiguredMsg = CurTime() + 60
					PrintMessage(HUD_PRINTTALK, "This map is not configured for Last Battle Royale. An admin can press F8 to open the map editor.")
				end
			elseif not LBR.AnyEditing() then
				RoundRestart()
			end
		end
	elseif state == STATE_LIVE and zoneisactive then
		local radius = LBR.GetZoneRadius()
		if radius < LBR.ZoneWarnRadius and startednuclearsiren == false then
			startednuclearsiren = true
			BroadcastLua('surface.PlaySound("gbombs_5/sirens/nuclear_siren.wav")')
		end
		if radius <= 0 and cvImplosion:GetInt() == 1 then
			zoneisactive = false
			implosionbomb = ents.Create( "hb_main_implosionbomb_edit" )
			if IsValid(implosionbomb) then
				implosionbomb:SetPos( LBR.GetZonePos() )
				implosionbomb:Spawn()
				implosionbomb:Arm()
				implosionbomb:ExplodeEDIT()
			end
			BroadcastLua('RunConsoleCommand("stopsound")')
		end
	end
end

function RunEvents(num)
	local nukes = CatList( "nukepositions", "events" )
	local drops = CatList( "supplydrops", "events" )
	if num == 1 and #nukes == 0 then num = 2 end
	if num == 1 then
		local nuke = ents.Create( "hb_nuclear_fatman" )
		if not IsValid( nuke ) then return end
		PrintMessage(HUD_PRINTTALK, "Nuclear airstrike inbound")
		PrintMessage(HUD_PRINTCENTER, "Nuclear airstrike inbound!")
		nuke:SetPos( nukes[math.random( #nukes )] )
		nuke:Spawn()
		nuke:Arm()
		// lua_run RunEvents(2)
	elseif num == 2 then
		if #drops == 0 then return end
		local spawns = LBR.ShuffledCopy( drops )
		local count = math.max( 1, #spawns - math.random( 1, 4 ) )
		PrintMessage(HUD_PRINTTALK, tostring(count) .. " supply airdrops incoming.")
		PrintMessage(HUD_PRINTCENTER, tostring(count) .. " supply airdrops incoming!")
		for i = 1, count do
			local supplydrop = ents.Create( "ent_supplydrop_fix" )
			if IsValid( supplydrop ) then
				supplydrop:SetPos( spawns[i] )
				supplydrop:Spawn()
			end
		end
	end
end

local function RemoveFromTeam( pl, other )
	table.RemoveByValue( pl.TeamingPlayers, other:SteamID64() )
	pl:PrintMessage( HUD_PRINTTALK, other:Nick() .. " is no longer in your team" )
	pl:UpdateTeamers()
end

// players that asked to leave a team during the previous round
local function ProcessTeamLeaves()
	for _, pl in ipairs( player.GetAll() ) do
		for _, leaver in ipairs( pl.wantstoleave or {} ) do
			if IsValid( leaver ) and table.HasValue( pl.TeamingPlayers, leaver:SteamID64() ) then
				for _, sid in ipairs( table.Copy( pl.TeamingPlayers ) ) do
					local mate = player.GetBySteamID64( sid )
					if sid ~= leaver:SteamID64() and IsValid( mate ) then
						RemoveFromTeam( leaver, mate )
						RemoveFromTeam( mate, leaver )
					end
				end
				RemoveFromTeam( pl, leaver )
				RemoveFromTeam( leaver, pl )
			end
		end
		pl.wantstoleave = {}
	end
end

// true when every player in the server is in the same team
local function EveryoneInOneTeam()
	local all = player.GetAll()
	if #all < 2 or #all > 4 then return false end
	for i = 2, #all do
		if not IsInTeam( all[1], all[i] ) then return false end
	end
	return true
end

function RoundRestart()
	if ConVarExists("lst_maxrounds") then
		print("Rounds: " .. GetRoundNum() .. "/" .. GetConVar("lst_maxrounds"):GetInt())
		if GetRoundNum() >= GetConVar("lst_maxrounds"):GetInt() then
			hook.Run("MapChange")
		elseif GetConVar("lst_maxrounds"):GetInt() - 1 == GetRoundNum() then
			PrintMessage(HUD_PRINTTALK, "Map will change after this round.")
		end
	end
	SetRoundNum(GetRoundNum() + 1)
	UpdateAllTeamers()
	RegenerateSpawns()
	timer.Remove("timer_prearing")
	timer.Remove("timer_attackdelay")
	timer.Remove("timer_event1")
	timer.Remove("timer_event2")
	canattack = false
	SetGlobalBool( "LBR_CanAttack", false )
	SetState(STATE_PREPARING)
	SetGlobalFloat( "LBR_PhaseEnd", CurTime() + PrepTime() )
	PrintMessage(HUD_PRINTTALK, "Game is starting in " .. PrepTime() .. " seconds")
	PrintMessage(HUD_PRINTCENTER, "Game is starting in " .. PrepTime() .. " seconds")
	net.Start("LST_PrepStart")
	net.Broadcast()
	timer.Create("timer_prearing", PrepTime(), 1, function()
		ProcessTeamLeaves()
		if EveryoneInOneTeam() then
			PrintMessage(HUD_PRINTTALK, "You cannot start the game when all players are in a team")
			SetState(STATE_NONE)
			return
		end
		if not LBR.IsMapReady() then
			PrintMessage(HUD_PRINTTALK, "Map config is not valid anymore, round cancelled.")
			SetState(STATE_NONE)
			return
		end
		game.CleanUpMap()
		PrintMessage(HUD_PRINTTALK, "Game is live! Players will be able to fight after " .. ActionPrepTime() .. " seconds.")
		PrintMessage(HUD_PRINTCENTER, "Game is live!")
		canattack = false
		SetGlobalFloat( "LBR_PhaseEnd", CurTime() + ActionPrepTime() )
		timer.Create("timer_attackdelay", ActionPrepTime(), 1, function()
			canattack = true
			SetGlobalBool( "LBR_CanAttack", true )
			PrintMessage(HUD_PRINTTALK, "Action phase is live! Players are able to fight now.")
			PrintMessage(HUD_PRINTCENTER, "Action phase is live!")
			net.Start("LST_ActionStart")
			net.Broadcast()
		end)
		SetGlobalFloat( "LBR_EventTime", CurTime() + 360 )
		timer.Create("timer_event1", 300, 1, function()
			PrintMessage(HUD_PRINTTALK, "Random event starts in one minute")
			PrintMessage(HUD_PRINTCENTER, "Random event starts in one minute")
			timer.Create("timer_event2", 60, 1, function()
				SetGlobalFloat( "LBR_EventTime", 0 )
				if cvNuke:GetInt() == 1 and math.random(1,3) == 1 then
					RunEvents(1)
				else
					RunEvents(2)
				end
			end)
		end)
		startednuclearsiren = false
		SetupZone()
		SetState(STATE_LIVE)
		zoneisactive = true
		NewSpawnAllItems()
		SpawnAllVehicles()
		SpawnAllFlyingVehicles()

		local spawns = LBR.ShuffledCopy( CatList( "playerspawns" ) )
		for i, pl in ipairs( player.GetAll() ) do
			pl.roundkills = 0
			pl:SetNW2Int( "LBR_Kills", 0 )
			pl:Spawn()
			pl:SetActivePlayer()
			if #spawns > 0 then
				// more players than spawns: PlacePlayer spreads them around the same point
				LBR.PlacePlayer( pl, spawns[ ( ( i - 1 ) % #spawns ) + 1 ] )
			end
		end
		net.Start("LST_RoundStart")
		net.Broadcast()
	end)
end

////////////// ROUND SYSTEM //////////////

function SetupZone()
	local centers = CatList( "endpositions" )
	local pos = centers[math.random( #centers )]
	local tickrate = 1 / engine.TickInterval()

	SetGlobalVector( "LBR_ZonePos", pos )
	SetGlobalFloat( "LBR_ZoneStartRadius", MapCfg().zone_radius or 20000 )
	SetGlobalFloat( "LBR_ZoneStartTime", CurTime() )
	SetGlobalFloat( "LBR_ZoneSpeed", GetZoneSpeed() * tickrate )

	zone = ents.Create( "ent_zone" )
	if IsValid(zone) then
		zone:SetPos( pos )
		zone:Spawn()
	end
	net.Start("LST_ZoneSetup")
	net.Broadcast()
end

function StopZone()
	zoneisactive = false
	SetGlobalFloat( "LBR_ZoneStartRadius", 0 )
end

function IsInZone(ply)
	return LBR.IsPosInZone( ply:GetPos() )
end

function HurtPlayers()
	if GetState() != STATE_LIVE then return end
	if not LBR.IsZoneActive() then return end
	local heal = cvHeal:GetInt() == 1
	for _, v in ipairs( team.GetPlayers( TEAM_CONT ) ) do
		if v:Alive() then
			if not IsInZone(v) then
				v:TakeDamage( 1, v, v )
			elseif heal and v:Health() < 20 then
				v:SetHealth(v:Health() + 1)
			end
		end
	end
end
timer.Create("HurtAllPlayers", 0.36, 0, HurtPlayers)

function SpawnAllVehicles()
	if #VEHICLES == 0 then return end
	for _, spawn in ipairs( CatList( "vehiclepositions" ) ) do
		local car = ents.Create( VEHICLES[math.random( #VEHICLES )] )
		if IsValid( car ) then
			car:SetPos( LBR.VehicleSpawnPos( spawn, 30 ) )
			car:Spawn()
		end
	end
end

local itemCategories = { "BETTERWEAPONS", "WEAPONS", "ADDITIONALWEAPONS", "ITEMS", "AMMO" }

function GetItemsToSpawn(...)
	local counts = { ... }
	local tabl = {}
	for i, cat in ipairs( itemCategories ) do
		local pool = ITEMS[cat] or {}
		if #pool > 0 then
			for _ = 1, ( counts[i] or 0 ) do
				tabl[#tabl + 1] = pool[math.random( #pool )]
			end
		end
	end
	return tabl
end

// Items are created a few per tick instead of all at once: less freeze on big maps
local ITEMS_PER_TICK = 6

function NewSpawnAllItems()
	timer.Remove( "LBR_SpawnItems" )
	local wc = MapCfg().weaponsc or {}
	local items = LBR.ShuffledCopy( GetItemsToSpawn( wc[1], wc[2], wc[3], wc[4], wc[5] ) )
	local spawns = LBR.ShuffledCopy( CatList( "weaponspawns" ) )
	local total = math.min( #items, #spawns )
	if total == 0 then return end
	local round = GetRoundNum()
	local index = 0
	timer.Create( "LBR_SpawnItems", 0, 0, function()
		if GetState() ~= STATE_LIVE or GetRoundNum() ~= round then
			timer.Remove( "LBR_SpawnItems" )
			return
		end
		for _ = 1, ITEMS_PER_TICK do
			index = index + 1
			if index > total then
				timer.Remove( "LBR_SpawnItems" )
				return
			end
			local it = ents.Create( items[index] )
			if IsValid( it ) then
				it:SetPos( spawns[index] )
				it:Spawn()
				LBR.PlaceOnFloor( it, spawns[index] )
				it.kanadelootable = true
			end
		end
	end )
end

function SpawnAllFlyingVehicles()
	for _, spawn in ipairs( CatList( "flying_vehiclespawns" ) ) do
		local pool = math.random(1,100) <= 50 and FLYING_VEHICLES["VERYRARE"] or FLYING_VEHICLES["RARE"]
		if pool and #pool > 0 then
			local vehicle = ents.Create( pool[math.random( #pool )] )
			if IsValid( vehicle ) then
				vehicle:SetPos( LBR.VehicleSpawnPos( spawn, 40 ) )
				vehicle:Spawn()
			end
		end
	end
end

function GM:PlayerCanHearPlayersVoice( listener, talker )
	if talker:Team() == TEAM_SPEC and listener:Team() == TEAM_CONT then
		return false
	end
	return true
end

function GM:PlayerCanSeePlayersChat( text, teamOnly, listener, speaker )
	if not IsValid( speaker ) then return true end
	if listener == speaker then return true end
	if speaker:Team() == TEAM_SPEC and listener:Team() == TEAM_CONT then
		return false
	end
	if teamOnly then
		return IsInTeam(listener, speaker)
	end
	return true
end
