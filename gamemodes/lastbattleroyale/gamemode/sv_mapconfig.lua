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
util.AddNetworkString( "LBR_Editor_Bounds" )
util.AddNetworkString( "LBR_Editor_Msg" )
util.AddNetworkString( "LBR_Editor_Toggle" )
util.AddNetworkString( "LBR_Editor_Sync" )

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

// Shared editing: every editor works on the same draft, kept here. Each change
// (point added / removed, category cleared, settings, import) goes to the server,
// which applies it to the draft and sends it to the other editors, so everyone
// sees the points of the others live. Save writes the draft; when the last editor
// closes, unsaved changes are dropped.
LBR.EdDraft = LBR.EdDraft or nil
LBR.EdDraftDirty = LBR.EdDraftDirty or false

local function copyConfig( cfg )
	return LBR.MapConfigFromJSON( LBR.MapConfigToJSON( cfg ) ) or LBR.NewMapConfig()
end

local function resetDraft()
	LBR.EdDraft = copyConfig( LBR.GetMapConfig() or LBR.NewMapConfig() )
	LBR.EdDraftDirty = false
end

local function editorList( except )
	local out = {}
	for p in pairs( LBR.Editors ) do
		if IsValid( p ) and p.LBR_Editing and p ~= except then out[#out + 1] = p end
	end
	return out
end

local function sendConfig( ply )
	if not LBR.EdDraft then resetDraft() end
	local data = util.Compress( LBR.MapConfigToJSON( LBR.EdDraft ) )
	if not data or #data > 60000 then
		editorMsg( ply, false, "Map config too big to send" )
		return false
	end
	net.Start( "LBR_Editor_Open" )
		net.WriteString( LBR.MapSource )
		net.WriteBool( LBR.EdDraftDirty )
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
	// first editor: the draft starts from the saved config; the others get the
	// draft as it is now, with the unsaved changes of who is already editing
	if not LBR.AnyEditing() then resetDraft() end
	if not sendConfig( ply ) then return end
	for _, p in ipairs( editorList( ply ) ) do editorMsg( p, true, ply:Nick() .. " joined the map editor" ) end
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
	if not LBR.AnyEditing() then LBR.EdDraft = nil end
	if was then
		for _, p in ipairs( editorList( ply ) ) do editorMsg( p, true, ply:Nick() .. " left the map editor" ) end
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
	ply.LBR_Editing = nil
	LBR.Editors[ply] = nil
	if not LBR.AnyEditing() then LBR.EdDraft = nil end
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

	// the shared draft is saved: it has the changes of every editor
	if not LBR.EdDraft then resetDraft() end
	local cfg = copyConfig( LBR.EdDraft )

	local map = game.GetMap()
	file.CreateDir( LBR.MapDataDir )
	file.Write( LBR.MapFileName( map ), LBR.MapConfigToJSON( cfg, map ) )
	if not file.Exists( LBR.MapFileName( map ), "DATA" ) then
		editorMsg( ply, false, "Save failed: could not write data/" .. LBR.MapFileName( map ) )
		return
	end

	MAPCONFIG[map] = cfg
	LBR.MapSource = "file"
	LBR.EdDraftDirty = false
	local errors = LBR.RefreshMapState()
	if RegenerateSpawns then RegenerateSpawns() end

	print( "[LBR] " .. ply:Nick() .. " saved the map config to data/" .. LBR.MapFileName( map ) )
	local msg = "Saved to data/" .. LBR.MapFileName( map ) .. ( #errors > 0 and ( " - not playable yet: " .. table.concat( errors, ", " ) ) or " - map is playable!" )
	for _, p in ipairs( editorList() ) do
		editorMsg( p, true, p == ply and msg or ( msg .. " (by " .. ply:Nick() .. ")" ) )
	end
end )

// the draft changed for everyone (reload, reset): every editor gets it again
local function resendAll()
	for _, p in ipairs( editorList() ) do sendConfig( p ) end
end

net.Receive( "LBR_Editor_Reload", function( len, ply )
	if not canUseEditorNet( ply ) then return end
	LBR.LoadCurrentMapConfig()
	resetDraft()
	resendAll()
	for _, p in ipairs( editorList() ) do
		editorMsg( p, true, "Reloaded (" .. LBR.MapSource .. ")" .. ( p ~= ply and ( " by " .. ply:Nick() ) or "" ) )
	end
end )

net.Receive( "LBR_Editor_Delete", function( len, ply )
	if not canUseEditorNet( ply ) then return end
	local path = LBR.MapFileName()
	if file.Exists( path, "DATA" ) then
		file.Delete( path )
		print( "[LBR] " .. ply:Nick() .. " deleted data/" .. path )
	end
	LBR.LoadCurrentMapConfig()
	resetDraft()
	resendAll()
	local msg = LBR.MapSource == "file" and "Reset to the built-in config" or "Saved file deleted, map is not configured"
	for _, p in ipairs( editorList() ) do
		editorMsg( p, true, msg .. ( p ~= ply and ( " (by " .. ply:Nick() .. ")" ) or "" ) )
	end
end )

// Live changes of an editor (see cl_editor.lua, ED.Send*):
//   1 add point       cat, x y z, index (0 = at the end)
//   2 remove point    cat, x y z
//   3 category list   cat, count, points (clear / undo of a clear)
//   4 settings        compressed JSON: zone radius, zone delay, loot amounts, player models
//   5 whole config    compressed JSON (import)
local SYNC_ADD, SYNC_REMOVE, SYNC_LIST, SYNC_SETTINGS, SYNC_FULL = 1, 2, 3, 4, 5

local function readPoint()
	local x, y, z = net.ReadFloat(), net.ReadFloat(), net.ReadFloat()
	local function ok( n ) return n == n and n > -1e6 and n < 1e6 end
	if ok( x ) and ok( y ) and ok( z ) then return Vector( x, y, z ) end
end

local function writePoint( v )
	net.WriteFloat( v.x ) net.WriteFloat( v.y ) net.WriteFloat( v.z )
end

local function readJSON()
	local size = net.ReadUInt( 16 )
	local data = net.ReadData( size )
	return util.JSONToTable( util.Decompress( data, 4 * 1024 * 1024 ) or "" )
end

local function writeJSON( tbl )
	local data = util.Compress( util.TableToJSON( tbl ) )
	net.WriteUInt( #data, 16 )
	net.WriteData( data, #data )
end

local function settingsOf( cfg )
	return { zone_radius = cfg.zone_radius, zone_delay = cfg.zone_delay or -1, weaponsc = cfg.weaponsc, playermodels = cfg.playermodels }
end

net.Receive( "LBR_Editor_Sync", function( len, ply )
	if not canUseEditorNet( ply ) then return end
	if not LBR.EdDraft then resetDraft() end
	local draft = LBR.EdDraft
	local kind = net.ReadUInt( 3 )
	local ci, cat, a, b

	if kind == SYNC_ADD or kind == SYNC_REMOVE or kind == SYNC_LIST then
		ci = net.ReadUInt( 4 )
		cat = LBR.MapCategories[ci]
		if not cat then return end
		local l = LBR.GetCategoryList( draft, cat, true )
		if kind == SYNC_ADD then
			a = readPoint()
			b = net.ReadUInt( 12 )
			if not a or #l >= LBR.MaxPointsPerCategory then return end
			if b > 0 and b <= #l then table.insert( l, b, a ) else l[#l + 1] = a b = 0 end
		elseif kind == SYNC_REMOVE then
			a = readPoint()
			if not a then return end
			// the point itself, not its index: the list may have changed in the meantime
			local best, bestD
			for i, p in ipairs( l ) do
				local d = p:DistToSqr( a )
				if d < 4 and ( not bestD or d < bestD ) then best, bestD = i, d end
			end
			if not best then return end
			table.remove( l, best )
		else
			local n = math.min( net.ReadUInt( 12 ), LBR.MaxPointsPerCategory )
			a = {}
			for i = 1, n do
				local v = readPoint()
				if v then a[#a + 1] = v end
			end
			for i = #l, 1, -1 do l[i] = nil end
			for i, v in ipairs( a ) do l[i] = v end
		end
	elseif kind == SYNC_SETTINGS or kind == SYNC_FULL then
		local raw = readJSON()
		if not istable( raw ) then return end
		if kind == SYNC_SETTINGS then
			local full = util.JSONToTable( LBR.MapConfigToJSON( draft ) )
			full.zone_radius, full.zone_delay = raw.zone_radius, raw.zone_delay
			full.weaponsc, full.playermodels = raw.weaponsc, raw.playermodels
			raw = full
		end
		local cfg = LBR.SanitizeMapConfig( raw )
		if not cfg then return end
		LBR.EdDraft = cfg
	else
		return
	end
	LBR.EdDraftDirty = true

	// to the other editors, as the server has it now
	local others = editorList( ply )
	if #others == 0 then return end
	net.Start( "LBR_Editor_Sync" )
		net.WriteEntity( ply )
		net.WriteUInt( kind, 3 )
		if kind == SYNC_ADD then
			net.WriteUInt( ci, 4 ) writePoint( a ) net.WriteUInt( b, 12 )
		elseif kind == SYNC_REMOVE then
			net.WriteUInt( ci, 4 ) writePoint( a )
		elseif kind == SYNC_LIST then
			net.WriteUInt( ci, 4 ) net.WriteUInt( #a, 12 )
			for _, v in ipairs( a ) do writePoint( v ) end
		elseif kind == SYNC_SETTINGS then
			writeJSON( settingsOf( LBR.EdDraft ) )
		else
			writeJSON( util.JSONToTable( LBR.MapConfigToJSON( LBR.EdDraft ) ) )
		end
	net.Send( others )
end )

// editor map (M): the map area of the points being placed, found the same way as
// the one of the saved config (LBR.ComputeMapBounds in sv_map.lua)
net.Receive( "LBR_Editor_Bounds", function( len, ply )
	if not canUseEditorNet( ply ) then return end
	if ( ply.LBR_EdBoundsNext or 0 ) > CurTime() then return end
	ply.LBR_EdBoundsNext = CurTime() + 0.3
	local mins, maxs = net.ReadVector(), net.ReadVector()
	local n = math.min( net.ReadUInt( 7 ), 64 )
	local points = {}
	for i = 1, n do points[i] = net.ReadVector() end
	if #points == 0 or not LBR.ComputeMapBounds then return end
	local a, b = LBR.ComputeMapBounds( mins, maxs, points )
	net.Start( "LBR_Editor_Bounds" )
		net.WriteVector( a )
		net.WriteVector( b )
	net.Send( ply )
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
