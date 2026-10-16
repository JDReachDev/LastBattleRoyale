// Shared file, for clients and server

include( "classes.lua" )

for k,v in pairs(CLASSES) do
	local cls = "player_class/" .. v["class"] .. ".lua"
	include(cls)
end

GM.Name 	= "Last Battle Royale"
GM.Author 	= "DarkReach"
GM.Email 	= "Steam"
GM.Website 	= ""

function GM:Initialize()
	self.BaseClass.Initialize( self )
end

TEAM_PLAYER = 1
TEAM_CONT = 2
TEAM_SPEC = 3

STATE_NONE = 1
STATE_PREPARING = 2
STATE_LIVE = 3
STATE_POST = 4

// Team setup
team.SetUp( TEAM_PLAYER,"Players",		Color( 165, 165, 89 ) )
team.SetUp( TEAM_CONT,	"Contestants",	Color( 89, 165, 127 ) )
team.SetUp( TEAM_SPEC,	"Spectators",	Color( 255, 255, 255 ) )

if !ConVarExists("lst_minimumplayers") then CreateConVar( "lst_minimumplayers", "2", FCVAR_NOTIFY, "Set minimum players" ) end
if !ConVarExists("lst_time_actionpreparing") then CreateConVar( "lst_time_actionpreparing", "60", FCVAR_NOTIFY, "Set action preparing time" ) end
if !ConVarExists("lst_time_preparing") then CreateConVar( "lst_time_preparing", "15", FCVAR_NOTIFY, "Set preparing time" ) end
if !ConVarExists("lst_time_postround") then CreateConVar( "lst_time_postround", "15", FCVAR_NOTIFY, "Set post time" ) end
if !ConVarExists("lst_zonespeed") then CreateConVar( "lst_zonespeed", "1", FCVAR_NOTIFY, "Set zone speed" ) end
if !ConVarExists("lst_healhealth") then CreateConVar( "lst_healhealth", "1", FCVAR_NOTIFY, "Heal players health after 5 seconds" ) end
if !ConVarExists("lst_event_enablenuke") then CreateConVar( "lst_event_enablenuke", "1", FCVAR_NOTIFY, "Enable nuke event" ) end
if !ConVarExists("lst_enableimplosion") then CreateConVar( "lst_enableimplosion", "1", FCVAR_NOTIFY, "Enable implosion bomb at the end" ) end
if !ConVarExists("lst_usecssarmor") then CreateConVar( "lst_usecssarmor", "1", FCVAR_NOTIFY, "If you dont have CS:Source installed then turn it to 0" ) end
if !ConVarExists("lst_expscale") then CreateConVar( "lst_expscale", "1", FCVAR_NOTIFY, "Set EXP scale" ) end
if !ConVarExists("lst_levelexp") then CreateConVar( "lst_levelexp", "25", FCVAR_NOTIFY, "Set def level exp" ) end
if !ConVarExists("lst_zonequality") then CreateConVar( "lst_zonequality", "3", FCVAR_NOTIFY, "3)high+texture 2)medium 1)low 0)invisible" ) end
if !ConVarExists("lst_objoutline") then CreateConVar( "lst_objoutline", "1", FCVAR_NOTIFY, "0 no, 1 yes" ) end

function ActionPrepTime()
	return GetConVar("lst_time_actionpreparing"):GetInt()
end

function PrepTime()
	return GetConVar("lst_time_preparing"):GetInt()
end

function PostTime()
	return GetConVar("lst_time_postround"):GetInt()
end

function MinPlayers()
	return GetConVar("lst_minimumplayers"):GetInt()
end

function EXPScale()
	return GetConVar("lst_expscale"):GetInt()
end

function LevelEXP()
	return GetConVar("lst_levelexp"):GetInt()
end

function GetGMWalkSpeed()
	return 190
end

function GetGMRunSpeed()
	return 265
end

function GetGMJumpPower()
	return 200
end

function GM:CanPlayerEnterVehicle( ply, vehicle, sRole )
	if ply:Team() == TEAM_CONT then
		return true
	else
		return false
	end
end

/*
Made by Mors Quaedam
https://facepunch.com/showthread.php?t=1382862&p=44459973&viewfull=1#post44459973
*/
if SERVER then
	local PLAYER = FindMetaTable("Player")
	util.AddNetworkString( "ColoredMessage" )
	function BroadcastMsg(...)
		local args = {...}
		net.Start("ColoredMessage")
		net.WriteTable(args)
		net.Broadcast()
	end
	function PLAYER:PlayerMsg(...)
		local args = {...}
		net.Start("ColoredMessage")
		net.WriteTable(args)
		net.Send(self)
	end
elseif CLIENT then
	net.Receive("ColoredMessage",function(len) 
		local msg = net.ReadTable()
		chat.AddText(unpack(msg))
		chat.PlaySound()
	end)
end
