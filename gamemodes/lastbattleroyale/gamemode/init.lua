// Server-side initialization file

AddCSLuaFile( "classes.lua" )
AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "cl_scoreboard.lua" )
AddCSLuaFile( "shared.lua" )

include( "shared.lua" )
include( "config.lua" )
include( "sv_round.lua" )
include( "sv_player.lua" )
include( "classes.lua" )
include( "classessystem.lua" )

util.AddNetworkString( "DropWeapon" )
util.AddNetworkString( "ChangeClass" )
util.AddNetworkString( "SendClassC" )
util.AddNetworkString( "SendClassS" )
util.AddNetworkString( "SendTeamRequest" )
util.AddNetworkString( "SendTeamRequestBack" )
util.AddNetworkString( "SendTeamRequestBTS" )
util.AddNetworkString( "UpdateTeamers" )
util.AddNetworkString( "LST_PrepStart" )
util.AddNetworkString( "LST_RoundStart" )
util.AddNetworkString( "LST_ActionStart" )
util.AddNetworkString( "LST_RoundEnd" )
util.AddNetworkString( "LST_ZoneSetup" )

function IsInTeam(pl1, pl2)
	if pl1:IsBot() or pl2:IsBot() then
		return false
	end
	for k,v in pairs(pl1.TeamingPlayers) do
		if v == pl2:SteamID64() then
			return true
		end
	end
	return false
end

function IsInTeam3(pl1, pl2, pl3)
	pl2_teaming = false
	pl3_teaming = false
	for k,v in pairs(pl1.TeamingPlayers) do
		if v == pl2:SteamID64() then
			pl2_teaming = true
		elseif v == pl3:SteamID64() then
			pl3_teaming = true
		end
	end
	if pl2_teaming == true and pl3_teaming == true then
		return true
	else
		return false
	end
end

function IsInTeam4(pl1, pl2, pl3, pl4)
	pl2_teaming = false
	pl3_teaming = false
	pl4_teaming = false
	for k,v in pairs(pl1.TeamingPlayers) do
		if v == pl2:SteamID64() then
			pl2_teaming = true
		elseif v == pl3:SteamID64() then
			pl3_teaming = true
		elseif v == pl4:SteamID64() then
			pl4_teaming = true
		end
	end
	if pl2_teaming == true and pl3_teaming == true and pl4_teaming == true then
		return true
	else
		return false
	end
end

if timer.Exists("checkrequeststick") == false then
	timer.Create("checkrequeststick", 1, 0, function()
		local curtime = CurTime()
		for k,v in pairs(player.GetAll()) do
			if v.REQUESTINFO != nil then
				for key,val in pairs(v.REQUESTINFO) do
					//print("val: " .. tostring(val))
					if istable(val) then PrintTable(val) end
					if curtime > val["requestedlast"] then
						if IsValid(val["requestedplayer"]) then
							v:PrintMessage(HUD_PRINTTALK, val["requestedplayer"]:Nick() .. " didn't answer team-up request in time")
							//print("reqinfo")
							//PrintTable(v.REQUESTINFO)
							//print("req: " .. tostring(val["requestedplayer"].sentteaming))
							//print("vply: " .. tostring(v.sentteaming))
							val["requestedplayer"].sentteaming = nil
							table.RemoveByValue(v.REQUESTINFO, val)
							//PrintTable(v.REQUESTINFO)
						end
					end
				end
			end
		end
	end)
end

// other player accepted, lets check again if they can teamup and then add them to a team
net.Receive( "SendTeamRequestBTS", function( len, ply )
	local getbool = net.ReadBool()
	local selectedplayer = nil
	
	if ply.sentteaming == nil then
		return
	elseif IsValid(player.GetBySteamID64( ply.sentteaming )) then
		selectedplayer = player.GetBySteamID64( ply.sentteaming )
	else
		return
	end
	
	if getbool == false then
		selectedplayer:PrintMessage(HUD_PRINTTALK, ply:Nick() .. " declined the request.")
		return
	end
	
	for k,v in pairs(selectedplayer.REQUESTINFO) do
		if v["requestedplayer"] == ply then
			table.RemoveByValue(selectedplayer.REQUESTINFO, v)
		end
	end
	
	for k,v in pairs(selectedplayer.TeamingPlayers) do
		local pl = player.GetBySteamID64( v )
		if pl != false then
			print("adding " .. ply:Nick() .. " to " .. pl:Nick() .. "'s mates")
			table.ForceInsert(pl.TeamingPlayers, ply:SteamID64())
			print("adding " .. pl:Nick() .. " to " .. ply:Nick() .. "'s mates")
			table.ForceInsert(ply.TeamingPlayers, pl:SteamID64())
			pl:UpdateTeamers()
			ply:UpdateTeamers()
		end
	end
	table.ForceInsert(selectedplayer.TeamingPlayers, ply:SteamID64())
	print("adding " .. ply:Nick() .. " to " .. selectedplayer:Nick() .. "'s mates")
	table.ForceInsert(ply.TeamingPlayers, selectedplayer:SteamID64())
	print("adding " .. selectedplayer:Nick() .. " to " .. ply:Nick() .. "'s mates")
	selectedplayer:UpdateTeamers()
	ply:UpdateTeamers()
	ply.sentteaming = nil
	
	/*
	if IsInTeam(ply, selectedplayer) == false then
		table.ForceInsert(ply.TeamingPlayers, selectedplayer:SteamID64())
		table.ForceInsert(selectedplayer.TeamingPlayers, ply:SteamID64())
		table.RemoveByValue(selectedplayer.REQUESTINFO, gotrequestinfo)
		ply.sentteaming = nil
		ply:UpdateTeamers()
		selectedplayer:UpdateTeamers()
		print(ply:Nick() .. "'s TeamingPlayers")
		PrintTable(ply.TeamingPlayers)
		print(selectedplayer:Nick() .. "'s TeamingPlayers")
		PrintTable(selectedplayer.TeamingPlayers)
	end
	*/
end)

function PLGTN(str)
	for k,v in pairs(player.GetAll()) do
		if v:Nick() == str then
			return v
		end
	end
	return nil
end

// we received a request, check if both players can team up and then send the request to the other player
net.Receive( "SendTeamRequest", function( len, ply )
	
	local getstr = net.ReadString()
	local gotplayer = nil
	
	if #player.GetAll() == 2 then
		ply:PrintMessage(HUD_PRINTTALK, "You cannot send request now.")
		return
	end
	
	if ply:Team() == TEAM_SPEC then return end
	
	local tryget = PLGTN(getstr)
	if tryget != nil then
		gotplayer = tryget
	else
		print("player not valid, return")
		return
	end
	
	if IsInTeam(ply, gotplayer) == true then
		local maymay = nil
		for k,v in pairs(ply.wantstoleave) do
			if v == gotplayer then
				maymay = v
			end
		end
		if maymay == nil then
			table.ForceInsert(ply.wantstoleave, gotplayer)
			gotplayer:PrintMessage(HUD_PRINTTALK, ply:Nick() .. " will leave your team in the next round")
			ply:PrintMessage(HUD_PRINTTALK, gotplayer:Nick() .. " will leave your team in the next round")
		end
		return
	end
	
	if gotplayer.sentteaming != nil then
		print("fefe000")
		ply:PrintMessage(HUD_PRINTTALK, gotplayer:Nick() .. " cannot receive request now.")
		return
	end
	if gotplayer:Team() == TEAM_SPEC then return end
	
	if GetState() == STATE_LIVE then
		local cnt = {}
		for k,v in pairs(team.GetPlayers(TEAM_CONT)) do
			if v != gotplayer then
				table.ForceInsert(cnt, v)
			end
		end
		if #cnt == 3 then
			if IsInTeam3(cnt[1], cnt[2]) then
				ply:PrintMessage(HUD_PRINTTALK, "You cannot send request now.")
				return
			end
		end
		if #cnt == 2 then
			ply:PrintMessage(HUD_PRINTTALK, "You cannot send request now.")
			return
		end
	end
	
	if GetState() == STATE_LIVE then
		if canattack then
			ply:PrintMessage(HUD_PRINTTALK, "You cannot send request after preparation phase.")
			return
		end
	end
	
	if #gotplayer.TeamingPlayers > 0 then
		ply:PrintMessage(HUD_PRINTTALK, gotplayer:Nick() .. " already has a team")
		return
	end
	
	if #ply.REQUESTINFO > 2 then
		ply:PrintMessage(HUD_PRINTTALK, "You can only invite 3 people.")
		return
	end
	for k,v in pairs(ply.TeamingPlayers) do
		if IsValid(player.GetBySteamID64( v )) == false then
			table.RemoveByValue(ply.TeamingPlayers, v)
			print(v .. " was nil, deleting")
		end
	end
	if #ply.TeamingPlayers > 2 then
		ply:PrintMessage(HUD_PRINTTALK, "You can not have any more teammates")
		return
	end
	for k,v in pairs(gotplayer.TeamingPlayers) do
		if IsValid(player.GetBySteamID64( v )) == false then
			table.RemoveByValue(gotplayer.TeamingPlayers, v)
			print(v .. " was nil, deleting")
		end
	end
	net.Start( "SendTeamRequestBack" )
		net.WriteString(ply:Nick())
	net.Send(gotplayer)
	gotplayer.sentteaming = ply:SteamID64()
	table.ForceInsert(ply.REQUESTINFO, {
		requestedlast = CurTime() + 15,
		requestedplayer = gotplayer
	})
	print(ply:Nick() .. "'s request sent to " .. gotplayer:Nick())
end)

net.Receive( "SendClassC", function( len, ply )
	local name = net.ReadString()
	for k,v in pairs(player.GetAll()) do
		if v:Nick() == name then
			net.Start( "SendClassS" )
				net.WriteString( tostring(v:GetLevel()) )
			net.Send(ply)
			return
		end
	end
end )

net.Receive( "ChangeClass", function( len, ply )
	ply:ChangeClass(net.ReadString())
end)

cantdropweapons = {
	"weapon_crowbar",
	"weapon_molotov_c",
	"cw_extrema_ratio_official",
	"weapon_stunstick",
	"sg_medkit_fix",
	"sg_adrenaline_fix"
}

function intab(val, tab)
	for k,v in pairs(tab) do
		if v == val then
			return true
		end
	end
	return false
end

net.Receive( "DropWeapon", function( len, ply )
	local wep = ply:GetActiveWeapon()
	if IsValid(wep) && wep != nil then
		if wep:GetClass() == nil then return end
		if intab(wep:GetClass(), cantdropweapons) == false then
			local ent = ents.Create( wep:GetClass() )
			if IsValid( ent ) then
				ent:Spawn()
				ent:SetPos(ply:GetShootPos() + ply:GetAimVector() * 10)
				ent:SetAngles( ply:EyeAngles() )
				
				ent:PhysWake()
				local phys = ent:GetPhysicsObject()
				if IsValid(phys) then
					phys:SetVelocity(ply:GetVelocity() + ply:GetAimVector() * 500)
				end
				
				ent:SetClip1(wep:Clip1())
				ent.kanadelootable = true
			end
			ply:StripWeapon(wep:GetClass())
			ply:ConCommand( "lastinv" )
		end
	end
end )

TEAM_PLAYER = 1
TEAM_CONT = 2
TEAM_SPEC = 3

STATE_NONE = 1
STATE_PREPARING = 2
STATE_LIVE = 3
STATE_POST = 4
 
if MAPCONFIG[game.GetMap()] == nil then
	Error("ERROR: This map is not compatible with Last Stand")
end

InitialSpawns = {}

DonatorList = {
	{"76561198098529139", Color(255,255,0)},
	{"76561198046774227", Color(0,255,0)},
	{"76561198156389563", Color(242,20,70)},
	{"76561198124708739", Color(0,255,242)}
}

function RegenerateSpawns()
	local allspawns = {}
	table.Add(allspawns, MAPCONFIG[game.GetMap()]["initialspawns"])
	InitialSpawns = allspawns
end

RegenerateSpawns()

function mayme()
	print("team.numplayers : players: " .. team.NumPlayers(TEAM_PLAYER) .. " teamnum : " .. teamnum(TEAM_PLAYER))
	print("team.numplayers : contestants: " .. team.NumPlayers(TEAM_CONT) .. " teamnum : " .. teamnum(TEAM_CONT))
	print("team.numplayers : spectators: " .. team.NumPlayers(TEAM_SPEC) .. " teamnum : " .. teamnum(TEAM_SPEC))
end

function teamnum(num)
	local tab = {}
	for k,v in pairs(team.GetPlayers(num)) do
		if v:Alive() == true then
			table.ForceInsert(tab, v)
		end
	end
	local ret = #tab
	return ret
end

function GM:PlayerInitialSpawn( ply )
	ply.Premium = false
	for k,v in pairs(DonatorList) do
		if v[1] == ply:SteamID64() then
			ply.Premium = true
			print(ply:Nick() .. " is a premium member")
		end
	end
	if ply.Premium == false then print(ply:Nick() .. " is not a premium member") end
	ply.class = "class_default"
	ply.requestedteaming = 0
	ply.sentteaming = nil
	ply.REQUESTINFO = {}
	ply.TeamingPlayers = {}
	ply.wantstoleave = {}
	player_manager.SetPlayerClass( ply, ply.class )
	ply.shouldchangeclass = true
	if GetState() == STATE_LIVE then
		ply.goingtobespec = true
		ply.goingtowait = false
	else
		ply.goingtobespec = false
		ply.goingtowait = true
	end
end

function GetPlayersClasses()
	local tab = {}
	for k,v in pairs(team.GetPlayers(2)) do
		table.ForceInsert(tab, {baseclass.Get( v.class )["DisplayName"], v:GetLevel()})
	end
	return tab
end

function GM:PlayerAuthed( ply, steamid, uniqueid )
	local st = GetState()
	if st == STATE_LIVE then
		ply:PrintMessage(HUD_PRINTTALK, "Game is currently live, wait for the next round to play.")
	elseif st == STATE_NONE then
		ply:PrintMessage(HUD_PRINTTALK, "Not enough players to start the round")
	end
end

function GM:PlayerSpawn(ply)
	ply:AllowFlashlight( false )
	ply:SetupHands()
	if ply.goingtobespec then
		ply.goingtobespec = false
		ply:SetSpectator()
		return
	end
	if ply.goingtowait then
		local spawn = table.Random(InitialSpawns)
		if spawn == nil then
			RegenerateSpawns()
			spawn = table.Random(InitialSpawns)
		end
		ply:SetWaitingPly()
		print(spawn)
		ply:SetPos(spawn)
		table.RemoveByValue(InitialSpawns, spawn)
		return
	end
end

function GM:PlayerSetHandsModel( ply, ent )
	local simplemodel = player_manager.TranslateToPlayerModelName( ply:GetModel() )
	local info = player_manager.TranslatePlayerHands( simplemodel )
	if ( info ) then
		ent:SetModel( info.model )
		ent:SetSkin( info.skin )
		ent:SetBodyGroups( info.body )
	end
end
function playerdeath( victim, inflictor, attacker )
	if GetState() != STATE_LIVE then
		victim.nextspawn = CurTime() + 10
		victim.goingtobespec = true
		return
	end
	victim.nextspawn = CurTime() + 10
	victim.goingtobespec = true
	if victim:Team() == TEAM_CONT then
		victim:SetTeam(TEAM_SPEC)
		local num = team.NumPlayers(TEAM_CONT)
		if num == 1 then
			local ply = team.GetPlayers(TEAM_CONT)[1]
			PrintMessage(HUD_PRINTTALK, victim:Nick() .. " died! " .. ply:Nick() .. " is the winner!" )
			ply:AddFrags(5)
			local exp = 30 * EXPScale()
			if ply.roundkills >= 5 then
				ply:SetEXP( ply:GetEXP() + (exp * 4) )
				ply:LevelUpdate()
				ply:PlayerMsg(Color(255,255,0), "You have earned " .. (exp * 4) .. " exp for winning the round with bonus for 5 or more kills!")
			else
				ply:SetEXP(ply:GetEXP() + (exp * 2.5))
				ply:LevelUpdate()
				ply:PlayerMsg(Color(255,255,0), "You have earned " .. (exp * 2.5) .. " exp for winning the round!")
			end
			player_manager.RunClass( ply, "SaveStats" )
			net.Start("LST_RoundEnd")
			net.Broadcast()
			ply:PrintMessage(HUD_PRINTCENTER, "You won!")
			victim.nextspawn = math.huge
			SetState(STATE_POST)
			timer.Create("timer_postround", PostTime(), 1, function()
				RegenerateSpawns()
				game.CleanUpMap()
				for k,v in pairs(player.GetAll()) do
					local spawn = table.Random(InitialSpawns)
					v:Spawn()
					v:SetWaitingPly()
					if spawn != nil then 
						v:SetPos(spawn)
						table.RemoveByValue(InitialSpawns, spawn)
					end
				end
				SetState(STATE_NONE)
			end)
		elseif num == 2 then
			local ply1 = team.GetPlayers(TEAM_CONT)[1]
			local ply2 = team.GetPlayers(TEAM_CONT)[2]
			if IsInTeam(ply1, ply2) then
				PrintMessage(HUD_PRINTTALK, ply1:Nick() .. " and " .. ply2:Nick() .. " won!" )
				net.Start("LST_RoundEnd")
				net.Broadcast()
				SetState(STATE_POST)
				timer.Create("timer_postround", PostTime(), 1, function()
					RegenerateSpawns()
					game.CleanUpMap()
					for k,v in pairs(player.GetAll()) do
						local spawn = table.Random(InitialSpawns)
						v:Spawn()
						v:SetWaitingPly()
						if spawn != nil then
							v:SetPos(spawn)
							table.RemoveByValue(InitialSpawns, spawn)
						end
					end
					SetState(STATE_NONE)
				end)
			else
				PrintMessage(HUD_PRINTTALK, victim:Nick() .. " died! " .. ply1:Nick() .. " versus " .. ply2:Nick() )
			end
			
		elseif num == 3 then
			local ply1 = team.GetPlayers(TEAM_CONT)[1]
			local ply2 = team.GetPlayers(TEAM_CONT)[2]
			local ply3 = team.GetPlayers(TEAM_CONT)[3]
			if IsInTeam3(ply1, ply2, ply3) then
				PrintMessage(HUD_PRINTTALK, ply1:Nick() .. ", " .. ply2:Nick() .. " and " .. ply3:Nick() .. " won!" )
				net.Start("LST_RoundEnd")
				net.Broadcast()
				SetState(STATE_POST)
				timer.Create("timer_postround", PostTime(), 1, function()
					RegenerateSpawns()
					game.CleanUpMap()
					for k,v in pairs(player.GetAll()) do
						local spawn = table.Random(InitialSpawns)
						v:Spawn()
						v:SetWaitingPly()
						if spawn != nil then 
							v:SetPos(spawn)
							table.RemoveByValue(InitialSpawns, spawn)
						end
					end
					SetState(STATE_NONE)
				end)
			else
				PrintMessage(HUD_PRINTTALK, victim:Nick() .. " died! " .. #team.GetPlayers(TEAM_CONT) .. " players left." )
			end
		else
			PrintMessage(HUD_PRINTTALK, victim:Nick() .. " died! " .. #team.GetPlayers(TEAM_CONT) .. " players left." )
		end
		victim:PrintMessage(HUD_PRINTTALK, "You will spawn as spectator in 10 seconds.")
		victim.goingtobespec = true
		victim.goingtowait = false
		if #victim:GetWeapons() > 0 then
			local pos = victim:GetPos()
			for k,v in pairs(victim:GetWeapons()) do
				local wep = ents.Create( v:GetClass() )
				if IsValid( wep ) then
					wep:SetPos( pos )
					wep:Spawn()
					wep:SetClip1(v:Clip1())
				end
			end
		end
	end
	if attacker:IsPlayer() then
		if victim:Team() == TEAM_SPEC and attacker:Team() == TEAM_CONT then
			local exp = ( 25 + (victim:GetLevel() * 2) ) * EXPScale()
			local hitgroup = victim:LastHitGroup()
			if hitgroup == HITGROUP_HEAD then
				exp = exp * 1.5
				attacker:PlayerMsg(Color(255,255,0), "You have earned " .. math.Round(exp) .. " exp for killing " .. victim:Nick() .. " with headshot bonus!")
			else
				attacker:PlayerMsg(Color(255,255,0), "You have earned " .. exp .. " exp for killing " .. victim:Nick())
			end
			attacker.roundkills = attacker.roundkills + 1
			exp = math.Round(exp)
			attacker:SetEXP(attacker:GetEXP() + exp)
			attacker:LevelUpdate()
			player_manager.RunClass( attacker, "SaveStats" )
			attacker:PrintMessage(HUD_PRINTCENTER, "You have earned " .. exp .. " exp! Your current exp: " .. attacker:GetEXP())
		end
	end
end
hook.Add("PlayerDeath", "playerdeathhook", playerdeath)

function deaththink( ply )
	if (CurTime() >= ply.nextspawn) then
		ply:Spawn()
		ply.nextspawn = math.huge
	end
end
hook.Add("PlayerDeathThink", "playerdeaththinkhook", deaththink)

function ResetGame()
	print("reseting game")
	SetState(STATE_POST)
	timer.Create("timer_postround", PostTime(), 1, function()
		game.CleanUpMap()
		RegenerateSpawns()
		for k,v in pairs(player.GetAll()) do
			local spawn = table.Random(InitialSpawns)
			v:Spawn()
			v:SetWaitingPly()
			if spawn != nil then 
				v:SetPos(spawn)
				table.RemoveByValue(InitialSpawns, spawn)
			end
		end
		SetState(STATE_NONE)
	end)
end

function GM:PlayerDisconnected( ply )
	for k,v in pairs(ply.TeamingPlayers) do
		local pl = player.GetBySteamID64( v )
		if pl != false then
			for k1,plyr in pairs(pl.TeamingPlayers) do
				if plyr == ply:SteamID64() then
					table.RemoveByValue(pl.TeamingPlayers, plyr)
					print(pl:Nick() .. "debug pldisc")
					pl:UpdateTeamers()
				end
			end
		end
	end
	ply.TeamingPlayers = {}
	player_manager.RunClass( ply, "SaveStats" )
	if GetState() != STATE_LIVE then return end
	local pls = 0
	for k,v in pairs(player.GetAll()) do
		if v != ply then
			if v:Team() == TEAM_CONT then
				pls = pls + 1
			end
		end
	end
	if pls == 1 then
		local winner = team.GetPlayers(TEAM_CONT)[1]
		winner:PrintMessage(HUD_PRINTTALK, ply:Nick() .. " disconnected, " .. winner:Nick() .. " won!." )
		net.Start("LST_RoundEnd")
		net.Broadcast()
		ResetGame()
	elseif pls == 0 then
		ResetGame()
	end
end

function GM:CanPlayerSuicide( ply )
	return false
end


function GM:PlayerUse( ply, item )
	if ply:Team() == TEAM_CONT then
		return true
	else
		return false
	end
end

function GM:AllowPlayerPickup( ply, ent )
	if ply:Team() == TEAM_CONT then
		return true
	else
		return false
	end
end

function GM:PlayerCanPickupWeapon( ply, wep )
	if ply:Team() == TEAM_CONT then
		if wep.kanadelootable == true then
			if ply:KeyDown(IN_USE) then
				return true
			end
		else
			return true
		end
	end
	return false
end

function GM:PlayerCanPickupItem( ply, item )
	if ply:Team() == TEAM_CONT then
		return true
	else
		return false
	end
end

function GM:PlayerShouldTakeDamage( victim, pl )
	if victim == pl then return true end
	if pl:IsPlayer() and victim:IsPlayer() then
		if canattack == false then
			return false
		else
			if IsInTeam(victim, pl) then
				return false
			else
				return true
			end
		end
	end
	return true
end

function GM:IsSpawnpointSuitable( ply, spawnpointent, bMakeSuitable )

	local Pos = spawnpointent:GetPos()

	-- Note that we're searching the default hull size here for a player in the way of our spawning.
	-- This seems pretty rough, seeing as our player's hull could be different.. but it should do the job
	-- ( HL2DM kills everything within a 128 unit radius )
	local Ents = ents.FindInBox( Pos + Vector( -16, -16, 0 ), Pos + Vector( 16, 16, 72 ) )

	if ( ply:Team() == TEAM_SPECTATOR or ply:Team() == TEAM_UNASSIGNED ) then return true end

	local Blockers = 0

	for k, v in pairs( Ents ) do
		if ( IsValid( v ) && v:GetClass() == "player" && v:Alive() ) then

			Blockers = Blockers + 1

		end
	end

	if ( bMakeSuitable ) then return true end
	if ( Blockers > 0 ) then return false end
	return true

end
