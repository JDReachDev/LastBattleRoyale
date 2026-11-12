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

	// square, centered on the points
	local cx, cy = ( mins.x + maxs.x ) / 2, ( mins.y + maxs.y ) / 2
	local half = math.max( maxs.x - mins.x, maxs.y - mins.y ) / 2 + MARGIN
	SetGlobalVector( "LBR_MapMins", Vector( cx - half, cy - half, mins.z - 1000 ) )
	SetGlobalVector( "LBR_MapMaxs", Vector( cx + half, cy + half, skyZ ) )
end

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
