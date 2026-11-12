// Shared safe zone math.
// The server only networks the start values once per round (pos, start radius, start time, speed);
// server and clients compute the current radius from CurTime(), so nothing is sent every tick.

LBR = LBR or {}

LBR.ZoneWarnRadius = 1750 // the zone turns red and the siren starts below this radius

function LBR.GetZonePos()
	return GetGlobalVector( "LBR_ZonePos", vector_origin )
end

function LBR.IsZoneActive()
	return GetGlobalFloat( "LBR_ZoneStartRadius", 0 ) > 0
end

// units per second
function LBR.GetZoneSpeed()
	return GetGlobalFloat( "LBR_ZoneSpeed", 0 )
end

function LBR.GetZoneRadius()
	local start = GetGlobalFloat( "LBR_ZoneStartRadius", 0 )
	if start <= 0 then return 0 end
	local elapsed = math.max( CurTime() - GetGlobalFloat( "LBR_ZoneStartTime", 0 ), 0 )
	return math.max( start - elapsed * LBR.GetZoneSpeed(), 0 )
end

// seconds before the zone starts shrinking (0 once it is shrinking)
function LBR.GetZoneStartsIn()
	return math.max( GetGlobalFloat( "LBR_ZoneStartTime", 0 ) - CurTime(), 0 )
end

// seconds until the zone reaches radius 0 (the wait before it starts included)
function LBR.GetZoneTimeLeft()
	local speed = LBR.GetZoneSpeed()
	if speed <= 0 then return 0 end
	return LBR.GetZoneStartsIn() + LBR.GetZoneRadius() / speed
end

function LBR.IsPosInZone( pos )
	if not LBR.IsZoneActive() then return true end
	local r = LBR.GetZoneRadius()
	if r < 1 then return false end
	return pos:DistToSqr( LBR.GetZonePos() ) <= r * r
end

// 0 = far from the end, 1 = zone fully closed. Used for the color shift.
function LBR.GetZoneDanger()
	local r = LBR.GetZoneRadius()
	if r >= LBR.ZoneWarnRadius then return 0 end
	return 1 - r / LBR.ZoneWarnRadius
end
