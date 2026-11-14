// Shared file, for clients and server

include( "classes.lua" )
include( "sh_mapconfig.lua" )
include( "sh_zone.lua" )
include( "sh_spawn.lua" )
include( "sh_tiers.lua" ) // weapon tiers: colors, tier ammo
include( "sh_loot.lua" )
include( "sh_notify.lua" )
include( "sh_inventory.lua" )
include( "sh_clips.lua" ) // ammo: magazines by color
include( "sh_profile.lua" ) // lbr_profile: what makes the game stutter

for k,v in pairs(CLASSES) do
	local cls = "player_class/" .. v["class"] .. ".lua"
	include(cls)
end
include( "sh_classcfg.lua" ) // classes.txt: class stats, loadout, unlock (F8 editor)

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

// ConVars. They were called lst_* (from Last Stand): now lbr_*.
// The old names still work: setting lst_zonespeed (server.cfg, console, command line)
// sets lbr_zone_speed, so old configs keep working.
LBR = LBR or {}
LBR.ConVars = {
	// { new name, old name, default, help, per player }
	{ "lbr_min_players", "lst_minimumplayers", "2", "Players needed to start a round" },
	{ "lbr_time_preparing", "lst_time_preparing", "30", "Seconds in the lobby before the match starts" },
	{ "lbr_time_weapons_hot", "lst_time_actionpreparing", "30", "Seconds after the start before players can attack" },
	{ "lbr_time_postround", "lst_time_postround", "15", "Seconds before going back to the lobby" },
	{ "lbr_zone_speed", "lst_zonespeed", "0.75", "Zone radius removed every tick" },
	{ "lbr_zone_delay", "lst_zonedelay", "60", "Seconds after the start before the zone starts shrinking (a map can set its own)" },
	{ "lbr_zone_heal", "lst_healhealth", "1", "Health regenerates up to 20 inside the zone" },
	{ "lbr_css_armor", "lst_usecssarmor", "1", "Use CS:S models for armor (needs CS:S mounted)" },
	{ "lbr_event_nuke", "lst_event_enablenuke", "0", "Random nuclear strike during the match" },
	{ "lbr_event_implosion", "lst_enableimplosion", "0", "Implosion bomb when the zone closes" },
	{ "lbr_exp_scale", "lst_expscale", "1", "EXP multiplier" },
	{ "lbr_level_exp", "lst_levelexp", "25", "EXP for the next level = next level x this" },
	{ "lbr_zone_quality", "lst_zonequality", "3", "3 high, 2 medium, 1 low, 0 invisible", true },
	{ "lbr_outline", "lst_objoutline", "1", "Outline on loot", true },
}

for _, c in ipairs( LBR.ConVars ) do
	local name, old, def, help, perPlayer = c[1], c[2], c[3], c[4], c[5]
	// the Start New Game menu (lastbattleroyale.txt) may have created it already
	if not ConVarExists( name ) then
		local flags = perPlayer and { FCVAR_ARCHIVE } or { FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED }
		CreateConVar( name, def, flags, help )
	end
	if not ConVarExists( old ) then
		CreateConVar( old, def, perPlayer and 0 or FCVAR_NOTIFY, "Old name of " .. name )
	end
	if SERVER or perPlayer then
		// old value set before this file ran (command line, menu of an old version)
		local o = GetConVar( old )
		if o and o:GetString() ~= def then RunConsoleCommand( name, o:GetString() ) end
		cvars.AddChangeCallback( old, function( _, _, new )
			RunConsoleCommand( name, new )
		end, "LBR_OldName" )
	end
end

function ActionPrepTime()
	return GetConVar("lbr_time_weapons_hot"):GetInt()
end

function PrepTime()
	return GetConVar("lbr_time_preparing"):GetInt()
end

function PostTime()
	return GetConVar("lbr_time_postround"):GetInt()
end

function MinPlayers()
	return GetConVar("lbr_min_players"):GetInt()
end

function EXPScale()
	return GetConVar("lbr_exp_scale"):GetFloat() // 0.5, 1.5... work too
end

function LevelEXP()
	return GetConVar("lbr_level_exp"):GetInt()
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
		chat.AddText( LBR.MsgColors.info, "[LBR] ", unpack( msg ) )
		chat.PlaySound()
	end)
end
