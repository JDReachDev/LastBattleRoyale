// Server side of the map (M): map area and squad positions.
//
// Map area: the box around the configured points (spawns, loot, cars, zone centers)
// plus a margin, made square, networked once as two global vectors. Its top is the
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

	// The whole world, up to its outer walls (not a square: most maps are rectangles).
	// The 3D skybox room is part of the world too and is usually off to one side:
	// on the side where the sky_camera is, stop a little after the configured points.
	local x1, y1 = mins.x - MARGIN, mins.y - MARGIN
	local x2, y2 = maxs.x + MARGIN, maxs.y + MARGIN
	local wmins, wmaxs = worldBounds()
	if wmins then
		local sky = ents.FindByClass( "sky_camera" )[1]
		local sp = IsValid( sky ) and sky:GetPos()
		if not ( sp and sp.x < x1 ) then x1 = math.min( x1, wmins.x ) end
		if not ( sp and sp.y < y1 ) then y1 = math.min( y1, wmins.y ) end
		if not ( sp and sp.x > x2 ) then x2 = math.max( x2, wmaxs.x ) end
		if not ( sp and sp.y > y2 ) then y2 = math.max( y2, wmaxs.y ) end
		// never past the world walls
		x1, y1 = math.max( x1, wmins.x ), math.max( y1, wmins.y )
		x2, y2 = math.min( x2, wmaxs.x ), math.min( y2, wmaxs.y )
	end
	SetGlobalVector( "LBR_MapMins", Vector( x1, y1, mins.z - 1000 ) )
	SetGlobalVector( "LBR_MapMaxs", Vector( x2, y2, skyZ ) )
	LBR.MapBoundsInfo = string.format( "map area x %d..%d  y %d..%d  sky %d  (world bounds: %s)",
		x1, x2, y1, y2, skyZ, wmins and ( tostring( wmins ) .. " / " .. tostring( wmaxs ) ) or "not found" )
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
