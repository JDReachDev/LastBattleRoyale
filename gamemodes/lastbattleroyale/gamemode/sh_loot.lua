// Loot and vehicle tables: format of data/lastbattleroyale/loot.txt
//
// Without the file the gamemode uses the tables in config.lua exactly as before
// (ITEMS, VEHICLES, FLYING_VEHICLES). The file is written only when an admin
// saves from the Loot panel of the map editor (F8 -> Q -> Loot and vehicles).
//
// {
//   "format": "lastbattleroyale-loot", "version": 1,
//   "groups": {
//     "BETTERWEAPONS": [ { "class": "cw_ak74", "weight": 1, "on": true }, ... ],
//     ...
//   }
// }
// weight = how many "tickets" the class has in its group (the old config.lua
// lists had a class written twice to make it twice as likely: that is weight 2).

LBR = LBR or {}

LBR.LootFile = "lastbattleroyale/loot.txt"
LBR.LootFormat = "lastbattleroyale-loot"

// order = order in the panel
LBR.LootGroups = {
	{ id = "BETTERWEAPONS",     name = "Rare weapons",       desc = "Rifles, snipers, machine guns (amount per map: 1st loot number)" },
	{ id = "WEAPONS",           name = "Weapons",            desc = "SMGs, shotguns, revolvers (2nd loot number)" },
	{ id = "ADDITIONALWEAPONS", name = "Pistols & grenades", desc = "Pistols, grenades, molotov (3rd loot number)" },
	{ id = "ITEMS",             name = "Items",              desc = "Medkits, adrenaline, armor, ghillie, attachments (4th loot number)" },
	{ id = "AMMO",              name = "Ammo",               desc = "Ammo kits (5th loot number)" },
	{ id = "CARS",              name = "Cars",               desc = "One random car on every car point", vehicle = true },
	{ id = "HELI_RARE",         name = "Helicopters (50%)",  desc = "Half of the helicopter points pick from this list", vehicle = true },
	{ id = "HELI_VERYRARE",     name = "Helicopters (50%) armed", desc = "The other half picks from this list", vehicle = true },
}

LBR.LootMaxPerGroup = 400
LBR.LootMaxWeight = 100

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
local function fromList( list )
	local out, index = {}, {}
	for _, class in ipairs( list or {} ) do
		if validClass( class ) then
			if index[class] then
				index[class].weight = index[class].weight + 1
			else
				local e = { class = class, weight = 1, on = true }
				index[class] = e
				out[#out + 1] = e
			end
		end
	end
	return out
end

// Config from the config.lua tables (the defaults)
function LBR.LootFromTables( items, vehicles, flying )
	items = items or {}
	flying = flying or {}
	return {
		BETTERWEAPONS     = fromList( items.BETTERWEAPONS ),
		WEAPONS           = fromList( items.WEAPONS ),
		ADDITIONALWEAPONS = fromList( items.ADDITIONALWEAPONS ),
		ITEMS             = fromList( items.ITEMS ),
		AMMO              = fromList( items.AMMO ),
		CARS              = fromList( vehicles ),
		HELI_RARE         = fromList( flying.RARE ),
		HELI_VERYRARE     = fromList( flying.VERYRARE ),
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
	local data = { format = LBR.LootFormat, version = 1, groups = {} }
	for _, g in ipairs( LBR.LootGroups ) do
		local list = {}
		for _, e in ipairs( groups[g.id] or {} ) do
			list[#list + 1] = { class = e.class, weight = e.weight, on = e.on and true or false }
		end
		data.groups[g.id] = list
	end
	return util.TableToJSON( data, true )
end

// returns groups or nil, error
function LBR.LootFromJSON( json )
	if not isstring( json ) or json == "" then return nil, "empty" end
	local data = util.JSONToTable( json )
	if not istable( data ) then return nil, "not valid JSON" end
	if data.format ~= LBR.LootFormat then return nil, "not a loot file" end
	if not istable( data.groups ) then return nil, "no groups" end

	local groups = {}
	for _, g in ipairs( LBR.LootGroups ) do
		local list, seen = {}, {}
		local src = data.groups[g.id]
		if istable( src ) then
			for _, e in ipairs( src ) do
				if #list >= LBR.LootMaxPerGroup then break end
				if istable( e ) and validClass( e.class ) and not seen[e.class] then
					seen[e.class] = true
					list[#list + 1] = {
						class = e.class,
						weight = math.Clamp( math.floor( tonumber( e.weight ) or 1 ), 1, LBR.LootMaxWeight ),
						on = e.on ~= false
					}
				end
			end
		end
		groups[g.id] = list
	end
	return groups
end
