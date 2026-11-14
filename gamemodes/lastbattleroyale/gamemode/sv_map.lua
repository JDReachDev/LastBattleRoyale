// Server side of the map (M): map area and squad positions.
//
// Map area: found by scanning the map from above (a grid of traces going down from
// the sky ceiling: where one lands on ground there is map), so it reaches the map
// borders on any map; networked once as two global vectors. Its top is the
// sky ceiling (traced up from the points), so the client can render the map from
// above with the sky cut away.
//
// Squad positions: a teammate far away is not sent by the engine (dormant), so the
// position of each living teammate is sent to his squad 4 times per second.

LBR = LBR or {}

util.AddNetworkString( "LBR_MatePos" )

local MARGIN = 2000
local BOUND_CATS = {
	playerspawns = true, weaponspawns = true, vehiclepositions = true,
	flying_vehiclespawns = true, endpositions = true,
}

// outer box of the world brushes (the walls around the map, plus the 3D skybox room)
local function worldBounds()
	local w = game.GetWorld()
	if not IsValid( w ) then return nil end
	local ok, a, b = pcall( function() return w:GetInternalVariable( "m_WorldMins" ), w:GetInternalVariable( "m_WorldMaxs" ) end )
	if not ( ok and isvector( a ) and isvector( b ) and b.x - a.x > 1 ) then
		ok, a, b = pcall( function() return w:GetModelBounds() end )
	end
	if ok and isvector( a ) and isvector( b ) and b.x - a.x > 1 and b.y - a.y > 1 then return a, b end
	return nil
end

LBR.MapBoundCats = BOUND_CATS

// map area of a set of points: mins / maxs is the box of all the points, points
// the ones the sky is traced from (up to 64 are used). Also used by the map editor
// for the points being placed (sv_mapconfig.lua). Returns area mins, maxs, info
function LBR.ComputeMapBounds( mins, maxs, points )
	// sky ceiling: highest sky hit going straight up from a sample of the points
	local skyZ
	local step = math.max( 1, math.floor( #points / 64 ) )
	for i = 1, #points, step do
		local start = points[i] + Vector( 0, 0, 40 )
		local tr = util.TraceLine( { start = start, endpos = start + Vector( 0, 0, 65536 ), mask = MASK_SOLID_BRUSHONLY } )
		if tr.HitSky and not tr.StartSolid then
			skyZ = math.max( skyZ or -math.huge, tr.HitPos.z )
		end
	end
	if not skyZ or skyZ < maxs.z then skyZ = maxs.z + 3000 end

	// top of the outermost sky: some maps have a sky above the sky (rp_ineu_pass_v1e:
	// ceiling at ~2000, a shell at 4096). The camera of the map picture must be above
	// all of them, out of the map: between two skies it is inside a leaf of the map
	// and the engine draws only what is visible from there (map almost all black).
	// Climbs from each sky hit through the brush and on up to the next sky.
	local topZ = skyZ
	for i = 1, #points, step do
		local p = points[i] + Vector( 0, 0, 40 )
		local tr = util.TraceLine( { start = p, endpos = p + Vector( 0, 0, 65536 ), mask = MASK_SOLID_BRUSHONLY } )
		if tr.HitSky and not tr.StartSolid then
			local z = tr.HitPos.z
			for _ = 1, 16 do
				local s = Vector( p.x, p.y, z + 1 )
				local up = util.TraceLine( { start = s, endpos = s + Vector( 0, 0, 32768 ), mask = MASK_SOLID_BRUSHONLY } )
				if up.StartSolid then
					// through the brush: where the trace leaves it, else solid up to the
					// top (the void out of the map): done
					if up.AllSolid or up.FractionLeftSolid >= 1 then break end
					local left = s.z + 32768 * up.FractionLeftSolid + 1
					up = util.TraceLine( { start = Vector( p.x, p.y, left ), endpos = Vector( p.x, p.y, left + 32768 ), mask = MASK_SOLID_BRUSHONLY } )
					if up.StartSolid or not up.Hit then break end
				elseif not up.Hit then
					break
				end
				if up.HitSky then topZ = math.max( topZ, up.HitPos.z ) end
				z = up.HitPos.z
			end
		end
	end
	SetGlobalFloat( "LBR_SkyTop", math.min( topZ, 15000 ) )

	// Map area: scan the map from above. A grid of traces goes down from the sky
	// ceiling; where one lands on ground there is map. Outside the outer walls the
	// trace starts in the void (StartSolid) and is skipped, so the area stops at the
	// map borders, whatever the shape of the map. The 3D skybox room (a small copy
	// of the scenery somewhere in the world) is skipped around the sky_camera.
	local wmins, wmaxs = worldBounds()
	local sx1, sy1, sx2, sy2
	if wmins then
		sx1, sy1, sx2, sy2 = wmins.x, wmins.y, wmaxs.x, wmaxs.y
	else
		sx1, sy1, sx2, sy2 = mins.x - 12000, mins.y - 12000, maxs.x + 12000, maxs.y + 12000
	end
	sx1, sy1 = math.max( sx1, -16384 ), math.max( sy1, -16384 )
	sx2, sy2 = math.min( sx2, 16384 ), math.min( sy2, 16384 )

	local sky = ents.FindByClass( "sky_camera" )[1]
	local skyPos = IsValid( sky ) and sky:GetPos()
	local function isSkyboxRoom( x, y )
		if not skyPos then return false end
		if x >= mins.x - MARGIN and x <= maxs.x + MARGIN and y >= mins.y - MARGIN and y <= maxs.y + MARGIN then return false end
		return math.abs( x - skyPos.x ) < 4000 and math.abs( y - skyPos.y ) < 4000
	end

	local N = 96
	local cw, ch = ( sx2 - sx1 ) / N, ( sy2 - sy1 ) / N
	local bottom = mins.z - 6000
	local x1, y1, x2, y2 = mins.x, mins.y, maxs.x, maxs.y
	local hits = 0
	for i = 0, N - 1 do
		local x = sx1 + ( i + 0.5 ) * cw
		for j = 0, N - 1 do
			local y = sy1 + ( j + 0.5 ) * ch
			if not isSkyboxRoom( x, y ) then
				local tr = util.TraceLine( { start = Vector( x, y, skyZ - 8 ), endpos = Vector( x, y, bottom ), mask = MASK_SOLID_BRUSHONLY } )
				if tr.StartSolid then
					// lower sky here: try again from just above the highest point
					tr = util.TraceLine( { start = Vector( x, y, maxs.z + 200 ), endpos = Vector( x, y, bottom ), mask = MASK_SOLID_BRUSHONLY } )
				end
				if not tr.StartSolid and tr.Hit and not tr.HitSky and not tr.HitNoDraw then
					hits = hits + 1
					x1, y1 = math.min( x1, x - cw / 2 ), math.min( y1, y - ch / 2 )
					x2, y2 = math.max( x2, x + cw / 2 ), math.max( y2, y + ch / 2 )
				end
			end
		end
	end
	if hits == 0 then
		x1, y1, x2, y2 = mins.x - MARGIN, mins.y - MARGIN, maxs.x + MARGIN, maxs.y + MARGIN
	end

	return Vector( x1, y1, mins.z - 1000 ), Vector( x2, y2, skyZ ),
		string.format( "map area x %d..%d  y %d..%d  sky %d  outer sky %d  ground cells %d/%d  scanned x %d..%d y %d..%d (world bounds %s)",
		x1, x2, y1, y2, skyZ, topZ, hits, N * N, sx1, sx2, sy1, sy2, wmins and "found" or "not found" )
end

function LBR.UpdateMapBounds()
	local cfg = LBR.GetMapConfig and LBR.GetMapConfig()
	local points = {}
	if istable( cfg ) then
		for _, cat in ipairs( LBR.MapCategories or {} ) do
			if BOUND_CATS[cat.key] then
				for _, p in ipairs( LBR.GetCategoryList( cfg, cat ) ) do
					if isvector( p ) then points[#points + 1] = p end
				end
			end
		end
	end
	if #points == 0 then
		SetGlobalVector( "LBR_MapMins", vector_origin )
		SetGlobalVector( "LBR_MapMaxs", vector_origin )
		return
	end

	local mins = Vector( math.huge, math.huge, math.huge )
	local maxs = Vector( -math.huge, -math.huge, -math.huge )
	for _, p in ipairs( points ) do
		mins.x, mins.y, mins.z = math.min( mins.x, p.x ), math.min( mins.y, p.y ), math.min( mins.z, p.z )
		maxs.x, maxs.y, maxs.z = math.max( maxs.x, p.x ), math.max( maxs.y, p.y ), math.max( maxs.z, p.z )
	end

	local a, b, info = LBR.ComputeMapBounds( mins, maxs, points )
	SetGlobalVector( "LBR_MapMins", a )
	SetGlobalVector( "LBR_MapMaxs", b )
	LBR.MapBoundsInfo = info
end

concommand.Add( "lbr_map_info", function( ply )
	if IsValid( ply ) and not ply:IsAdmin() then return end
	local msg = "[LBR] " .. ( LBR.MapBoundsInfo or "no map area (no configured points)" )
	if IsValid( ply ) then ply:PrintMessage( HUD_PRINTCONSOLE, msg ) else print( msg ) end
end )

// the world must be loaded for the sky traces
hook.Add( "InitPostEntity", "LBR_MapBounds", function()
	timer.Simple( 1, LBR.UpdateMapBounds )
end )
if game.GetWorld and IsValid( game.GetWorld() ) then timer.Simple( 0, LBR.UpdateMapBounds ) end // lua refresh

// squad positions
timer.Create( "LBR_MatePos", 0.25, 0, function()
	local alive = {}
	for _, pl in ipairs( player.GetAll() ) do
		local sid = pl:SteamID64()
		if sid and pl:Alive() and pl:Team() == 2 then alive[sid] = pl end
	end
	for _, ply in ipairs( player.GetHumans() ) do
		local list = ply.TeamingPlayers
		if istable( list ) and #list > 0 then
			local send = {}
			for i = 1, math.min( #list, 3 ) do
				local mate = alive[list[i]]
				if mate and mate ~= ply then send[#send + 1] = mate end
			end
			if #send > 0 then
				net.Start( "LBR_MatePos", true ) // unreliable: a lost update is replaced 0.25s later
					net.WriteUInt( #send, 3 )
					for _, mate in ipairs( send ) do
						local pos = mate:GetPos()
						net.WriteString( mate:SteamID64() or "" )
						net.WriteFloat( pos.x )
						net.WriteFloat( pos.y )
						net.WriteInt( math.Round( mate:EyeAngles().y ), 10 )
					end
				net.Send( ply )
			end
		end
	end
end )

------------------------------------------------------------------------
// Map marks: supply drops, nuke target, squad markers (pings), fallen teammates
------------------------------------------------------------------------

util.AddNetworkString( "LBR_MapDrops" )
util.AddNetworkString( "LBR_MapPing" )
util.AddNetworkString( "LBR_MateDeath" )

// supply drops still to open (a far crate is not sent by the engine): sent when the
// list changes, and every 5 s for players who just joined
local lastDrops, nextDropsSend = "", 0
timer.Create( "LBR_MapDrops", 1, 0, function()
	local list = {}
	for _, e in ipairs( ents.FindByClass( "ent_supplydrop_fix" ) ) do
		if not e.LBR_Looted then list[#list + 1] = e:GetPos() end
		if #list >= 31 then break end
	end
	local sig = ""
	for _, p in ipairs( list ) do sig = sig .. math.floor( p.x / 64 ) .. "," .. math.floor( p.y / 64 ) .. ";" end
	if sig == lastDrops and CurTime() < nextDropsSend then return end
	lastDrops, nextDropsSend = sig, CurTime() + 5
	net.Start( "LBR_MapDrops" )
		net.WriteUInt( #list, 5 )
		for _, p in ipairs( list ) do
			net.WriteFloat( p.x )
			net.WriteFloat( p.y )
		end
	net.Broadcast()
end )

// the nuke target on the map is set by LBR.Nuke (sv_events.lua)

// players of the squad of ply (ply included)
local function squadOf( ply )
	local out = { ply }
	for _, sid in ipairs( ply.TeamingPlayers or {} ) do
		local pl = player.GetBySteamID64( sid )
		if IsValid( pl ) and pl ~= ply then out[#out + 1] = pl end
	end
	return out
end

// squad marker: left click on the map sets it, right click removes it
net.Receive( "LBR_MapPing", function( len, ply )
	if ( ply.LBR_PingNext or 0 ) > CurTime() then return end
	ply.LBR_PingNext = CurTime() + 0.25
	local set = net.ReadBool()
	local pos
	if set then
		local x, y = net.ReadFloat(), net.ReadFloat()
		local mins, maxs = GetGlobalVector( "LBR_MapMins" ), GetGlobalVector( "LBR_MapMaxs" )
		if maxs.x - mins.x < 100 or x ~= x or y ~= y then return end
		x, y = math.Clamp( x, mins.x, maxs.x ), math.Clamp( y, mins.y, maxs.y )
		// ground under the marker, for the marker on screen
		local tr = util.TraceLine( { start = Vector( x, y, maxs.z - 8 ), endpos = Vector( x, y, mins.z - 6000 ), mask = MASK_SOLID_BRUSHONLY } )
		local z = ( tr.Hit and not tr.StartSolid ) and tr.HitPos.z or ply:GetPos().z
		pos = Vector( x, y, z )
	end
	net.Start( "LBR_MapPing" )
		net.WriteString( ply:SteamID64() or "" )
		net.WriteBool( pos ~= nil )
		if pos then net.WriteVector( pos ) end
	net.Send( squadOf( ply ) )
end )

// where a teammate fell
hook.Add( "PlayerDeath", "LBR_MapMateDeath", function( victim )
	if not IsValid( victim ) or not victim.TeamingPlayers or #victim.TeamingPlayers == 0 then return end
	local p = victim:GetPos()
	local to = squadOf( victim )
	table.remove( to, 1 )
	if #to == 0 then return end
	net.Start( "LBR_MateDeath" )
		net.WriteString( victim:SteamID64() or "" )
		net.WriteFloat( p.x )
		net.WriteFloat( p.y )
	net.Send( to )
end )
