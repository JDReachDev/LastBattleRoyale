// Server side map configuration: loading map files and the in-game map editor.
//
// Every map config lives in a text file (JSON inside):
//     garrysmod/data/lastbattleroyale/maps/<map>.txt
//
// - On startup every built-in map of config.lua (MAPCONFIG) is exported to that folder,
//   only if its file does not exist yet, so the existing configs are never lost.
// - The game always plays the .txt file: edit it with the in-game editor (F8) or by hand,
//   or drop in a file made by someone else.
// - Delete a .txt (or use "Reset" in the editor) to get the original built-in config back.
// - Addons can ship files in data_static/lastbattleroyale/maps/<map>.txt too.

LBR = LBR or {}

util.AddNetworkString( "LBR_Editor_Open" )
util.AddNetworkString( "LBR_Editor_Close" )
util.AddNetworkString( "LBR_Editor_Save" )
util.AddNetworkString( "LBR_Editor_Reload" )
util.AddNetworkString( "LBR_Editor_Delete" )
util.AddNetworkString( "LBR_Editor_Goto" )
util.AddNetworkString( "LBR_Editor_Msg" )
util.AddNetworkString( "LBR_Editor_Toggle" )

local cvSuperOnly = CreateConVar( "lbr_editor_superadminonly", "0", FCVAR_ARCHIVE, "1 = only superadmins can use the map editor, 0 = admins too" )

LBR.MapSource = LBR.MapSource or "none" // "file", "builtin" or "none"
LBR.MapReady = LBR.MapReady or false
LBR.Editors = LBR.Editors or {}

MAPCONFIG = MAPCONFIG or {}

function LBR.GetMapConfig()
	return MAPCONFIG[game.GetMap()]
end

function LBR.RefreshMapState()
	local errors = LBR.ValidateMapConfig( LBR.GetMapConfig() )
	LBR.MapReady = #errors == 0
	SetGlobalBool( "LBR_MapReady", LBR.MapReady )
	if LBR.UpdateMapBounds then LBR.UpdateMapBounds() end // map area for the M map (sv_map.lua)
	return errors
end

function LBR.IsMapReady()
	return LBR.MapReady
end

// Built-in configs from config.lua (MAPCONFIG is rebuilt every time config.lua is included)
LBR.BuiltinMaps = {}
for map, cfg in pairs( MAPCONFIG ) do
	if istable( cfg ) then LBR.BuiltinMaps[string.lower( map )] = cfg end
end

function LBR.ExportBuiltinMap( map, force )
	local raw = LBR.BuiltinMaps[string.lower( map )]
	if not raw then return false end
	local path = LBR.MapFileName( map )
	if not force and file.Exists( path, "DATA" ) then return false end
	local cfg = LBR.SanitizeMapConfig( raw )
	if not cfg then return false end
	file.CreateDir( LBR.MapDataDir )
	file.Write( path, LBR.MapConfigToJSON( cfg, map ) )
	return true
end

function LBR.ExportAllBuiltinMaps()
	local n = 0
	for map in pairs( LBR.BuiltinMaps ) do
		if LBR.ExportBuiltinMap( map ) then n = n + 1 end
	end
	if n > 0 then print( "[LBR] Exported " .. n .. " built-in map configs to data/" .. LBR.MapDataDir .. "/" ) end
end

function LBR.LoadCurrentMapConfig()
	local map = game.GetMap()
	local path = LBR.MapFileName( map )
	LBR.MapSource = "none"
	MAPCONFIG[map] = nil
	LBR.ExportBuiltinMap( map )
	if file.Exists( path, "DATA" ) then
		local cfg, err = LBR.MapConfigFromJSON( file.Read( path, "DATA" ) )
		if cfg then
			MAPCONFIG[map] = cfg
			LBR.MapSource = "file"
			print( "[LBR] Loaded map config from data/" .. path )
		else
			ErrorNoHalt( "[LBR] data/" .. path .. " is broken (" .. tostring( err ) .. "), using built-in config if any\n" )
		end
	end
	if LBR.MapSource ~= "file" and LBR.BuiltinMaps[string.lower( map )] then
		MAPCONFIG[map] = LBR.SanitizeMapConfig( LBR.BuiltinMaps[string.lower( map )] )
		LBR.MapSource = "builtin"
		print( "[LBR] Using built-in map config for " .. map )
	end
	local errors = LBR.RefreshMapState()
	if #errors > 0 then
		print( "[LBR] Map " .. map .. " is not playable yet: " .. table.concat( errors, ", " ) )
		print( "[LBR] An admin can press F8 (or run lbr_editor) to configure it." )
	end
end

LBR.ExportAllBuiltinMaps()
LBR.LoadCurrentMapConfig()

concommand.Add( "lbr_map_reload", function( ply )
	if IsValid( ply ) and not ply:IsSuperAdmin() then return end
	LBR.LoadCurrentMapConfig()
	if RegenerateSpawns then RegenerateSpawns() end
end )

------------------------------------------------------------------------
// Editor
------------------------------------------------------------------------

function LBR.CanEdit( ply )
	if not IsValid( ply ) then return false end
	if game.SinglePlayer() or ply:IsListenServerHost() then return true end
	if cvSuperOnly:GetBool() then return ply:IsSuperAdmin() end
	return ply:IsAdmin()
end

function LBR.AnyEditing()
	for ply in pairs( LBR.Editors ) do
		if IsValid( ply ) and ply.LBR_Editing then return true end
		LBR.Editors[ply] = nil
	end
	return false
end

local function editorMsg( ply, ok, msg )
	net.Start( "LBR_Editor_Msg" )
		net.WriteBool( ok )
		net.WriteString( msg )
	net.Send( ply )
end

local function sendConfig( ply )
	local cfg = LBR.GetMapConfig() or LBR.NewMapConfig()
	local data = util.Compress( LBR.MapConfigToJSON( cfg ) )
	if not data or #data > 60000 then
		editorMsg( ply, false, "Map config too big to send" )
		return false
	end
	net.Start( "LBR_Editor_Open" )
		net.WriteString( LBR.MapSource )
		net.WriteUInt( #data, 16 )
		net.WriteData( data, #data )
	net.Send( ply )
	return true
end

local function applyEditMode( ply )
	if not IsValid( ply ) or not ply.LBR_Editing then return end
	if not ply:Alive() then ply:Spawn() end
	ply:SetMoveType( MOVETYPE_NOCLIP )
	ply:GodEnable()
end

function LBR.OpenEditor( ply )
	if not LBR.CanEdit( ply ) then
		LBR.Chat( ply, "Only admins can use the map editor.", "bad" )
		return
	end
	local st = GetState()
	if st == STATE_LIVE or st == STATE_PREPARING then
		LBR.Chat( ply, "The map editor can be opened only between rounds.", "bad" )
		return
	end
	if not sendConfig( ply ) then return end
	ply.LBR_Editing = true
	LBR.Editors[ply] = true
	applyEditMode( ply )
	print( "[LBR] " .. ply:Nick() .. " opened the map editor" )
end

function LBR.CloseEditor( ply )
	if not IsValid( ply ) then return end
	local was = ply.LBR_Editing
	ply.LBR_Editing = nil
	LBR.Editors[ply] = nil
	if was then
		if ply:GetMoveType() == MOVETYPE_NOCLIP then ply:SetMoveType( MOVETYPE_WALK ) end
		net.Start( "LBR_Editor_Close" )
		net.Send( ply )
		// put the player back in the lobby
		if GetState() == STATE_NONE or GetState() == STATE_POST then
			ply.goingtowait = true
			ply.goingtobespec = false
			ply:Spawn()
		end
	end
end

function LBR.ToggleEditor( ply )
	if ply.LBR_Editing then LBR.CloseEditor( ply ) else LBR.OpenEditor( ply ) end
end

concommand.Add( "lbr_editor", function( ply )
	if IsValid( ply ) then LBR.ToggleEditor( ply ) end
end )

// F8 is detected on the client (cl_editor.lua), which sends this message
net.Receive( "LBR_Editor_Toggle", function( len, ply )
	if ( ply.LBR_NextToggle or 0 ) > CurTime() then return end
	ply.LBR_NextToggle = CurTime() + 0.5
	LBR.ToggleEditor( ply )
end )

hook.Add( "PlayerNoClip", "LBR_EditorNoclip", function( ply, desired )
	if ply.LBR_Editing then return true end
end )

hook.Add( "PlayerSpawn", "LBR_EditorRespawn", function( ply )
	if ply.LBR_Editing then
		timer.Simple( 0, function() applyEditMode( ply ) end )
	end
end )

hook.Add( "PlayerDisconnected", "LBR_EditorCleanup", function( ply )
	LBR.Editors[ply] = nil
end )

local function canUseEditorNet( ply )
	return IsValid( ply ) and ply.LBR_Editing and LBR.CanEdit( ply )
end

net.Receive( "LBR_Editor_Save", function( len, ply )
	if not canUseEditorNet( ply ) then return end
	if ( ply.LBR_NextSave or 0 ) > CurTime() then
		editorMsg( ply, false, "Wait a second before saving again" )
		return
	end
	ply.LBR_NextSave = CurTime() + 1

	local size = net.ReadUInt( 16 )
	local data = net.ReadData( size )
	local json = util.Decompress( data, 4 * 1024 * 1024 )
	local cfg, err = LBR.MapConfigFromJSON( json )
	if not cfg then
		editorMsg( ply, false, "Save failed: " .. tostring( err ) )
		return
	end

	local map = game.GetMap()
	file.CreateDir( LBR.MapDataDir )
	file.Write( LBR.MapFileName( map ), LBR.MapConfigToJSON( cfg, map ) )
	if not file.Exists( LBR.MapFileName( map ), "DATA" ) then
		editorMsg( ply, false, "Save failed: could not write data/" .. LBR.MapFileName( map ) )
		return
	end

	MAPCONFIG[map] = cfg
	LBR.MapSource = "file"
	local errors = LBR.RefreshMapState()
	if RegenerateSpawns then RegenerateSpawns() end

	print( "[LBR] " .. ply:Nick() .. " saved the map config to data/" .. LBR.MapFileName( map ) )
	if #errors > 0 then
		editorMsg( ply, true, "Saved to data/" .. LBR.MapFileName( map ) .. " - not playable yet: " .. table.concat( errors, ", " ) )
	else
		editorMsg( ply, true, "Saved to data/" .. LBR.MapFileName( map ) .. " - map is playable!" )
	end
end )

net.Receive( "LBR_Editor_Reload", function( len, ply )
	if not canUseEditorNet( ply ) then return end
	LBR.LoadCurrentMapConfig()
	sendConfig( ply )
	editorMsg( ply, true, "Reloaded (" .. LBR.MapSource .. ")" )
end )

net.Receive( "LBR_Editor_Delete", function( len, ply )
	if not canUseEditorNet( ply ) then return end
	local path = LBR.MapFileName()
	if file.Exists( path, "DATA" ) then
		file.Delete( path )
		print( "[LBR] " .. ply:Nick() .. " deleted data/" .. path )
	end
	LBR.LoadCurrentMapConfig()
	sendConfig( ply )
	editorMsg( ply, true, LBR.MapSource == "file" and "Reset to the built-in config" or "Saved file deleted, map is not configured" )
end )

net.Receive( "LBR_Editor_Goto", function( len, ply )
	if not canUseEditorNet( ply ) then return end
	local pos = net.ReadVector()
	if not util.IsInWorld( pos ) then
		pos = pos + Vector( 0, 0, 40 )
	end
	ply:SetMoveType( MOVETYPE_NOCLIP )
	ply:SetPos( pos )
end )
