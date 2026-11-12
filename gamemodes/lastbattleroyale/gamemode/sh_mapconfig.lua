// Shared map configuration helpers: categories, JSON (de)serialization, validation.
// Used by the server (loading / saving map files) and by the client map editor.

LBR = LBR or {}

LBR.MapDataDir = "lastbattleroyale/maps"
LBR.MaxPointsPerCategory = 2048

// Every kind of point that can be placed on a map.
//  key      = key inside the map config (and in the JSON file)
//  parent   = optional sub-table (events.*)
//  offset   = height added to the aimed surface when placing
//  hull     = shape drawn by the editor
//  eye      = place at the editor's own position by default (things in the sky)
LBR.MapCategories = {
	{ key = "playerspawns",         name = "Player spawns",   desc = "Where players appear when the match starts", color = Color( 80, 220, 80 ),   offset = 8,  hull = "player" },
	{ key = "initialspawns",        name = "Lobby spawns",    desc = "Waiting area between rounds",                color = Color( 80, 170, 255 ),  offset = 8,  hull = "player" },
	{ key = "weaponspawns",         name = "Loot",            desc = "Weapons, items and ammo",                    color = Color( 255, 210, 60 ),  offset = 10, hull = "loot" },
	{ key = "vehiclepositions",     name = "Cars",            desc = "SCars",                                      color = Color( 255, 140, 40 ),  offset = 30, hull = "car" },
	{ key = "flying_vehiclespawns", name = "Helicopters",     desc = "WAC helicopters",                            color = Color( 200, 110, 255 ), offset = 40, hull = "heli" },
	{ key = "endpositions",         name = "Zone centers",    desc = "One is picked as the zone center each round", color = Color( 255, 70, 70 ),  offset = 0,  hull = "zone" },
	{ key = "nukepositions",        name = "Nuke targets",    desc = "Nuclear strike event",        parent = "events", color = Color( 170, 40, 40 ),   offset = 0,  hull = "small" },
	{ key = "supplydrops",          name = "Supply drops",    desc = "Airdrops, place them high in the sky", parent = "events", color = Color( 240, 240, 240 ), offset = 0, hull = "small", eye = true },
}

LBR.WeaponCountNames = { "Better weapons", "Weapons", "Additional weapons", "Items", "Ammo", "Attachment kits" }
LBR.WeaponCountIcons = { "icon16/star.png", "icon16/gun.png", "icon16/bomb.png", "icon16/heart.png", "icon16/box.png", "icon16/wrench.png" }

// attachment kits of a map that does not set them (configs made before the 6th
// number): one kit every 3 weapons
function LBR.DefaultAttachmentKits( wc )
	return math.Round( ( ( wc[1] or 0 ) + ( wc[2] or 0 ) + ( wc[3] or 0 ) ) / 3 )
end

LBR.DefaultPlayerModels = {
	"models/player/group03/female_01.mdl",
	"models/player/group03/female_02.mdl",
	"models/player/group03/female_03.mdl",
	"models/player/group03/female_04.mdl",
	"models/player/group03/female_05.mdl",
	"models/player/group03/female_06.mdl",
	"models/player/group03/male_01.mdl",
	"models/player/group03/male_02.mdl",
	"models/player/group03/male_03.mdl",
	"models/player/group03/male_04.mdl",
	"models/player/group03/male_05.mdl",
	"models/player/group03/male_06.mdl",
	"models/player/group03/male_07.mdl",
	"models/player/group03/male_08.mdl",
	"models/player/group03/male_09.mdl"
}

function LBR.SafeMapName( map )
	return string.gsub( string.lower( map or game.GetMap() ), "[^%w_%-%.]", "_" )
end

function LBR.MapFileName( map )
	return LBR.MapDataDir .. "/" .. LBR.SafeMapName( map ) .. ".txt"
end

// Returns the point list of a category. With create = true missing tables are created.
function LBR.GetCategoryList( cfg, cat, create )
	if not istable( cfg ) then return {} end
	local holder = cfg
	if cat.parent then
		holder = cfg[cat.parent]
		if not istable( holder ) then
			if not create then return {} end
			holder = {}
			cfg[cat.parent] = holder
		end
	end
	local list = holder[cat.key]
	if not istable( list ) then
		if not create then return {} end
		list = {}
		holder[cat.key] = list
	end
	return list
end

function LBR.NewMapConfig()
	local cfg = {
		zone_radius = 20000,
		weaponsc = { 10, 10, 10, 10, 10, 10 },
		playermodels = table.Copy( LBR.DefaultPlayerModels )
	}
	for _, cat in ipairs( LBR.MapCategories ) do
		LBR.GetCategoryList( cfg, cat, true )
	end
	return cfg
end

local function finite( n )
	return n ~= nil and n == n and n > -1e6 and n < 1e6
end

// Accepts a Vector, {x,y,z}, {x=,y=,z=} or the "[x y z]" string written by util.TableToJSON
local function toVector( v )
	local x, y, z
	if isvector( v ) then
		x, y, z = v.x, v.y, v.z
	elseif istable( v ) then
		x, y, z = tonumber( v[1] or v.x ), tonumber( v[2] or v.y ), tonumber( v[3] or v.z )
	elseif isstring( v ) then
		local a, b, c = string.match( v, "^%[?%s*([%-%d%.e]+)%s+([%-%d%.e]+)%s+([%-%d%.e]+)" )
		x, y, z = tonumber( a ), tonumber( b ), tonumber( c )
	end
	if finite( x ) and finite( y ) and finite( z ) then
		return Vector( x, y, z )
	end
end

// Builds a clean config from anything (built-in table, decoded JSON, network data).
function LBR.SanitizeMapConfig( raw )
	if not istable( raw ) then return nil, "config is not a table" end
	local cfg = {}
	for _, cat in ipairs( LBR.MapCategories ) do
		local src
		if cat.parent then
			src = istable( raw[cat.parent] ) and raw[cat.parent][cat.key]
		else
			src = raw[cat.key]
		end
		local out = LBR.GetCategoryList( cfg, cat, true )
		if istable( src ) then
			for _, v in ipairs( src ) do
				local vec = toVector( v )
				if vec then
					out[#out + 1] = vec
					if #out >= LBR.MaxPointsPerCategory then break end
				end
			end
		end
	end

	cfg.zone_radius = math.Clamp( math.floor( tonumber( raw.zone_radius ) or 20000 ), 100, 500000 )
	// seconds before the zone starts shrinking on this map; none = lbr_zone_delay
	local zd = tonumber( raw.zone_delay )
	cfg.zone_delay = ( zd and zd >= 0 ) and math.min( math.floor( zd ), 3600 ) or nil

	cfg.weaponsc = {}
	local wc = istable( raw.weaponsc ) and raw.weaponsc or {}
	for i = 1, #LBR.WeaponCountNames do
		cfg.weaponsc[i] = math.Clamp( math.floor( tonumber( wc[i] ) or 0 ), 0, 1000 )
	end
	if tonumber( wc[6] ) == nil then cfg.weaponsc[6] = LBR.DefaultAttachmentKits( cfg.weaponsc ) end

	cfg.playermodels = {}
	if istable( raw.playermodels ) then
		for _, mdl in ipairs( raw.playermodels ) do
			if isstring( mdl ) and #mdl < 260 and string.match( string.lower( mdl ), "%.mdl$" ) then
				cfg.playermodels[#cfg.playermodels + 1] = mdl
				if #cfg.playermodels >= 64 then break end
			end
		end
	end
	if #cfg.playermodels == 0 then
		cfg.playermodels = table.Copy( LBR.DefaultPlayerModels )
	end

	return cfg
end

function LBR.MapConfigToJSON( cfg, map )
	local out = {
		format = "lastbattleroyale-map",
		version = 1,
		map = map or game.GetMap(),
		zone_radius = cfg.zone_radius,
		zone_delay = cfg.zone_delay,
		weaponsc = cfg.weaponsc,
		playermodels = cfg.playermodels
	}
	for _, cat in ipairs( LBR.MapCategories ) do
		local arr = {}
		for i, v in ipairs( LBR.GetCategoryList( cfg, cat ) ) do
			arr[i] = { math.Round( v.x, 2 ), math.Round( v.y, 2 ), math.Round( v.z, 2 ) }
		end
		LBR.GetCategoryList( out, cat, true )
		if cat.parent then out[cat.parent][cat.key] = arr else out[cat.key] = arr end
	end
	return util.TableToJSON( out, true )
end

// Returns cfg, map name stored in the file (may be nil) / or nil, error
function LBR.MapConfigFromJSON( str )
	if not isstring( str ) or str == "" then return nil, "empty file" end
	local raw = util.JSONToTable( str )
	if not istable( raw ) then return nil, "invalid JSON" end
	local cfg, err = LBR.SanitizeMapConfig( raw )
	if not cfg then return nil, err end
	return cfg, isstring( raw.map ) and raw.map or nil
end

// items that need a loot position of their own: the attachment kits (6th number)
// do not, when the positions are all taken they spawn next to other loot
function LBR.CountWeapons( cfg )
	local n = 0
	for i = 1, 5 do n = n + ( ( cfg.weaponsc or {} )[i] or 0 ) end
	return n
end

// all the loot of a match (weapons, items, ammo, attachment kits...): the number shown in the editor
function LBR.CountLoot( cfg )
	local wc = cfg.weaponsc or {}
	return LBR.CountWeapons( cfg ) + ( wc[6] or LBR.DefaultAttachmentKits( wc ) )
end

// errors = the map can not be played, warnings = it works but something is off
function LBR.ValidateMapConfig( cfg )
	local errors, warnings = {}, {}
	if not istable( cfg ) then
		errors[1] = "Map is not configured"
		return errors, warnings
	end
	local function count( key, parent )
		for _, cat in ipairs( LBR.MapCategories ) do
			if cat.key == key and cat.parent == parent then
				return #LBR.GetCategoryList( cfg, cat )
			end
		end
		return 0
	end
	if count( "playerspawns" ) == 0 then errors[#errors + 1] = "No player spawns" end
	if count( "weaponspawns" ) == 0 then errors[#errors + 1] = "No loot positions" end
	if count( "endpositions" ) == 0 then errors[#errors + 1] = "No zone centers" end
	if ( cfg.zone_radius or 0 ) <= 0 then errors[#errors + 1] = "Zone radius is 0" end

	if count( "initialspawns" ) == 0 then warnings[#warnings + 1] = "No lobby spawns (map spawn points are used)" end
	local need = LBR.CountLoot( cfg )
	local have = count( "weaponspawns" )
	if have > 0 and have < need then
		warnings[#warnings + 1] = "Loot spots " .. have .. " < loot " .. need .. ": add " .. ( need - have ) .. " spots"
	end
	if count( "playerspawns" ) > 0 and count( "playerspawns" ) < 8 then
		warnings[#warnings + 1] = "Only " .. count( "playerspawns" ) .. " player spawns (players will share them)"
	end
	if count( "supplydrops", "events" ) == 0 then warnings[#warnings + 1] = "No supply drops (airdrop event disabled)" end
	if count( "nukepositions", "events" ) == 0 then warnings[#warnings + 1] = "No nuke targets (nuke event disabled)" end
	return errors, warnings
end

// Fisher-Yates shuffle of a copy, used instead of table.Random + table.RemoveByValue (O(n^2))
function LBR.ShuffledCopy( tbl )
	local out = {}
	for i, v in ipairs( tbl or {} ) do out[i] = v end
	for i = #out, 2, -1 do
		local j = math.random( i )
		out[i], out[j] = out[j], out[i]
	end
	return out
end

------------------------------------------------------------------------
// Entity classes used by the performance code (sv_perf.lua / cl_perf.lua / cl_zone.lua)
------------------------------------------------------------------------

LBR.LootPrefixes = { "khr_", "cw_", "weapon_", "sg_", "kevlar_", "suit_", "rust_" }
LBR.VehiclePrefixes = { "sent_sakarias_", "wac_" }

local function hasPrefix( class, list )
	for i = 1, #list do
		if string.sub( class, 1, #list[i] ) == list[i] then return true end
	end
	return false
end

function LBR.IsLootClass( class )
	return hasPrefix( class, LBR.LootPrefixes )
end

function LBR.IsVehicleClass( class )
	return hasPrefix( class, LBR.VehiclePrefixes )
end
