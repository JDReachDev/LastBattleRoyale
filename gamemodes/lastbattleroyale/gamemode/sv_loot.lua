// Loot / vehicle tables from data/lastbattleroyale/loot.txt (see sh_loot.lua).
// Included after config.lua: the config.lua tables are kept as the defaults.
// No file = nothing changes.

util.AddNetworkString( "LBR_Loot_Get" )
util.AddNetworkString( "LBR_Loot_Data" )
util.AddNetworkString( "LBR_Loot_Save" )
util.AddNetworkString( "LBR_Loot_Reset" )

LBR.LootDefaults = LBR.LootDefaults or LBR.LootFromTables( ITEMS, VEHICLES, FLYING_VEHICLES )
LBR.LootSource = "default"

// Rebuild the lists used by sv_round.lua
function LBR.ApplyLoot( groups )
	ITEMS = ITEMS or {}
	ITEMS.BETTERWEAPONS     = LBR.LootExpand( groups.BETTERWEAPONS )
	ITEMS.WEAPONS           = LBR.LootExpand( groups.WEAPONS )
	ITEMS.ADDITIONALWEAPONS = LBR.LootExpand( groups.ADDITIONALWEAPONS )
	ITEMS.ITEMS             = LBR.LootExpand( groups.ITEMS )
	ITEMS.AMMO              = LBR.LootExpand( groups.AMMO )
	ITEMS.ATTACHMENTS       = LBR.LootExpand( groups.ATTACHMENTS )
	VEHICLES                = LBR.LootExpand( groups.CARS )
	FLYING_VEHICLES = FLYING_VEHICLES or {}
	FLYING_VEHICLES.RARE     = LBR.LootExpand( groups.HELI_RARE )
	FLYING_VEHICLES.VERYRARE = LBR.LootExpand( groups.HELI_VERYRARE )
	// extra ammo given on pickup, per weapon class
	LBR.LootAmmo = {}
	for _, list in pairs( groups ) do
		for _, e in ipairs( list ) do
			if ( e.ammo or 0 ) > 0 then LBR.LootAmmo[e.class] = e.ammo end
		end
	end
	LBR.LootCurrent = groups
end

function LBR.LoadLoot()
	if file.Exists( LBR.LootFile, "DATA" ) then
		local groups, err = LBR.LootFromJSON( file.Read( LBR.LootFile, "DATA" ) )
		if groups then
			LBR.ApplyLoot( groups )
			LBR.LootSource = "file"
			print( "[LBR] Loot tables loaded from data/" .. LBR.LootFile )
			return
		end
		print( "[LBR] data/" .. LBR.LootFile .. " is not valid (" .. tostring( err ) .. "), using the config.lua loot" )
	end
	LBR.ApplyLoot( table.Copy( LBR.LootDefaults ) )
	LBR.LootSource = "default"
end

LBR.LoadLoot()

------------------------------------------------------------------------
// Editor panel
------------------------------------------------------------------------

local function canEdit( ply )
	return IsValid( ply ) and ply.LBR_Editing and LBR.CanEdit and LBR.CanEdit( ply )
end

local function lootMsg( ply, ok, msg )
	net.Start( "LBR_Editor_Msg" )
		net.WriteBool( ok )
		net.WriteString( msg )
	net.Send( ply )
end

local function sendLoot( ply )
	local data = util.Compress( LBR.LootToJSON( LBR.LootCurrent or LBR.LootDefaults ) )
	if not data or #data > 60000 then
		lootMsg( ply, false, "Loot config too big to send" )
		return
	end
	net.Start( "LBR_Loot_Data" )
		net.WriteString( LBR.LootSource )
		net.WriteUInt( #data, 16 )
		net.WriteData( data, #data )
	net.Send( ply )
end

local function throttle( ply )
	if ( ply.LBR_NextLootNet or 0 ) > CurTime() then return true end
	ply.LBR_NextLootNet = CurTime() + 0.5
	return false
end

net.Receive( "LBR_Loot_Get", function( len, ply )
	if not canEdit( ply ) or throttle( ply ) then return end
	sendLoot( ply )
end )

net.Receive( "LBR_Loot_Save", function( len, ply )
	if not canEdit( ply ) or throttle( ply ) then return end
	local size = net.ReadUInt( 16 )
	local json = util.Decompress( net.ReadData( size ), 1024 * 1024 )
	local groups, err = LBR.LootFromJSON( json )
	if not groups then
		lootMsg( ply, false, "Loot not saved: " .. tostring( err ) )
		return
	end

	file.CreateDir( "lastbattleroyale" )
	file.Write( LBR.LootFile, LBR.LootToJSON( groups ) )
	if not file.Exists( LBR.LootFile, "DATA" ) then
		lootMsg( ply, false, "Loot not saved: could not write data/" .. LBR.LootFile )
		return
	end

	LBR.ApplyLoot( groups )
	LBR.LootSource = "file"
	print( "[LBR] " .. ply:Nick() .. " saved the loot tables to data/" .. LBR.LootFile )
	lootMsg( ply, true, "Loot tables written to data/" .. LBR.LootFile .. " (used from the next round)" )
	sendLoot( ply )
end )

net.Receive( "LBR_Loot_Reset", function( len, ply )
	if not canEdit( ply ) or throttle( ply ) then return end
	if file.Exists( LBR.LootFile, "DATA" ) then file.Delete( LBR.LootFile ) end
	LBR.LoadLoot()
	print( "[LBR] " .. ply:Nick() .. " reset the loot tables to config.lua" )
	lootMsg( ply, true, "Loot tables reset to the config.lua defaults (used from the next round)" )
	sendLoot( ply )
end )

concommand.Add( "lbr_loot_reload", function( ply )
	if IsValid( ply ) and not ply:IsSuperAdmin() then return end
	LBR.LoadLoot()
	local msg = "[LBR] Loot tables reloaded (" .. LBR.LootSource .. ")"
	if IsValid( ply ) then LBR.Chat( ply, msg ) else print( msg ) end
end )
