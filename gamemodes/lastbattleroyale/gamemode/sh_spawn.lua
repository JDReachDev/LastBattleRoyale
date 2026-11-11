// Safe spawn positions (shared: the server uses it to spawn, the editor to preview).
//
// Before, players and items were put exactly on the saved point. A point a few units
// under the floor (uneven terrain, displacements, points taken with getpos) or too close
// to a wall made players stuck in the floor/wall and items fall through the ground, so
// points had to be placed higher by hand. Now every spawn:
//   0. if the box fits at the point, uses it exactly as before (working points don't move),
//   1. otherwise looks for the floor under (or just above) the point,
//   2. checks that the hull fits there,
//   3. if not, searches the closest free spot around it (in sight of the point).

LBR = LBR or {}

LBR.PlayerHullMins = Vector( -16, -16, 0 )
LBR.PlayerHullMaxs = Vector( 16, 16, 72 )

local UP_SEARCH = 40     // how far above the point the floor is searched (point buried in the floor)
local DOWN_SEARCH = 160  // how far below the point the floor is searched (point in the air)
local LIFT = 2           // gap between the floor and the hull

local rings = { 20, 36, 52, 72, 96 }
local dirs = {}
for i = 0, 7 do
	local a = math.rad( i * 45 )
	dirs[#dirs + 1] = Vector( math.cos( a ), math.sin( a ), 0 )
end

// floor height under pos; nil when there is no floor in range
function LBR.FindGround( pos, mask, filter )
	mask = mask or MASK_PLAYERSOLID
	local start = pos + Vector( 0, 0, UP_SEARCH )
	local tr = util.TraceLine( { start = start, endpos = pos - Vector( 0, 0, DOWN_SEARCH ), mask = mask, filter = filter } )
	if tr.StartSolid then
		// something right above the point (low ceiling, table): start from the point itself
		tr = util.TraceLine( { start = pos + Vector( 0, 0, 2 ), endpos = pos - Vector( 0, 0, DOWN_SEARCH ), mask = mask, filter = filter } )
		if tr.StartSolid then return nil end
	end
	if not tr.Hit or tr.HitSky then return nil end
	return tr.HitPos
end

local function hullFree( pos, mins, maxs, mask, filter )
	local tr = util.TraceHull( { start = pos, endpos = pos, mins = mins, maxs = maxs, mask = mask, filter = filter } )
	return not tr.StartSolid and not tr.Hit
end

local function visible( a, b, mask, filter )
	local tr = util.TraceLine( { start = a, endpos = b, mask = mask, filter = filter } )
	return not tr.Hit
end

// candidate = point on the floor where the bottom of the hull (mins.z) touches the floor
local function onFloor( pos, mins, mask, filter )
	local ground = LBR.FindGround( pos, mask, filter )
	if not ground then return nil end
	return ground + Vector( 0, 0, LIFT - mins.z )
end

// Returns a position where a box (mins, maxs) fits on the floor near pos.
// ok = false when no free spot was found (pos is then the best guess).
function LBR.FindSafePos( pos, mins, maxs, mask, filter )
	mins = mins or LBR.PlayerHullMins
	maxs = maxs or LBR.PlayerHullMaxs
	mask = mask or MASK_PLAYERSOLID

	// a point that already works is used exactly as before (existing maps stay the same)
	if hullFree( pos, mins, maxs, mask, filter ) then return pos, true end

	local base = onFloor( pos, mins, mask, filter ) or pos
	if hullFree( base, mins, maxs, mask, filter ) then return base, true end

	// try a bit higher first (stairs, small props on the floor)
	for _, h in ipairs( { 8, 18 } ) do
		local p = base + Vector( 0, 0, h )
		if hullFree( p, mins, maxs, mask, filter ) then return p, true end
	end

	local eye = base + Vector( 0, 0, math.max( 8, ( maxs.z - mins.z ) * 0.5 ) )
	for _, r in ipairs( rings ) do
		for _, d in ipairs( dirs ) do
			local p = onFloor( base + d * r, mins, mask, filter )
			if p and math.abs( p.z - base.z ) < 64 and hullFree( p, mins, maxs, mask, filter )
				and visible( eye, p + Vector( 0, 0, eye.z - base.z ), MASK_SOLID_BRUSHONLY ) then
				return p, true
			end
		end
	end
	return base + Vector( 0, 0, 8 ), false
end

if SERVER then
	// Put a player on a safe spot near pos (other players count as obstacles, so
	// players sharing the same point are spread around it instead of stacked).
	function LBR.PlacePlayer( ply, pos )
		local mins, maxs = ply:GetHull()
		local safe = LBR.FindSafePos( pos, mins, maxs, MASK_PLAYERSOLID, ply )
		ply:SetPos( safe )
		ply:SetVelocity( -ply:GetVelocity() )
		return safe
	end

	// Rest a freshly spawned entity on the floor under pos (its model is known only after Spawn)
	function LBR.PlaceOnFloor( ent, pos )
		if not IsValid( ent ) then return end
		local mins, maxs = ent:OBBMins(), ent:OBBMaxs()
		local safe = LBR.FindSafePos( pos, mins, maxs, MASK_SOLID, ent )
		ent:SetPos( safe )
		local phys = ent:GetPhysicsObject()
		if IsValid( phys ) then
			phys:SetPos( safe )
			phys:Wake()
		end
	end

	// Vehicles are moved before Spawn (moving SCars/WAC after Spawn can leave parts behind):
	// only lift the point when it is under the floor; working points are not touched.
	function LBR.VehicleSpawnPos( pos, minHeight )
		local ground = LBR.FindGround( pos, MASK_SOLID )
		if not ground then return pos end
		if pos.z < ground.z then
			return Vector( pos.x, pos.y, ground.z + minHeight )
		end
		return pos
	end
end
