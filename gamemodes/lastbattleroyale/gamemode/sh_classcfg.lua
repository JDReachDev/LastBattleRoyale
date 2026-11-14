// Classes (F3): name, description, health, armor, speed, loadout and unlock
// requirements, editable in game (F8 -> Q -> Classes). One file for the whole
// addon (every map): data/lastbattleroyale/classes.txt. Without the file the
// classes are the ones of classes.lua + player_class/*.lua.
//
// {
//   "format": "lastbattleroyale-classes", "version": 1,
//   "classes": {
//     "class_soldier": { "name": "Soldier", "desc": "...", "health": 100, "armor": 0,
//                        "walk": 100, "run": 100, "loadout": [ "weapon_crowbar", "cw_p99" ],
//                        "needs": [ { "class": "class_scout", "level": 25 } ] },
//     ...
//   }
// }
// walk / run = percent of the server speed (lbr walk / run speed options).

LBR = LBR or {}

LBR.ClassFile = "lastbattleroyale/classes.txt"
LBR.ClassFormat = "lastbattleroyale-classes"
LBR.ClassLimits = { health = { 1, 1000 }, armor = { 0, 255 }, walk = { 10, 300 }, run = { 10, 300 }, level = { 0, 1000 } }
LBR.ClassMaxLoadout = 12
LBR.ClassMaxNeeds = 8

// armor given in the old Loadout() functions (not in a field)
local OLD_ARMOR = { class_russian = 30, class_scout = 30 }

local function validClass( c )
	return isstring( c ) and #c > 0 and #c <= 80 and string.match( c, "^[%w_%-%.]+$" ) ~= nil
end

local function clampNum( v, key, def )
	local l = LBR.ClassLimits[key]
	return math.Clamp( math.floor( tonumber( v ) or def ), l[1], l[2] )
end

// the table given to player_manager.RegisterClass: baseclass keeps that same
// table (player_manager.GetPlayerClasses only gives a copy)
local function classTables( cls )
	local b = baseclass.Get( cls )
	if istable( b ) and next( b ) ~= nil then return { b } end
	return {}
end

local function isClass( cls )
	for _, c in ipairs( CLASSES or {} ) do
		if c.class == cls then return true end
	end
	return false
end

// defaults: what classes.lua and player_class/*.lua say (read once, before any change)
local function buildDefaults()
	local out = {}
	for _, c in ipairs( CLASSES or {} ) do
		local t = classTables( c.class )[1] or {}
		local info = CLASS_INFO and CLASS_INFO[c.class] or {}
		local needs = {}
		for _, n in ipairs( c.classesneeded or {} ) do
			needs[#needs + 1] = { class = n.class, level = tonumber( n.level ) or 0 }
		end
		out[c.class] = {
			name = t.DisplayName or c.name or c.class,
			desc = info.desc or "",
			health = tonumber( t.MaxHealth ) or 100,
			armor = OLD_ARMOR[c.class] or tonumber( t.StartArmor ) or 0,
			walk = math.Round( ( tonumber( t.WalkSpeed ) or 1 ) * 100 ),
			run = math.Round( ( tonumber( t.RunSpeed ) or 1 ) * 100 ),
			loadout = table.Copy( info.loadout or {} ),
			needs = needs,
		}
	end
	return out
end

// cleans one class entry (from a file or from the editor), def = its default
local function cleanEntry( cls, e, def )
	e = istable( e ) and e or {}
	def = def or {}
	local out = {
		name = isstring( e.name ) and string.Trim( e.name ) ~= "" and string.sub( string.Trim( e.name ), 1, 32 ) or def.name or cls,
		desc = isstring( e.desc ) and string.sub( e.desc, 1, 200 ) or def.desc or "",
		health = clampNum( e.health, "health", def.health or 100 ),
		armor = clampNum( e.armor, "armor", def.armor or 0 ),
		walk = clampNum( e.walk, "walk", def.walk or 100 ),
		run = clampNum( e.run, "run", def.run or 100 ),
		loadout = {},
		needs = {},
	}
	for _, w in ipairs( istable( e.loadout ) and e.loadout or def.loadout or {} ) do
		if validClass( w ) and #out.loadout < LBR.ClassMaxLoadout then out.loadout[#out.loadout + 1] = w end
	end
	for _, n in ipairs( istable( e.needs ) and e.needs or def.needs or {} ) do
		if istable( n ) and isClass( n.class ) and n.class ~= cls and #out.needs < LBR.ClassMaxNeeds then
			out.needs[#out.needs + 1] = { class = n.class, level = clampNum( n.level, "level", 1 ) }
		end
	end
	return out
end

function LBR.ClassesFromJSON( json )
	local data = isstring( json ) and util.JSONToTable( json )
	if not istable( data ) then return nil, "not JSON" end
	if data.format ~= LBR.ClassFormat then return nil, "not a classes file" end
	local src = istable( data.classes ) and data.classes or {}
	local out = {}
	for _, c in ipairs( CLASSES or {} ) do
		out[c.class] = cleanEntry( c.class, src[c.class], LBR.ClassDefaults[c.class] )
	end
	return out
end

function LBR.ClassesToJSON( cfg )
	local data = { format = LBR.ClassFormat, version = 1, classes = {} }
	for _, c in ipairs( CLASSES or {} ) do
		if cfg[c.class] then data.classes[c.class] = cleanEntry( c.class, cfg[c.class], LBR.ClassDefaults[c.class] ) end
	end
	return util.TableToJSON( data, true )
end

// puts the config in the class tables (stats, Loadout), CLASSES (name, unlock)
// and CLASS_INFO (F3 menu)
function LBR.ApplyClasses( cfg )
	LBR.ClassCfg = cfg
	CLASS_INFO = CLASS_INFO or {}
	for _, c in ipairs( CLASSES or {} ) do
		local e = cfg[c.class]
		if e then
			c.name = e.name
			c.classesneeded = table.Copy( e.needs )
			CLASS_INFO[c.class] = CLASS_INFO[c.class] or {}
			CLASS_INFO[c.class].desc = e.desc
			CLASS_INFO[c.class].loadout = table.Copy( e.loadout )
			local cls = c.class
			for _, t in ipairs( classTables( cls ) ) do
				t.DisplayName = e.name
				t.MaxHealth = e.health
				t.StartHealth = e.health
				t.StartArmor = e.armor
				t.WalkSpeed = e.walk / 100
				t.RunSpeed = e.run / 100
				t.Loadout = function( self )
					local pl = self.Player
					local cur = LBR.ClassCfg and LBR.ClassCfg[cls]
					pl:RemoveAllAmmo()
					pl:StripWeapons()
					for _, w in ipairs( cur and cur.loadout or {} ) do pl:Give( w ) end
					pl:SetArmor( cur and cur.armor or 0 )
				end
			end
		end
	end
end

LBR.ClassDefaults = LBR.ClassDefaults or buildDefaults()

------------------------------------------------------------------------
// Net: the server sends the classes to everyone (F3 menu), the editor saves
------------------------------------------------------------------------

if SERVER then
	util.AddNetworkString( "LBR_Classes" )
	util.AddNetworkString( "LBR_Classes_Get" )
	util.AddNetworkString( "LBR_Classes_Save" )
	util.AddNetworkString( "LBR_Classes_Reset" )

	LBR.ClassSource = "default"

	local function writeCfg()
		local data = util.Compress( util.TableToJSON( { format = LBR.ClassFormat, version = 1, classes = LBR.ClassCfg } ) )
		net.WriteString( LBR.ClassSource )
		net.WriteUInt( #data, 16 )
		net.WriteData( data, #data )
	end

	function LBR.SendClasses( target, open )
		net.Start( "LBR_Classes" )
			net.WriteBool( open == true )
			writeCfg()
		if target then net.Send( target ) else net.Broadcast() end
	end

	function LBR.LoadClasses()
		local cfg
		if file.Exists( LBR.ClassFile, "DATA" ) then
			local err
			cfg, err = LBR.ClassesFromJSON( file.Read( LBR.ClassFile, "DATA" ) )
			if cfg then
				LBR.ClassSource = "file"
				print( "[LBR] Classes loaded from data/" .. LBR.ClassFile )
			else
				print( "[LBR] data/" .. LBR.ClassFile .. " is not valid (" .. tostring( err ) .. "), using classes.lua" )
			end
		end
		if not cfg then
			cfg = table.Copy( LBR.ClassDefaults )
			LBR.ClassSource = "default"
		end
		LBR.ApplyClasses( cfg )
		if player.GetCount() > 0 then LBR.SendClasses() end
	end

	local function canEdit( ply )
		return IsValid( ply ) and ply.LBR_Editing and LBR.CanEdit and LBR.CanEdit( ply )
	end
	local function msg( ply, ok, text )
		net.Start( "LBR_Editor_Msg" )
			net.WriteBool( ok )
			net.WriteString( text )
		net.Send( ply )
	end
	local function throttle( ply )
		if ( ply.LBR_NextClassNet or 0 ) > CurTime() then return true end
		ply.LBR_NextClassNet = CurTime() + 0.5
		return false
	end

	// everyone asks once (InitPostEntity); the editor asks with open = true
	net.Receive( "LBR_Classes_Get", function( len, ply )
		if throttle( ply ) then return end
		local open = net.ReadBool()
		if open and not canEdit( ply ) then return end
		LBR.SendClasses( ply, open )
	end )

	net.Receive( "LBR_Classes_Save", function( len, ply )
		if not canEdit( ply ) or throttle( ply ) then return end
		local size = net.ReadUInt( 16 )
		local cfg, err = LBR.ClassesFromJSON( util.Decompress( net.ReadData( size ), 256 * 1024 ) )
		if not cfg then
			msg( ply, false, "Classes not saved: " .. tostring( err ) )
			return
		end
		file.CreateDir( "lastbattleroyale" )
		file.Write( LBR.ClassFile, LBR.ClassesToJSON( cfg ) )
		if not file.Exists( LBR.ClassFile, "DATA" ) then
			msg( ply, false, "Classes not saved: could not write data/" .. LBR.ClassFile )
			return
		end
		LBR.ClassSource = "file"
		LBR.ApplyClasses( cfg )
		LBR.SendClasses()
		print( "[LBR] " .. ply:Nick() .. " saved the classes to data/" .. LBR.ClassFile )
		msg( ply, true, "Classes written to data/" .. LBR.ClassFile .. " (stats and loadout from the next spawn)" )
		LBR.SendClasses( ply, true )
	end )

	net.Receive( "LBR_Classes_Reset", function( len, ply )
		if not canEdit( ply ) or throttle( ply ) then return end
		if file.Exists( LBR.ClassFile, "DATA" ) then file.Delete( LBR.ClassFile ) end
		LBR.LoadClasses()
		LBR.SendClasses()
		msg( ply, true, "Classes reset to classes.lua" )
		LBR.SendClasses( ply, true )
	end )

	concommand.Add( "lbr_classes_reload", function( ply )
		if IsValid( ply ) and not ply:IsSuperAdmin() then return end
		LBR.LoadClasses()
		local text = "[LBR] Classes reloaded (" .. LBR.ClassSource .. ")"
		if IsValid( ply ) then LBR.Chat( ply, text ) else print( text ) end
	end )

	// init.lua includes classes.lua a second time after shared.lua (CLASSES and
	// CLASS_INFO made again): load once every file is in
	hook.Add( "Initialize", "LBR_LoadClasses", LBR.LoadClasses )
	if LBR.ClassCfg then LBR.LoadClasses() end // lua refresh
else
	net.Receive( "LBR_Classes", function()
		local open = net.ReadBool()
		local source = net.ReadString()
		local size = net.ReadUInt( 16 )
		local data = util.JSONToTable( util.Decompress( net.ReadData( size ), 256 * 1024 ) or "" )
		if not istable( data ) or not istable( data.classes ) then return end
		local cfg = {}
		for _, c in ipairs( CLASSES or {} ) do
			cfg[c.class] = cleanEntry( c.class, data.classes[c.class], LBR.ClassDefaults[c.class] )
		end
		LBR.ApplyClasses( cfg )
		LBR.ClassSource = source
		if open and LBR.OnClassesForEditor then LBR.OnClassesForEditor( cfg, source ) end
	end )

	hook.Add( "InitPostEntity", "LBR_ClassesGet", function()
		net.Start( "LBR_Classes_Get" )
			net.WriteBool( false )
		net.SendToServer()
	end )
end
