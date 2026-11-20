// Spawn intro: when the match starts the camera begins high in the sky right above
// the player, looking straight down, dives towards him and in the last moment turns
// into his eyes (first person). Then the player takes control.
// The server freezes the players for the same time (lbr_spawn_intro seconds, 0 = off)
// and sends the length with LST_RoundStart.

LBR = LBR or {}

local MAX_HEIGHT = 6000  // highest start above the player (the sky is lower on most maps)
local PRE_HEIGHT = 140   // where the dive ends, above the head, before turning into the eyes

local active, startTime, length = false, 0, 4
local topZ // start height, found once the player is at his spawn point

local function easeInOut( t ) return t < 0.5 and 4 * t * t * t or 1 - ( -2 * t + 2 ) ^ 3 / 2 end
local function easeOut( t ) return 1 - ( 1 - t ) ^ 3 end

// first sky above pos: the dive starts there (just under it). Roofs on the way are
// passed through, the white flash at the end covers that
local function findTop( pos )
	local start = pos
	for _ = 1, 6 do
		local tr = util.TraceLine( { start = start, endpos = start + Vector( 0, 0, 16384 ), mask = MASK_SOLID_BRUSHONLY } )
		if tr.HitSky then return math.max( math.min( tr.HitPos.z - 48, pos.z + MAX_HEIGHT ), pos.z ) end
		if not tr.Hit then break end
		start = tr.HitPos + Vector( 0, 0, 8 )
		// find the top side of this roof
		local back = util.TraceLine( { start = start + Vector( 0, 0, 2048 ), endpos = start, mask = MASK_SOLID_BRUSHONLY } )
		if back.StartSolid or not back.Hit then break end
		start = back.HitPos + Vector( 0, 0, 4 )
	end
	return pos.z + 1500 // no sky found: a fixed height
end

// clear space right above the head (indoors the dive stops under the ceiling)
local function headroom( eye )
	local tr = util.TraceLine( { start = eye, endpos = eye + Vector( 0, 0, PRE_HEIGHT ), mask = MASK_SOLID_BRUSHONLY } )
	return math.max( ( tr.HitPos.z - eye.z ) - 12, 0 )
end

function LBR.SpawnIntroActive()
	return active
end

local function progress()
	return math.Clamp( ( CurTime() - startTime ) / length, 0, 1 )
end

net.Receive( "LST_RoundStart", function()
	local len = net.ReadFloat()
	print( "Round has started" )
	if not len or len <= 0 then return end
	local lp = LocalPlayer()
	if not IsValid( lp ) or not lp:Alive() or lp:Team() == TEAM_SPEC then return end
	active, startTime, length, topZ = true, CurTime(), len, nil
	surface.PlaySound( "ambient/wind/wind_snippet2.wav" )
	timer.Create( "LBR_SpawnIntroWhoosh", len * 0.62, 1, function()
		if active then surface.PlaySound( "ambient/wind/windgust.wav" ) end
	end )
end )

local function stop()
	active = false
	timer.Remove( "LBR_SpawnIntroWhoosh" )
end

hook.Add( "CalcView", "LBR_SpawnIntro", function( ply, origin, angles, fov )
	if not active then return end
	local t = progress()
	if t >= 1 or not ply:Alive() then stop() return end

	local eye = ply:EyePos()
	// the position of the player reaches the client a moment after the message:
	// the start height is picked after a few frames at the top
	if not topZ or t < 0.05 then topZ = findTop( eye ) end
	local top = Vector( eye.x, eye.y, topZ )
	local pre = eye + Vector( 0, 0, headroom( eye ) )
	local yaw = angles.y
	local down = Angle( 89, yaw, 0 )

	local pos, ang, f
	if t < 0.12 then
		// hold up high: a slow turn while looking down on the map
		pos, ang = top, Angle( 89, yaw - ( 0.12 - t ) * 120, 0 )
		f = fov
	elseif t < 0.78 then
		// the dive
		local k = easeInOut( ( t - 0.12 ) / 0.66 )
		pos, ang = LerpVector( k, top, pre ), down
		f = fov + math.sin( k * math.pi ) * 12 // a bit wider at full speed
	else
		// turn into the eyes
		local k = easeOut( ( t - 0.78 ) / 0.22 )
		pos, ang = LerpVector( k, pre, eye ), LerpAngle( k, down, angles )
		f = fov
	end

	return { origin = pos, angles = ang, fov = f, drawviewer = t < 0.93 }
end )

// no weapon in front of the camera while it is up in the sky
hook.Add( "PreDrawViewModel", "LBR_SpawnIntro", function()
	if active and progress() < 0.93 then return true end
end )

// cinematic bars and a white flash when the camera enters the eyes
hook.Add( "HUDPaint", "LBR_SpawnIntro", function()
	if not active then return end
	local t = progress()
	local w, h = ScrW(), ScrH()
	local bar = math.floor( h * 0.09 * ( 1 - math.Clamp( ( t - 0.8 ) / 0.2, 0, 1 ) ) )
	if bar > 0 then
		surface.SetDrawColor( 0, 0, 0, 255 )
		surface.DrawRect( 0, 0, w, bar )
		surface.DrawRect( 0, h - bar, w, bar )
	end
	local flash = 1 - math.abs( t - 0.9 ) / 0.1
	if flash > 0 then
		surface.SetDrawColor( 255, 255, 255, flash * 200 )
		surface.DrawRect( 0, 0, w, h )
	end
end )

// the player is frozen on the server; keep the view still on the client too
hook.Add( "CreateMove", "LBR_SpawnIntro", function( cmd )
	if not active then return end
	cmd:ClearMovement()
	cmd:ClearButtons()
end )

hook.Add( "InputMouseApply", "LBR_SpawnIntro", function( cmd )
	if active then
		cmd:SetMouseX( 0 )
		cmd:SetMouseY( 0 )
		return true
	end
end )
