
// server-side round system

include("config.lua")

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

function GetZoneSpeed()
	return GetConVar("lst_zonespeed"):GetFloat()
end

zoneisactive = false
canattack = false

-------------- ROUND SYSTEM --------------

function Round_Check()
	if #player.GetAll() < MinPlayers() then return end
	local usable = true
	if MAPCONFIG == nil then
		usable = false
	end
	if MAPCONFIG[game.GetMap()] == nil then
		usable = false
	end
	if MAPCONFIG[game.GetMap()]["spawns"] == nil then
		usable = false
	end
	if MAPCONFIG[game.GetMap()]["weaponspawns"] == nil then
		usable = false
	end
	if MAPCONFIG[game.GetMap()]["endpositions"] == nil then
		usable = false
	end
	if usable == false then
		Error("This map is not compatible with this gamemode or config file is broken.")
		return false
	end
	if usable then return true end
end
 
function GM:Tick()
	if GetState() == STATE_NONE then
		if #team.GetPlayers(TEAM_PLAYER) >= MinPlayers() then
			print("rround2")
			if #team.GetPlayers(TEAM_PLAYER) >= math.floor(#player.GetAll() / 3) then
				RoundRestart()
			end
		end
	end
	if GetState() == STATE_LIVE then
		if zoneisactive then
			if GetGlobalInt("Zone_Radius") < 1750 then
				if startednuclearsiren == false then
					startednuclearsiren = true
					BroadcastLua('surface.PlaySound("gbombs_5/sirens/nuclear_siren.wav")')
				end
			end
			if GetGlobalInt("Zone_Radius") > 0 then
				SetGlobalInt( "Zone_Radius", GetGlobalInt("Zone_Radius") - GetZoneSpeed() )
			elseif GetConVar("lst_enableimplosion"):GetInt() == 1 then
				zoneisactive = false
				implosionbomb = ents.Create( "hb_main_implosionbomb_edit" )
				if IsValid(implosionbomb) then
					implosionbomb:SetPos( GetGlobalVector("Zone_Pos") )
					implosionbomb:Spawn()
					implosionbomb:Arm()
					implosionbomb:ExplodeEDIT()
				end
				BroadcastLua('RunConsoleCommand("stopsound")')
			end
		end
	end
end

function RunEvents(num)
	if num == 1 then
		PrintMessage(HUD_PRINTTALK, "Nuclear airstrike inbound")
		PrintMessage(HUD_PRINTCENTER, "Nuclear airstrike inbound!")
		local nuke = ents.Create( "hb_nuclear_fatman" )
		local pos = table.Random(MAPCONFIG[game.GetMap()]["events"]["nukepositions"])
		nuke:SetPos( pos )
		nuke:Spawn()
		nuke:Arm()
		// lua_run RunEvents(2)
	elseif num == 2 then
		local airdropcount = math.random(1,4)
		local allspawns = {}
		table.Add(allspawns, MAPCONFIG[game.GetMap()]["events"]["supplydrops"])
		for i=1, airdropcount do
			table.RemoveByValue(allspawns, table.Random(allspawns))
		end
		PrintMessage(HUD_PRINTTALK, tostring(#allspawns) .. " supply airdrops incoming.")
		PrintMessage(HUD_PRINTCENTER, tostring(#allspawns) .. " supply airdrops incoming!")
		for k,v in pairs(allspawns) do
			local supplydrop = ents.Create( "ent_supplydrop_fix" )
			supplydrop:SetPos( v )
			supplydrop:Spawn()
		end
	end
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
	timer.Destroy("timer_prearing")
	timer.Destroy("timer_attackdelay")
	timer.Destroy("timer_event1")
	timer.Destroy("timer_event2")
	canattack = false
	SetState(STATE_PREPARING)
	PrintMessage(HUD_PRINTTALK, "Game is starting in " .. PrepTime() .. " seconds")
	PrintMessage(HUD_PRINTCENTER, "Game is starting in " .. PrepTime() .. " seconds")
	net.Start("LST_PrepStart")
	net.Broadcast()
	timer.Create("timer_prearing", PrepTime(), 1, function()
		for k,pl in pairs(player.GetAll()) do
			for k2,pl2 in pairs(pl.wantstoleave) do
				for k3,pl_teamer_64 in pairs(pl.TeamingPlayers) do
					if pl_teamer_64 == pl2:SteamID64() then
						for k4,v in pairs(pl.TeamingPlayers) do
							if v != pl2:SteamID64() then
								local plyr = player.GetBySteamID64( v )
								if plyr != false then
									print("removing " .. plyr:Nick() .. " from " .. pl2:Nick() .. "'s mates")
									table.RemoveByValue(pl2.TeamingPlayers, plyr:SteamID64())
									plyr:PrintMessage(HUD_PRINTTALK, pl2:Nick() .. " is no longer in your team")
									print("removing " .. pl2:Nick() .. " from " .. plyr:Nick() .. "'s mates")
									table.RemoveByValue(plyr.TeamingPlayers, pl2:SteamID64())
									plyr:UpdateTeamers()
								end
							end
						end
						
						print("removing " .. pl2:Nick() .. " from " .. pl:Nick() .. "'s mates")
						table.RemoveByValue(pl.TeamingPlayers, pl2:SteamID64())
						pl:PrintMessage(HUD_PRINTTALK, pl2:Nick() .. " is no longer in your team")
						pl:UpdateTeamers()
						print("removing " .. pl:Nick() .. " from " .. pl2:Nick() .. "'s mates")
						table.RemoveByValue(pl2.TeamingPlayers, pl:SteamID64())
						pl2:UpdateTeamers()
						pl.wantstoleave = {}
						
					end
				end
			end
		end
		local cnt = player.GetAll()
		if #cnt == 4 then
			if IsInTeam3(cnt[1], cnt[2], cnt[3], cnt[4]) then
				PrintMessage(HUD_PRINTTALK, "You cannot start the game when all players are in a team")
				SetState(STATE_NONE)
				return
			end
		end
		if #cnt == 3 then
			if IsInTeam3(cnt[1], cnt[2], cnt[3]) then
				PrintMessage(HUD_PRINTTALK, "You cannot start the game when all players are in a team")
				SetState(STATE_NONE)
				return
			end
		end
		if #cnt == 2 then
			if IsInTeam(cnt[1], cnt[2]) then
				PrintMessage(HUD_PRINTTALK, "You cannot start the game when all players are in a team")
				SetState(STATE_NONE)
				return
			end
		end
		game.CleanUpMap()
		PrintMessage(HUD_PRINTTALK, "Game is live! Players will be able to fight after " .. ActionPrepTime() .. " seconds.")
		PrintMessage(HUD_PRINTCENTER, "Game is live!")
		PrintMessage(HUD_PRINTTALK, "Mini-Freezes are normal ;)")
		canattack = false
		timer.Create("timer_attackdelay", ActionPrepTime(), 1, function()
			canattack = true
			PrintMessage(HUD_PRINTTALK, "Action phase is live! Players are able to fight now.")
			PrintMessage(HUD_PRINTCENTER, "Action phase is live!")
			net.Start("LST_ActionStart")
			net.Broadcast()
		end)
		timer.Create("timer_event1", 300, 1, function()
			PrintMessage(HUD_PRINTTALK, "Random event starts in one minute")
			PrintMessage(HUD_PRINTCENTER, "Random event starts in one minute")
			timer.Create("timer_event2", 60, 1, function()
				if GetConVar("lst_event_enablenuke"):GetInt() == 1 then
					if math.random(1,3) == 1 then
						RunEvents(1)
					else
						RunEvents(2)
					end
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
		local allspawns = {}
		table.Add(allspawns, MAPCONFIG[game.GetMap()]["playerspawns"])
		
		for k,pl in pairs(player.GetAll()) do
			pl.roundkills = 0
			local spawn = table.Random(allspawns)
			pl:Spawn()
			pl:SetActivePlayer()
			if spawn == nil then spawn = table.Random(allspawns) print("bad spawn:" .. spawn) end
			pl:SetPos(spawn)
			table.RemoveByValue(allspawns, spawn)
		end
		net.Start("LST_RoundStart")
		net.Broadcast()
	end)
end

////////////// ROUND SYSTEM //////////////

function SetupZone()
	local pos = table.Random( MAPCONFIG[game.GetMap()]["endpositions"] )
	//local zonepos3d = pos["pos3d"]
	//local zonepos2d = pos["pos2d"]
	SetGlobalVector( "Zone_Pos", pos )
	//SetGlobalString( "Zone_Pos2D", zonepos2d )
	//SetGlobalFloat( "Zone_Pos2D_x", pos["pos2d"][1] )
	//SetGlobalFloat( "Zone_Pos2D_y", pos["pos2d"][2] )
	SetGlobalInt( "Zone_Radius", MAPCONFIG[game.GetMap()]["zone_radius"] )
	
	zone = ents.Create( "ent_zone" )
	if IsValid(zone) then
		zone:SetPos( pos )
		zone:Spawn()
	end
	net.Start("LST_ZoneSetup")
	net.Broadcast()
end

function IsInZone(ply)
	local radius = GetGlobalInt( "Zone_Radius")
	if radius < 1 then
		return false
	end
	local allents = ents.FindInSphere( GetGlobalInt( "Zone_Pos"), radius )
	for k,v in pairs(allents) do
		if v == ply then
			return true
		end
	end
	return false
end

function HurtPlayers()
	if GetState() != STATE_LIVE then return end
	for k,v in pairs( player.GetAll() ) do
		if IsInZone(v) == false then
			v:TakeDamage( 1, v, v )
		elseif GetConVar("lst_healhealth"):GetInt() == 1 then
			if v:Health() < 20 then
				v:SetHealth(v:Health() + 1)
			end
		end
	end
end
timer.Create("HurtAllPlayers", 0.36, 0, HurtPlayers)

function SpawnAllVehicles()
	for k,v in pairs(MAPCONFIG[game.GetMap()]["vehiclepositions"]) do
		local spawn = v
		local car = ents.Create( table.Random(VEHICLES) )
		if IsValid( car ) then
			car:SetPos( spawn )
			car:Spawn()
		end
	end
end

function GetItemsToSpawn(n1,n2,n3,n4,n5)
	local tabl = {}
	for i=1, n1 do
		table.ForceInsert(tabl, table.Random(ITEMS["BETTERWEAPONS"]))
	end
	for i=1, n2 do
		table.ForceInsert(tabl, table.Random(ITEMS["WEAPONS"]))
	end
	for i=1, n3 do
		table.ForceInsert(tabl, table.Random(ITEMS["ADDITIONALWEAPONS"]))
	end
	for i=1, n4 do
		table.ForceInsert(tabl, table.Random(ITEMS["ITEMS"]))
	end
	for i=1, n5 do
		table.ForceInsert(tabl, table.Random(ITEMS["AMMO"]))
	end
	return tabl
end

function NewSpawnAllItems()
	local itemstospawn = {}
	local spawns = {}
	table.Add(spawns, MAPCONFIG[game.GetMap()]["weaponspawns"])
	local pls = #player.GetAll()
	itemstospawn = GetItemsToSpawn(MAPCONFIG[game.GetMap()]["weaponsc"][1],MAPCONFIG[game.GetMap()]["weaponsc"][2],MAPCONFIG[game.GetMap()]["weaponsc"][3],MAPCONFIG[game.GetMap()]["weaponsc"][4],MAPCONFIG[game.GetMap()]["weaponsc"][5])
	//PrintTable(itemstospawn)
	for k,v in pairs(itemstospawn) do
		local it = ents.Create( v )
		if IsValid( it ) then
			local pos = table.Random(spawns)
			if pos == nil then pos = table.Random(spawns) print(pos) print(v) return end
			it:SetPos( pos )
			table.RemoveByValue(spawns, pos)
			it:Spawn()
			it.kanadelootable = true
		end
	end
end

function SpawnAllFlyingVehicles()
	for k,v in pairs(MAPCONFIG[game.GetMap()]["flying_vehiclespawns"]) do
		if math.random(1,100) <= 50 then
			local spawn = v
			local vehicle = ents.Create( table.Random(FLYING_VEHICLES["VERYRARE"]) )
			if IsValid( vehicle ) then
				vehicle:SetPos( spawn )
				vehicle:Spawn()
			end
		else
			local spawn = v
			local vehicle = ents.Create( table.Random(FLYING_VEHICLES["RARE"]) )
			if IsValid( vehicle ) then
				vehicle:SetPos( spawn )
				vehicle:Spawn()
			end
		end
	end
end

function GM:PlayerCanHearPlayersVoice( listener, talker )
	if talker:Team() == TEAM_SPEC and listener:Team() == TEAM_CONT then
		return false
	end
	/*
	if talker:Team() == TEAM_CONT and listener:Team() == TEAM_CONT then
		if talker:GetPos():Distance(listener:GetPos()) > 1250 then
			if IsInTeam(listener, talker) then
				return true
			end
			return false
		end
	end
	*/
	return true
end

function GM:PlayerCanSeePlayersChat( text, teamOnly, listener, speaker )
	if listener == speaker then return true end
	if speaker:Team() == TEAM_SPEC and listener:Team() == TEAM_CONT then
		return false
	end
	if teamOnly then
		if IsInTeam(listener, speaker) then
			return true
		else
			return false
		end
	end
	return true
end
