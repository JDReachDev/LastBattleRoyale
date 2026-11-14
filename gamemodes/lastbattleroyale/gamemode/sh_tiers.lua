// Weapon tiers: green (simple), blue (good), purple (special).
//
// - Every weapon of the GREEN / BLUE / PURPLE loot groups (config.lua, or
//   data/lastbattleroyale/loot.txt from the Loot editor) has that tier.
// - Colors: outline and beam of the loot, inventory, weapon bar, prompt, editor.
// - Ammo: three stores of magazines, one per color (sh_clips.lua). Every weapon
//   with a magazine has its own engine ammo ("lbr_w_cw_m4") whose reserve is its
//   store x its magazine size. Weapons without a tier use the green store.
// - Ammo kits (lbr_ammo_*): E opens a menu, you pick the colors. A magazine costs
//   100 / percent of its tier in green magazines (1 / 2 / 4 by default, set in
//   the Loot editor).
//
// The server sends the class -> tier list and the percents to the clients
// (LBR_Tiers), again whenever the Loot editor saves.

LBR = LBR or {}

LBR.Tiers = {
	{ id = "green",  group = "GREEN",  name = "Green",  color = Color( 90, 215, 95 ),  percent = 100 },
	{ id = "blue",   group = "BLUE",   name = "Blue",   color = Color( 65, 150, 255 ), percent = 50 },
	{ id = "purple", group = "PURPLE", name = "Purple", color = Color( 180, 95, 255 ), percent = 25 },
}
LBR.TierById = {}
LBR.TierByGroup = {}
for i, t in ipairs( LBR.Tiers ) do
	t.index = i
	t.defaultPercent = t.percent
	LBR.TierById[t.id] = t
	LBR.TierByGroup[t.group] = t
end

// class -> tier id
LBR.WeaponTier = LBR.WeaponTier or {}

function LBR.TierOfClass( class )
	local id = class and LBR.WeaponTier[class]
	return id and LBR.TierById[id] or nil
end

// tier table of a weapon entity (or class), nil = no tier
function LBR.TierOf( wep )
	if isstring( wep ) then return LBR.TierOfClass( wep ) end
	if not IsValid( wep ) then return nil end
	return LBR.TierOfClass( wep:GetClass() )
end

function LBR.TierColor( wep, fallback )
	local t = LBR.TierOf( wep )
	return t and t.color or fallback
end

if CLIENT then
	// small package of the tier color (editor, loot panel)
	function LBR.DrawTierBox( x, y, w, h, col )
		local s = math.min( w, h )
		x, y = x + math.floor( ( w - s ) / 2 ), y + math.floor( ( h - s ) / 2 )
		surface.SetDrawColor( col.r, col.g, col.b, 255 )
		surface.DrawRect( x, y + s * 0.2, s, s * 0.8 )
		surface.SetDrawColor( col.r * 0.6, col.g * 0.6, col.b * 0.6, 255 )
		surface.DrawRect( x - 1, y + s * 0.1, s + 2, s * 0.25 ) // lid
		surface.DrawRect( x + s * 0.42, y + s * 0.1, s * 0.16, s * 0.9 ) // band
		surface.SetDrawColor( 0, 0, 0, 160 )
		surface.DrawOutlinedRect( x - 1, y + s * 0.1, s + 2, s * 0.9 )
	end
end

------------------------------------------------------------------------
// Ammo kinds (from the caliber the weapon pack gives the weapon)
------------------------------------------------------------------------

local AMMO_KINDS = {
	pistol = { "pistol", "357", "alyxgun", "smg1", ".22lr", ".32 acp", ".357 magnum", ".357 sig", ".38 special",
		".44 magnum", ".45 acp", ".45 long colt", ".50 ae", "9x17mm", "9x18mm", "9x19mm", "9x21mm",
		"7.62x25mm", "5.7x28mm", "4.6x30mm", "9x19mm parabellum" },
	rifle = { "ar2", "5.56x45mm", "5.45x39mm", "7.62x39mm", "9x39mm", ".30 carbine", ".30-06", "5.56x45mm nato" },
	sniper = { "sniperround", "sniperpenetratedround", "7.62x51mm", "7.62x54mmr", ".338 lapua", ".50 bmg", ".416 barrett", ".408 cheytac" },
	shotgun = { "buckshot", "12 gauge", ".410 bore", "four-bore cartridge", "20 gauge" },
}
LBR.AmmoKinds = { "pistol", "rifle", "sniper", "shotgun", "smg" }
LBR.AmmoKindNames = { pistol = "Pistol", rifle = "Rifle", sniper = "Sniper", shotgun = "Shotgun", smg = "SMG" }
local kindOf = {}
for k, list in pairs( AMMO_KINDS ) do
	for _, name in ipairs( list ) do kindOf[name] = k end
end

// kind of an ammo name: a known caliber, else a guess from the name ("rifle" if nothing fits)
function LBR.AmmoKindOfName( name )
	if not isstring( name ) then return nil end
	name = string.lower( name )
	if kindOf[name] then return kindOf[name], true end
	if string.find( name, "gauge", 1, true ) or string.find( name, "buck", 1, true ) or string.find( name, "shell", 1, true ) then return "shotgun", false end
	if string.find( name, "sniper", 1, true ) or string.find( name, "lapua", 1, true ) or string.find( name, "bmg", 1, true ) then return "sniper", false end
	if string.find( name, "pistol", 1, true ) or string.find( name, "smg", 1, true ) or string.find( name, "acp", 1, true ) or string.find( name, "9x19", 1, true ) then return "pistol", false end
	return "rifle", false
end

// "lbr_blue_rifle"
function LBR.TierAmmoName( tierId, kind )
	return "lbr_" .. tierId .. "_" .. kind
end

// tier id of one of our ammo types, or nil
local tierAmmo = {}
for _, t in ipairs( LBR.Tiers ) do
	for _, k in ipairs( LBR.AmmoKinds ) do tierAmmo[LBR.TierAmmoName( t.id, k )] = t.id end
end
function LBR.TierOfAmmoName( name )
	return name and tierAmmo[string.lower( name )]
end

local function addAmmoType( name, label )
	game.AddAmmoType( {
		name = name,
		dmgtype = DMG_BULLET,
		tracer = TRACER_LINE_AND_WHIZ,
		plydmg = 0,
		npcdmg = 0,
		force = 2000,
		maxcarry = 9999,
		minsplash = 4,
		maxsplash = 8,
	} )
	if CLIENT then language.Add( name .. "_ammo", label ) end
end

// Same order on the server and on every client
for _, t in ipairs( LBR.Tiers ) do
	for _, k in ipairs( LBR.AmmoKinds ) do
		addAmmoType( LBR.TierAmmoName( t.id, k ), t.name .. " " .. LBR.AmmoKindNames[k] )
	end
end
// adrenaline shots (sg_adrenaline_fix): the count of the shots you have, as the
// medkit does with its charges. They stack and the HUD shows how many
addAmmoType( "lbr_adrenaline", "Adrenaline Shots" )

------------------------------------------------------------------------
// Giving the tier ammo to the weapons
------------------------------------------------------------------------

local NO_AMMO = { [""] = true, none = true, [-1] = true }

// grenades, molotovs, mines (by class name): never magazine weapons, even when
// their pack gives them a clip (the molotov): they keep their own ammo
local THROWABLE_WORDS = { "grenade", "nade", "molotov", "slam", "c4", "mine", "flash", "smoke" }
function LBR.IsThrowableClass( class )
	class = string.lower( class or "" )
	for _, w in ipairs( THROWABLE_WORDS ) do
		if string.find( class, w, 1, true ) then return true end
	end
	return false
end

// ammo the weapon pack gave the class (before the tiers), from the stored table
local function originalAmmo( class )
	local stored = weapons.GetStored( class )
	if not stored then return nil end
	if stored.LBR_OrigAmmo ~= nil then return stored.LBR_OrigAmmo or nil end
	local full = weapons.Get( class )
	local prim = full and full.Primary
	local ammo = prim and prim.Ammo
	if NO_AMMO[ammo] or not isstring( ammo ) or LBR.TierOfAmmoName( ammo ) or LBR.IsThrowableClass( class ) then ammo = false end
	// grenades and other one-shot weapons have no magazine: they keep their ammo
	if ammo and ( tonumber( prim.ClipSize ) or -1 ) <= 0 then ammo = false end
	stored.LBR_OrigAmmo = ammo
	return ammo or nil
end
LBR.OriginalAmmo = originalAmmo

// Pistol calibers are shot by pistols and by SMGs: the hold type (or the slot)
// of the weapon tells them apart, so the two do not share the tier ammo
local PISTOL_HOLD = { pistol = true, revolver = true, duel = true }
local function isHandgun( class )
	local w = weapons.Get( class )
	if not w then return true end
	// CW 2.0: NormalHoldType, ArcCW: HoldtypeActive, others: HoldType
	local hold = w.NormalHoldType or w.HoldtypeActive or w.HoldType
	if isstring( hold ) and hold ~= "" then return PISTOL_HOLD[string.lower( hold )] == true end
	return tonumber( w.Slot ) == 1
end

// kind of the tier ammo of a class
function LBR.AmmoKindOfClass( class )
	local orig = originalAmmo( class )
	if not orig then return nil end
	local stored = weapons.GetStored( class )
	if stored and stored.LBR_AmmoKind then return stored.LBR_AmmoKind end
	local kind = LBR.AmmoKindOfName( orig )
	if kind == "pistol" and not isHandgun( class ) then kind = "smg" end
	if stored then stored.LBR_AmmoKind = kind end
	return kind
end

// One ammo type per WEAPON ("lbr_w_cw_m4"), not per caliber: the server sets the
// reserve of each weapon from its magazine store (sh_clips.lua), so an SKS (20)
// and an M4 (30) with 2 green magazines show 40 and 60 rounds.
// The types are made on Initialize (the weapons exist only then), in the same
// order on the server and on the clients (every weapon with a magazine, sorted by
// class). If the engine runs out of ammo types (256), the weapons left use the
// tier + kind ammo ("lbr_blue_rifle").
local MAX_AMMO_TYPES = 250
local classAmmo = {} // ammo name -> class
function LBR.WeaponAmmoName( class )
	return "lbr_w_" .. string.lower( class )
end

function LBR.RegisterWeaponAmmo()
	if LBR.WeaponAmmoDone then return end
	LBR.WeaponAmmoDone = true
	local first, seen = {}, {}
	for _, w in ipairs( weapons.GetList() ) do
		local c = w.ClassName
		if c and not seen[c] and originalAmmo( c ) then
			seen[c] = true
			first[#first + 1] = c
		end
	end
	table.sort( first )
	local count = #( game.GetAmmoTypes() or {} )
	for _, c in ipairs( first ) do
		if count >= MAX_AMMO_TYPES then break end
		local name = LBR.WeaponAmmoName( c )
		local w = weapons.Get( c )
		local label = w and w.PrintName or c
		if CLIENT and isstring( label ) and string.sub( label, 1, 1 ) == "#" then label = language.GetPhrase( string.sub( label, 2 ) ) end
		addAmmoType( name, tostring( label ) )
		classAmmo[name] = c
		count = count + 1
	end
end

// tier id ("" = none) of a weapon ammo type, nil for the others
local tierOfAmmoName = LBR.TierOfAmmoName
function LBR.TierOfAmmoName( name )
	if not name then return nil end
	local t = tierOfAmmoName( name )
	if t then return t end
	local c = classAmmo[string.lower( name )]
	if c then return LBR.WeaponTier[c] or "" end
end

// ammo name a class uses now: its own (the reserve is set from the magazine
// stores, sh_clips.lua); with no room left for one more type, the tier + kind
// ammo, else the one of its pack
function LBR.AmmoForClass( class )
	local orig = originalAmmo( class )
	if not orig then return nil end
	local name = LBR.WeaponAmmoName( class )
	if classAmmo[name] then return name end
	local t = LBR.TierOfClass( class )
	if not t then return orig end
	return LBR.TierAmmoName( t.id, LBR.AmmoKindOfClass( class ) )
end

local function setPrimaryAmmo( tbl, ammo )
	tbl.Primary = tbl.Primary or {}
	tbl.Primary.Ammo = ammo
	if tbl.ArcCW then tbl.OldAmmo = ammo end // ArcCW: no ammo reset when attachments change
end

// Applies LBR.WeaponTier to the weapon tables and to the weapons already in the world
function LBR.ApplyTierAmmo()
	for _, w in ipairs( weapons.GetList() ) do
		local class = w.ClassName
		local stored = class and weapons.GetStored( class )
		if stored and originalAmmo( class ) then
			// weapons whose Primary comes from the base: copy it first, so the
			// base (and every other weapon on it) keeps its own ammo
			if not rawget( stored, "Primary" ) then
				local full = weapons.Get( class )
				stored.Primary = table.Copy( full and full.Primary or {} )
			end
			setPrimaryAmmo( stored, LBR.AmmoForClass( class ) )
		end
	end
	for _, ent in ipairs( ents.GetAll() ) do
		if IsValid( ent ) and ent:IsWeapon() and ent.Primary then
			local ammo = LBR.AmmoForClass( ent:GetClass() )
			if ammo and ent.Primary.Ammo ~= ammo then
				// ArcCW ammo conversions (attachments) stay as they are
				local cur = ent.Primary.Ammo
				if cur == originalAmmo( ent:GetClass() ) or LBR.TierOfAmmoName( cur ) then setPrimaryAmmo( ent, ammo ) end
			end
		end
	end
end

// ammo type id the weapon really uses: Primary.Ammo (the tier ammo, set after
// the weapon was created too), else what the engine has for it
function LBR.WeaponAmmoID( wep )
	local name = wep.Primary and wep.Primary.Ammo
	if isstring( name ) then
		local id = game.GetAmmoID( name )
		if id and id >= 0 then return id end
	end
	return wep:GetPrimaryAmmoType()
end

// a weapon that takes magazines (not a melee, a grenade, a molotov, a medkit...)
function LBR.UsesMagazines( wep )
	return IsValid( wep ) and wep:IsWeapon() and LBR.WeaponAmmoID( wep ) >= 0 and wep:GetMaxClip1() > 0
		and not LBR.IsThrowableClass( wep:GetClass() )
end

------------------------------------------------------------------------
// Network
------------------------------------------------------------------------

local function percentsTable()
	local out = {}
	for _, t in ipairs( LBR.Tiers ) do out[t.id] = t.percent end
	return out
end

if SERVER then
	util.AddNetworkString( "LBR_Tiers" )
	util.AddNetworkString( "LBR_Tiers_Get" )

	local function send( target )
		local data = util.Compress( util.TableToJSON( { tiers = LBR.WeaponTier, percent = percentsTable() } ) )
		if not data then return end
		net.Start( "LBR_Tiers" )
			net.WriteUInt( #data, 16 )
			net.WriteData( data, #data )
		if target then net.Send( target ) else net.Broadcast() end
	end

	// groups = loot groups (sh_loot.lua format): GREEN / BLUE / PURPLE + TIERS
	function LBR.SetTiersFromLoot( groups )
		local map = {}
		for _, t in ipairs( LBR.Tiers ) do
			for _, e in ipairs( groups[t.group] or {} ) do
				if not map[e.class] then map[e.class] = t.id end
			end
			local p = groups.TIERS and groups.TIERS[t.id]
			t.percent = math.Clamp( math.floor( tonumber( p ) or t.defaultPercent ), 1, 1000 )
		end
		LBR.WeaponTier = map
		if LBR.TiersReady then LBR.ApplyTierAmmo() end
		send()
	end

	net.Receive( "LBR_Tiers_Get", function( _, ply )
		if ( ply.LBR_TiersAsked or 0 ) > CurTime() then return end
		ply.LBR_TiersAsked = CurTime() + 2
		send( ply )
	end )
else
	net.Receive( "LBR_Tiers", function()
		local size = net.ReadUInt( 16 )
		local data = util.JSONToTable( util.Decompress( net.ReadData( size ), 1024 * 1024 ) or "" )
		if not istable( data ) then return end
		LBR.WeaponTier = istable( data.tiers ) and data.tiers or {}
		for _, t in ipairs( LBR.Tiers ) do
			t.percent = tonumber( data.percent and data.percent[t.id] ) or t.defaultPercent
		end
		LBR.ApplyTierAmmo()
	end )

	hook.Add( "InitPostEntity", "LBR_Tiers", function()
		net.Start( "LBR_Tiers_Get" )
		net.SendToServer()
	end )
end

// the weapons are registered after the gamemode files: apply on Initialize
hook.Add( "Initialize", "LBR_Tiers", function()
	LBR.RegisterWeaponAmmo()
	LBR.TiersReady = true
	LBR.ApplyTierAmmo()
end )
hook.Add( "InitPostEntity", "LBR_TiersApply", function()
	LBR.RegisterWeaponAmmo() // no-op when Initialize did it
	LBR.TiersReady = true
	LBR.ApplyTierAmmo()
end )
if GAMEMODE then
	// lua refresh: the types are already in the engine, only the tables are made again
	LBR.WeaponAmmoDone = nil
	LBR.RegisterWeaponAmmo()
	LBR.TiersReady = true
end

// a weapon created later (Give, pickup of a new class...) gets its tier ammo too
hook.Add( "OnEntityCreated", "LBR_TierAmmo", function( ent )
	timer.Simple( 0, function()
		if not IsValid( ent ) or not ent:IsWeapon() or not ent.Primary then return end
		local ammo = LBR.AmmoForClass( ent:GetClass() )
		if ammo and ent.Primary.Ammo ~= ammo then
			local cur = ent.Primary.Ammo
			if cur == originalAmmo( ent:GetClass() ) or LBR.TierOfAmmoName( cur ) then setPrimaryAmmo( ent, ammo ) end
		end
	end )
end )
