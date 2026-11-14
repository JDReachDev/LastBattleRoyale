// Magazines by color: the ammo of a player is not per weapon but three stores of
// magazines, one per tier color (green / blue / purple, see sh_tiers.lua). The
// stores hold fractions (2.5 = two magazines and a half).
// - The reserve of a weapon is its store x its magazine size: with 2.5 green
//   magazines a green M4 (30) shows 75 rounds, a green SKS (20) 50. Weapons
//   without a tier (the class loadouts) use the green store.
// - Reloading takes the part of a magazine you loaded: 15 rounds in an M4 = 0.5,
//   5 shells in an 8 shell shotgun = 0.625.
// - Ammo given by anything else (a weapon picked up with rounds in reserve,
//   extra ammo of the Loot editor) goes in the store the same way.
// - Right click in TAB: unload a weapon into its store (10 rounds of an M4 =
//   0.33), drop one magazine / the part after the point / all of a color in a box
//   on the ground (lbr_ammo_box): anyone takes it with E, one magazine at a time.
// - When you die, your magazines fall in one box per color.
// - Each color has a limit (lbr_clips_max_green / _blue / _purple, 10 / 8 / 6,
//   0 = no limit): boxes and kits give only up to it, the rest stays there.
// How it works: every weapon with a magazine has its own engine ammo type
// (sh_tiers.lua). The server sets the reserve of each weapon from its store, then
// every tick reads it back: what went down (reload) or up (ammo given) is moved
// to the store in magazines of that weapon.

LBR = LBR or {}

local EPS = 0.0001

local MAX_DEFAULT = { green = 10, blue = 8, purple = 6 }
for color, n in pairs( MAX_DEFAULT ) do
	if not ConVarExists( "lbr_clips_max_" .. color ) then
		CreateConVar( "lbr_clips_max_" .. color, tostring( n ), { FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED }, "Most " .. color .. " magazines a player carries, 0 = no limit" )
	end
end

// color ids, in the order of LBR.Tiers ("green", "blue", "purple")
function LBR.ClipColors()
	local out = {}
	for _, t in ipairs( LBR.Tiers or {} ) do out[#out + 1] = t.id end
	return out
end

// store a weapon uses: its tier, the first color for weapons without one
function LBR.ClipColorOf( wep )
	local t = LBR.TierOf( wep )
	if t then return t.id end
	return LBR.Tiers and LBR.Tiers[1] and LBR.Tiers[1].id or "green"
end

function LBR.ClipTier( color )
	return LBR.TierById and LBR.TierById[color]
end

function LBR.GetClips( ply, color )
	if SERVER and ply.LBR_Clips then return ply.LBR_Clips[color] or 0 end
	return ply:GetNW2Float( "LBR_Clips_" .. color, 0 )
end

// most magazines of a color a player carries (math.huge: no limit)
function LBR.ClipMax( color )
	local cv = GetConVar( "lbr_clips_max_" .. color )
	local n = cv and cv:GetFloat() or 0
	return n > 0 and n or math.huge
end

// magazines of a color you can still take
function LBR.ClipRoom( ply, color )
	return math.max( LBR.ClipMax( color ) - LBR.GetClips( ply, color ), 0 )
end

// "x2", "x2 / 10" with a limit
function LBR.ClipLimitText( color )
	local m = LBR.ClipMax( color )
	return m < math.huge and ( " / " .. LBR.ClipText( m ) ) or ""
end

// "2.5", "1", "0.3": one decimal is enough to read (the store keeps the exact value)
function LBR.ClipText( n )
	if n < EPS then return "0" end
	if n < 0.05 then return "0.1" end // a crumb left: not shown as 0
	local s = string.format( "%.1f", n )
	s = string.gsub( s, "0+$", "" )
	s = string.gsub( s, "%.$", "" )
	return s
end

// part of a magazine the loaded rounds of wep are worth (unload)
function LBR.ClipValueOfLoaded( wep )
	local size = wep:GetMaxClip1()
	if size <= 0 then return 0 end
	return math.max( wep:Clip1(), 0 ) / size
end

if CLIENT then
	// last time someone else hurt you (the kit menu closes, the zone damage does not count)
	LBR.LastEnemyHit = LBR.LastEnemyHit or 0
	net.Receive( "LBR_EnemyHit", function() LBR.LastEnemyHit = CurTime() end )

	// a magazine: a frame leaning right at the top that fills from the bottom: full
	// from 1 magazine up, 0.8 = 80%, empty at 0. Drawn in a size x size box in the color c
	local function quad( cx, hw, t0, t1, y0, y1 )
		// slice of the body between t0 and t1 (0 top, 1 bottom), clockwise
		return {
			{ x = cx( t0 ) - hw( t0 ), y = y0 }, { x = cx( t0 ) + hw( t0 ), y = y0 },
			{ x = cx( t1 ) + hw( t1 ), y = y1 }, { x = cx( t1 ) - hw( t1 ), y = y1 },
		}
	end
	// low / lowColor (optional): the bottom part of the fill, up to low, in another
	// color (ammo kit: what stays in the kit under what a pick takes)
	function LBR.DrawClipIcon( x, y, size, c, alpha, fill, low, lowColor )
		alpha = alpha or 255
		fill = math.Clamp( fill or 1, 0, 1 )
		local top, bot = y + size * 0.04, y + size * 0.96
		local function cx( t ) return x + size * ( 0.6 - 0.2 * t ) end // leans right
		local function hw( t ) return size * 0.2 end // same width top and bottom
		local th = math.max( math.floor( size * 0.09 ), 2 ) // frame
		local function ihw( t ) return math.max( hw( t ) - th, 1 ) end
		local function ty( t ) return top + ( bot - top ) * t end
		draw.NoTexture()
		// dark edge, frame, dark inside, fill
		surface.SetDrawColor( 0, 0, 0, alpha * 0.6 )
		surface.DrawPoly( quad( cx, function( t ) return hw( t ) + 1 end, 0, 1, top - 1, bot + 1 ) )
		surface.SetDrawColor( c.r, c.g, c.b, fill > 0 and alpha or alpha * 0.5 )
		surface.DrawPoly( quad( cx, hw, 0, 1, top, bot ) )
		local it, ib = th / ( bot - top ), 1 - th / ( bot - top )
		surface.SetDrawColor( 0, 0, 0, alpha * 0.75 )
		surface.DrawPoly( quad( cx, ihw, it, ib, ty( it ), ty( ib ) ) )
		if fill > 0 then
			// a 1 px gap from the frame, so a full one still reads as a magazine
			local function fhw( t ) return math.max( ihw( t ) - 1, 1 ) end
			local ft, fb = it + 1 / ( bot - top ), ib - 1 / ( bot - top )
			local tf = fb - ( fb - ft ) * fill
			surface.SetDrawColor( c.r, c.g, c.b, alpha )
			surface.DrawPoly( quad( cx, fhw, tf, fb, ty( tf ), ty( fb ) ) )
			low = math.Clamp( low or 0, 0, fill )
			if low > 0 and lowColor then
				local tl = fb - ( fb - ft ) * low
				surface.SetDrawColor( lowColor.r, lowColor.g, lowColor.b, alpha )
				surface.DrawPoly( quad( cx, fhw, tl, fb, ty( tl ), ty( fb ) ) )
			end
		end
	end
	return
end

util.AddNetworkString( "LBR_ClipDrop" )
util.AddNetworkString( "LBR_EnemyHit" )

// hurt by another player / NPC (not the zone, not a fall, not yourself): the
// client closes the kit menu so you can fight back
hook.Add( "PlayerHurt", "LBR_EnemyHit", function( ply, attacker )
	if not IsValid( attacker ) or attacker == ply or attacker:IsWorld() then return end
	net.Start( "LBR_EnemyHit" )
	net.Send( ply )
end )

local function store( ply )
	ply.LBR_Clips = ply.LBR_Clips or {}
	return ply.LBR_Clips
end

local function publish( ply, color )
	ply:SetNW2Float( "LBR_Clips_" .. color, store( ply )[color] or 0 )
end

// adds n magazines (negative: takes them) to a store, up to the limit of the
// color; the weapons follow on the next tick. Returns what was really added
function LBR.ClipAdd( ply, color, n )
	if not LBR.ClipTier( color ) then return 0 end
	local s = store( ply )
	local old = s[color] or 0
	local v = math.min( old + n, math.max( LBR.ClipMax( color ), old ) )
	if v < EPS then v = 0 end
	s[color] = v
	ply.LBR_ClipDirty = true
	publish( ply, color )
	return v - old
end

function LBR.ClipReset( ply )
	ply.LBR_Clips = {}
	ply.LBR_ClipSet = {}
	ply.LBR_ClipDirty = true
	for _, c in ipairs( LBR.ClipColors() ) do publish( ply, c ) end
end

// ammo ids the server set for this player: id -> { v = rounds set, c = color, size = magazine }
local function tracked( ply )
	ply.LBR_ClipSet = ply.LBR_ClipSet or {}
	return ply.LBR_ClipSet
end

// what went down (reload, shots of a weapon without magazine reload) or up (ammo
// given) since the last tick goes to the store
local function readBack( ply )
	local set = tracked( ply )
	for id, rec in pairs( set ) do
		local now = ply:GetAmmoCount( id )
		if now ~= rec.v then
			local s = store( ply )
			local old = s[rec.c] or 0
			local v = old + ( now - rec.v ) / rec.size
			if v > old then v = math.min( v, math.max( LBR.ClipMax( rec.c ), old ) ) end // ammo given: up to the limit
			if v < EPS then v = 0 end
			s[rec.c] = v
			rec.v = now
			ply.LBR_ClipDirty = true
			publish( ply, rec.c )
		end
	end
end

// the reserve of every weapon from its store
local seenIds = {}
local function apply( ply )
	ply.LBR_ClipDirty = false
	local set = tracked( ply )
	local s = store( ply )
	local act = ply:GetActiveWeapon()
	for k in pairs( seenIds ) do seenIds[k] = nil end
	local weps = ply:GetWeapons()
	// the weapon in hand last: if two weapons share an ammo type, its size wins
	for i = 1, #weps + 1 do
		local w = weps[i]
		if i > #weps then w = act elseif w == act then w = nil end
		if IsValid( w ) and LBR.UsesMagazines( w ) then
			local id = LBR.WeaponAmmoID( w )
			local color = LBR.ClipColorOf( w )
			local size = math.max( w:GetMaxClip1(), 1 )
			local rec = set[id]
			if not rec then
				// a new weapon: the reserve it came with goes in the store
				local have = ply:GetAmmoCount( id )
				if have > 0 then
					local old = s[color] or 0
					s[color] = math.min( old + have / size, math.max( LBR.ClipMax( color ), old ) )
					publish( ply, color )
				end
				rec = {}
				set[id] = rec
			end
			local v = math.floor( ( s[color] or 0 ) * size + EPS )
			rec.c, rec.size, rec.v = color, size, v
			if ply:GetAmmoCount( id ) ~= v then ply:SetAmmo( v, id ) end
			seenIds[id] = true
		end
	end
	// weapons gone (dropped, thrown): their reserve is not theirs any more
	for id in pairs( set ) do
		if not seenIds[id] then
			set[id] = nil
			if ply:GetAmmoCount( id ) > 0 then ply:SetAmmo( 0, id ) end
		end
	end
end

function LBR.ClipSync( ply )
	readBack( ply )
	apply( ply )
end

local nextFull = 0
hook.Add( "Tick", "LBR_Clips", function()
	local full = CurTime() >= nextFull // weapons picked up / lost: checked twice a second
	if full then nextFull = CurTime() + 0.5 end
	for _, ply in ipairs( player.GetAll() ) do
		if ply:Alive() then
			readBack( ply )
			if full or ply.LBR_ClipDirty then apply( ply ) end
		end
	end
end )

hook.Add( "WeaponEquip", "LBR_Clips", function( wep, ply )
	if IsValid( ply ) then ply.LBR_ClipDirty = true end
end )

// a new life starts with empty stores (the loadouts remove all the ammo first,
// then the ammo they give goes in the stores)
hook.Add( "PlayerSpawn", "LBR_Clips", function( ply )
	LBR.ClipReset( ply )
end )

------------------------------------------------------------------------
// Boxes on the ground
------------------------------------------------------------------------

local MERGE_DIST = 90

// a box of n magazines of a color at pos; dropped next to a box of the same
// color, it goes in that box. life: seconds before it disappears (nil = default)
function LBR.ClipBox( color, n, pos, vel, life )
	if n < EPS or not LBR.ClipTier( color ) then return end
	for _, e in ipairs( ents.FindInSphere( pos, MERGE_DIST ) ) do
		if e:GetClass() == "lbr_ammo_box" and not e.Taken and e:GetTier() == color then
			e:SetAmount( e:GetAmount() + n )
			e:Refresh( life )
			return e
		end
	end
	local box = ents.Create( "lbr_ammo_box" )
	if not IsValid( box ) then return end
	box:SetPos( pos )
	box:SetAngles( Angle( 0, math.random( 0, 359 ), 0 ) )
	box:SetTier( color )
	box:SetAmount( n )
	box.Life = life
	box:Spawn()
	local phys = box:GetPhysicsObject()
	if IsValid( phys ) and vel then phys:SetVelocity( vel ) end
	return box
end

// right click in TAB on a magazine color: 1 = one magazine, 2 = the part after
// the point, 3 = all of them
net.Receive( "LBR_ClipDrop", function( _, ply )
	local color = net.ReadString()
	local what = net.ReadUInt( 2 )
	if not ply:Alive() or not LBR.ClipTier( color ) then return end
	if ( ply.LBR_ClipDropNext or 0 ) > CurTime() then return end
	ply.LBR_ClipDropNext = CurTime() + 0.25
	LBR.ClipSync( ply )
	local have = store( ply )[color] or 0
	local n
	if what == 1 then n = math.min( 1, have )
	elseif what == 2 then n = have - math.floor( have + EPS )
	else n = have end
	if n < EPS then return end
	LBR.ClipAdd( ply, color, -n )
	LBR.ClipSync( ply )
	LBR.ClipBox( color, n, ply:GetShootPos() + ply:GetAimVector() * 20, ply:GetVelocity() + ply:GetAimVector() * 250 )
	ply:EmitSound( "items/ammo_pickup.wav", 60, 80 )
end )

// death: one box per color, they stay until the round ends
hook.Add( "PlayerDeath", "LBR_Clips", function( ply )
	readBack( ply )
	local s = store( ply )
	local pos = ply:GetPos() + Vector( 0, 0, 20 )
	for i, color in ipairs( LBR.ClipColors() ) do
		local n = s[color] or 0
		if n >= EPS then
			local a = i / 3 * math.pi * 2
			LBR.ClipBox( color, n, pos + Vector( math.cos( a ) * 14, math.sin( a ) * 14, 0 ), nil, 0 )
		end
	end
	ply:RemoveAllAmmo()
	LBR.ClipReset( ply )
end )
