// Loot and vehicle tables: format of data/lastbattleroyale/loot.txt
// One file for the whole addon (every map), made by the Loot panel of the map
// editor (F8 -> Q -> Loot and vehicles). Without the file the gamemode uses the
// tables in config.lua (ITEMS, VEHICLES, FLYING_VEHICLES, TIERS, WEAPON_DAMAGE,
// SUPPLY_DROP).
//
// {
//   "format": "lastbattleroyale-loot", "version": 2,
//   "groups": {
//     "GREEN": [ { "class": "cw_m1911", "weight": 1, "on": true, "ammo": 0, "damage": 100 }, ... ],
//     "BLUE": [...], "PURPLE": [...], "THROWABLES": [...], "ITEMS": [...], ...
//   },
//   "tiers": { "green": 100, "blue": 50, "purple": 25 },
//   "supply": { "time": 5, "purple": 1, "blue": 1, "purple_chance": 50, "purple_clips": 2, "items": [ ... ] }
// }
// weight = how many "tickets" the class has in its group (the old config.lua
// lists had a class written twice to make it twice as likely: that is weight 2).
// ammo = extra reserve rounds given when the weapon is picked up (0 = only the
// loaded magazine). damage = percent of the weapon's damage (100 = unchanged).
// A weapon is in one tier only (GREEN, BLUE or PURPLE).
// Version 1 files (BETTERWEAPONS / WEAPONS / ADDITIONALWEAPONS, CW 2.0 kits)
// are converted when read: each weapon goes in its default tier.

LBR = LBR or {}

LBR.LootFile = "lastbattleroyale/loot.txt"
LBR.LootFormat = "lastbattleroyale-loot"
LBR.LootVersion = 2

// order = order in the panel
LBR.LootGroups = {
	{ id = "GREEN",         name = "Green weapons",      desc = "Simple weapons: pistols, simple SMGs (1st loot number)", tier = "green" },
	{ id = "BLUE",          name = "Blue weapons",       desc = "Good weapons: assault rifles, good SMGs, shotguns (2nd loot number)", tier = "blue" },
	{ id = "PURPLE",        name = "Purple weapons",     desc = "Special weapons: snipers, machine guns (3rd loot number)", tier = "purple" },
	{ id = "THROWABLES",    name = "Throwables",         desc = "Grenades, molotov, mines: no tier (7th loot number)" },
	{ id = "ITEMS",         name = "Items",              desc = "Medkits, adrenaline, armor, ghillie (4th loot number)" },
	{ id = "AMMO",          name = "Ammo",               desc = "Ammo kits: magazines for the weapon in your hands (5th loot number)" },
	{ id = "ATTACHMENTS",   name = "Attachments",        desc = "Attachment kits for the weapon in your hands, CW 2.0 or ArcCW (6th loot number)" },
	{ id = "CARS",          name = "Cars",               desc = "One random car on every car point", vehicle = true },
	{ id = "HELI_RARE",     name = "Helicopters (50%)",  desc = "Half of the helicopter points pick from this list", vehicle = true },
	{ id = "HELI_VERYRARE", name = "Helicopters (50%) armed", desc = "The other half picks from this list", vehicle = true },
}

LBR.LootMaxPerGroup = 400
LBR.LootMaxWeight = 100
LBR.LootMaxAmmo = 9999
LBR.LootMaxDamage = 1000

LBR.SupplyDefaults = { time = 5, purple = 1, blue = 1, purple_chance = 50, purple_clips = 2, items = { "kevlar_armor", "sg_medkit_fix", "sg_adrenaline_fix", "lbr_ammo_medium" } }

function LBR.LootGroupById( id )
	for _, g in ipairs( LBR.LootGroups ) do
		if g.id == id then return g end
	end
end

local function validClass( c )
	return isstring( c ) and #c > 0 and #c <= 80 and string.match( c, "^[%w_%-%.]+$" ) ~= nil
end
LBR.LootValidClass = validClass

// { "a", "a", "b" } -> { { class = "a", weight = 2, on = true }, { class = "b", weight = 1, on = true } }
local function fromList( list, damage )
	local out, index = {}, {}
	for _, class in ipairs( list or {} ) do
		if validClass( class ) then
			if index[class] then
				index[class].weight = index[class].weight + 1
			else
				local e = { class = class, weight = 1, on = true }
				local d = damage and tonumber( damage[class] )
				if d and d ~= 100 then e.damage = math.Clamp( math.floor( d ), 1, LBR.LootMaxDamage ) end
				index[class] = e
				out[#out + 1] = e
			end
		end
	end
	return out
end

local function cleanSupply( s )
	s = istable( s ) and s or {}
	local d = LBR.SupplyDefaults
	local out = {
		time = math.Clamp( tonumber( s.time ) or d.time, 0, 60 ),
		purple = math.Clamp( math.floor( tonumber( s.purple ) or d.purple ), 0, 10 ),
		blue = math.Clamp( math.floor( tonumber( s.blue ) or d.blue ), 0, 10 ),
		purple_chance = math.Clamp( math.floor( tonumber( s.purple_chance ) or d.purple_chance ), 0, 100 ),
		purple_clips = math.Clamp( tonumber( s.purple_clips ) or d.purple_clips, 0, 10 ),
		items = {},
	}
	for _, c in ipairs( istable( s.items ) and s.items or d.items ) do
		if validClass( c ) and #out.items < 20 then out.items[#out.items + 1] = c end
	end
	return out
end
LBR.LootCleanSupply = cleanSupply

local function cleanTiers( t )
	t = istable( t ) and t or {}
	local out = {}
	for _, tier in ipairs( LBR.Tiers ) do
		out[tier.id] = math.Clamp( math.floor( tonumber( t[tier.id] ) or tier.defaultPercent ), 1, 1000 )
	end
	return out
end

// Config from the config.lua tables (the defaults)
function LBR.LootFromTables( items, vehicles, flying, tiers, damage, supply )
	items = items or {}
	flying = flying or {}
	return {
		GREEN         = fromList( items.GREEN, damage ),
		BLUE          = fromList( items.BLUE, damage ),
		PURPLE        = fromList( items.PURPLE, damage ),
		THROWABLES    = fromList( items.THROWABLES, damage ),
		ITEMS         = fromList( items.ITEMS ),
		AMMO          = fromList( items.AMMO ),
		ATTACHMENTS   = fromList( items.ATTACHMENTS ),
		CARS          = fromList( vehicles ),
		HELI_RARE     = fromList( flying.RARE ),
		HELI_VERYRARE = fromList( flying.VERYRARE ),
		TIERS         = cleanTiers( tiers ),
		SUPPLY        = cleanSupply( supply ),
	}
end

// { entries } -> { "a", "a", "b" } (what the spawn code picks from)
function LBR.LootExpand( entries )
	local out = {}
	for _, e in ipairs( entries or {} ) do
		if e.on then
			for _ = 1, e.weight do out[#out + 1] = e.class end
		end
	end
	return out
end

function LBR.LootToJSON( groups )
	local data = { format = LBR.LootFormat, version = LBR.LootVersion, groups = {}, tiers = cleanTiers( groups.TIERS ), supply = cleanSupply( groups.SUPPLY ) }
	for _, g in ipairs( LBR.LootGroups ) do
		local list = {}
		for _, e in ipairs( groups[g.id] or {} ) do
			list[#list + 1] = {
				class = e.class, weight = e.weight, on = e.on and true or false,
				ammo = ( e.ammo or 0 ) > 0 and e.ammo or nil,
				damage = ( e.damage and e.damage ~= 100 ) and e.damage or nil,
			}
		end
		data.groups[g.id] = list
	end
	return util.TableToJSON( data, true )
end

------------------------------------------------------------------------
// Version 1 -> 2
------------------------------------------------------------------------

local OLD_CLASSES = {
	cw_ammo_kit_small = "lbr_ammo_small",
	cw_ammo_kit_regular = "lbr_ammo_medium",
	cw_ammo_crate_small = "lbr_ammo_big",
	cw_ammo_crate_regular = "lbr_ammo_big",
	cw_attpack_random_small = "lbr_attpack_small",
	cw_attpack_random_medium = "lbr_attpack_medium",
	cw_attpack_random_big = "lbr_attpack_big",
}

local function isThrowable( class ) return LBR.IsThrowableClass( class ) end

// old groups: BETTERWEAPONS (rare), WEAPONS, ADDITIONALWEAPONS (pistols + grenades)
local function migrate( src )
	local defaults = LBR.LootDefaults or {}
	local defaultGroup = {}
	for _, id in ipairs( { "GREEN", "BLUE", "PURPLE", "THROWABLES" } ) do
		for _, e in ipairs( defaults[id] or {} ) do defaultGroup[e.class] = id end
	end
	local fallback = { BETTERWEAPONS = "BLUE", WEAPONS = "GREEN", ADDITIONALWEAPONS = "GREEN" }
	local out = { GREEN = {}, BLUE = {}, PURPLE = {}, THROWABLES = {} }
	for _, old in ipairs( { "BETTERWEAPONS", "WEAPONS", "ADDITIONALWEAPONS" } ) do
		for _, e in ipairs( istable( src[old] ) and src[old] or {} ) do
			if istable( e ) and validClass( e.class ) then
				local to = defaultGroup[e.class] or ( isThrowable( e.class ) and "THROWABLES" ) or fallback[old]
				table.insert( out[to], e )
			end
		end
	end
	for id, list in pairs( out ) do src[id] = list end
	for _, id in ipairs( { "AMMO", "ATTACHMENTS", "ITEMS" } ) do
		for _, e in ipairs( istable( src[id] ) and src[id] or {} ) do
			if istable( e ) and OLD_CLASSES[e.class] then e.class = OLD_CLASSES[e.class] end
		end
	end
end

// returns groups or nil, error (groups.TIERS / groups.SUPPLY: settings)
function LBR.LootFromJSON( json )
	if not isstring( json ) or json == "" then return nil, "empty" end
	local data = util.JSONToTable( json )
	if not istable( data ) then return nil, "not valid JSON" end
	if data.format ~= LBR.LootFormat then return nil, "not a loot file" end
	if not istable( data.groups ) then return nil, "no groups" end
	if ( tonumber( data.version ) or 1 ) < 2 then migrate( data.groups ) end

	local groups = {}
	local inTier = {}
	for _, g in ipairs( LBR.LootGroups ) do
		local list, seen = {}, {}
		local src = data.groups[g.id]
		if istable( src ) then
			for _, e in ipairs( src ) do
				if #list >= LBR.LootMaxPerGroup then break end
				// a weapon is in one tier only: the first one wins
				if istable( e ) and validClass( e.class ) and not seen[e.class] and not ( g.tier and inTier[e.class] ) then
					seen[e.class] = true
					if g.tier then inTier[e.class] = true end
					local dmg = math.Clamp( math.floor( tonumber( e.damage ) or 100 ), 1, LBR.LootMaxDamage )
					list[#list + 1] = {
						class = e.class,
						weight = math.Clamp( math.floor( tonumber( e.weight ) or 1 ), 1, LBR.LootMaxWeight ),
						on = e.on ~= false,
						ammo = math.Clamp( math.floor( tonumber( e.ammo ) or 0 ), 0, LBR.LootMaxAmmo ),
						damage = dmg ~= 100 and dmg or nil,
					}
				end
			end
		end
		// a group the file does not have yet (saved by an older version): the defaults
		if not istable( src ) and LBR.LootDefaults and LBR.LootDefaults[g.id] then
			list = table.Copy( LBR.LootDefaults[g.id] )
		end
		groups[g.id] = list
	end
	groups.TIERS = cleanTiers( data.tiers or ( LBR.LootDefaults and LBR.LootDefaults.TIERS ) )
	groups.SUPPLY = cleanSupply( data.supply or ( LBR.LootDefaults and LBR.LootDefaults.SUPPLY ) )
	return groups
end
