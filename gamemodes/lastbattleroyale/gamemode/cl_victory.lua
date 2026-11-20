// Victory screen: the end of a round with a winner (LBR_Victory from init.lua).
//  - the last kill in slow motion (server), a white flash and cinematic bars
//  - the camera of everybody slowly circles around the winner
//  - a big animated title ("VICTORY" for the winners, "<NAME> WINS" for the others),
//    the line "LAST ONE STANDING" and cards with kills, match time and exp counting up
//  - confetti on the screen and fireworks above the winners
// All the animations use RealTime: the slow motion slows CurTime down.

LBR = LBR or {}

local STATE_POST = 4

local scale = 1
local function S( v ) return math.Round( v * scale ) end
local function CreateFonts()
	scale = math.Clamp( ScrH() / 1080, 0.6, 2 )
	surface.CreateFont( "LBR_WIN_Title", { font = "Roboto", size = S( 110 ), weight = 900, antialias = true } )
	surface.CreateFont( "LBR_WIN_Sub",   { font = "Roboto", size = S( 26 ), weight = 800, antialias = true } )
	surface.CreateFont( "LBR_WIN_Num",   { font = "Roboto", size = S( 40 ), weight = 900, antialias = true } )
	surface.CreateFont( "LBR_WIN_Label", { font = "Roboto", size = S( 14 ), weight = 800, antialias = true } )
end
CreateFonts()
hook.Add( "OnScreenSizeChanged", "LBR_VictoryFonts", CreateFonts )

local colGold = Color( 255, 210, 70 )
local colText = Color( 236, 239, 245 )
local colDim = Color( 150, 158, 175 )
local colBg = Color( 10, 14, 24, 215 )

local CONFETTI_COLORS = {
	Color( 255, 210, 70 ), Color( 255, 85, 75 ), Color( 70, 170, 255 ),
	Color( 110, 230, 140 ), Color( 200, 110, 255 ), Color( 255, 255, 255 ),
}

local win // the current victory, nil when none

local function easeOutBack( t )
	local c1, c3 = 1.70158, 2.70158
	return 1 + c3 * ( t - 1 ) ^ 3 + c1 * ( t - 1 ) ^ 2
end
local function easeOut( t ) return 1 - ( 1 - t ) ^ 3 end
local function clamp01( v ) return math.Clamp( v, 0, 1 ) end

local function fmtTime( s )
	s = math.max( math.floor( s ), 0 )
	return string.format( "%d:%02d", math.floor( s / 60 ), s % 60 )
end

function LBR.VictoryActive()
	return win ~= nil
end

local function stop()
	win = nil
end

// the winner the camera looks at: the first one still valid and alive
local function camTarget()
	if not win then return end
	for _, w in ipairs( win.winners ) do
		if IsValid( w.ply ) and w.ply:Alive() then return w.ply end
	end
end

------------------------------------------------------------------------
// Start
------------------------------------------------------------------------

local function spawnConfetti()
	local w, h = ScrW(), ScrH()
	local list = {}
	for i = 1, 180 do
		// two bursts from the lower corners and a rain from the top
		local p = {}
		if i <= 120 then
			local left = i % 2 == 0
			p.x = left and -S( 20 ) or w + S( 20 )
			p.y = h * 0.75
			local ang = math.rad( math.Rand( 50, 80 ) )
			local speed = math.Rand( 0.9, 1.6 ) * h
			p.vx = math.cos( ang ) * speed * ( left and 1 or -1 )
			p.vy = -math.sin( ang ) * speed
			p.delay = math.Rand( 0, 0.25 )
		else
			p.x = math.Rand( 0, w )
			p.y = -math.Rand( S( 10 ), h * 0.5 )
			p.vx = math.Rand( -40, 40 )
			p.vy = math.Rand( 60, 160 )
			p.delay = math.Rand( 0.3, 1.5 )
		end
		p.col = CONFETTI_COLORS[math.random( #CONFETTI_COLORS )]
		p.size = S( math.Rand( 6, 12 ) )
		p.spin = math.Rand( 4, 12 )
		p.phase = math.Rand( 0, math.pi * 2 )
		list[i] = p
	end
	return list
end

// winners: { { ply = , kills = , name = } }. test = preview without a round (lbr_victory_test)
local function start( winners, exp, length, test )
	local n = #winners
	local me = false
	for _, w in ipairs( winners ) do
		if w.ply == LocalPlayer() then me = true end
	end

	local kills = 0
	for _, w in ipairs( winners ) do kills = kills + w.kills end

	win = {
		start = RealTime(),
		winners = winners,
		me = me,
		exp = me and exp or 0,
		kills = kills,
		length = length,
		confetti = n > 0 and spawnConfetti() or {},
		nextFirework = RealTime() + 0.6,
		fireworks = 0,
		test = test,
	}
end

net.Receive( "LBR_Victory", function()
	local winners = {}
	for i = 1, net.ReadUInt( 4 ) do
		local ply = net.ReadEntity()
		local kills = net.ReadUInt( 8 )
		winners[i] = { ply = ply, kills = kills, name = IsValid( ply ) and ply:Nick() or "?" }
	end
	local exp = net.ReadUInt( 16 )
	start( winners, exp, net.ReadFloat() )
end )

// preview on the client only (no slow motion, nobody gets god mode), ends after 12 s:
//  lbr_victory_test         you win
//  lbr_victory_test other   another player (or bot) wins: what the others see
//  lbr_victory_test none    nobody survived
concommand.Add( "lbr_victory_test", function( _, _, args )
	local lp = LocalPlayer()
	local mode = string.lower( args[1] or "" )
	local who = lp
	if mode == "other" then
		for _, p in ipairs( player.GetAll() ) do
			if p ~= lp and p:Alive() then who = p break end
		end
		if who == lp then LBR.ChatLocal( "No other living player: add a bot with \"bot\"", "bad" ) return end
	end
	local winners = mode == "none" and {} or { { ply = who, kills = 7, name = who:Nick() } }
	start( winners, 75, 754, true )
	if #winners > 0 then
		sound.PlayFile( "sound/music/hl2_song23_suitsong3.mp3", "", function( ch )
			if not IsValid( ch ) then return end
			if win then win.testSound = ch end
			ch:SetVolume( 0.35 )
		end )
	end
end )

// the round is over (back to the lobby, map change): everything off
hook.Add( "Think", "LBR_Victory", function()
	if not win then return end
	if win.test then
		if RealTime() - win.start > 12 then
			if IsValid( win.testSound ) then win.testSound:Stop() end
			stop()
			return
		end
	// the message can arrive before the new state: wait for it a moment
	elseif GetGlobalInt( "state", 1 ) == STATE_POST then
		win.seenPost = true
	elseif win.seenPost or RealTime() - win.start > 3 then
		stop()
		return
	end

	// fireworks above the winners in the first seconds
	if #win.winners > 0 and win.fireworks < 8 and RealTime() >= win.nextFirework then
		win.fireworks = win.fireworks + 1
		win.nextFirework = RealTime() + math.Rand( 0.45, 0.8 )
		local target = win.winners[( win.fireworks - 1 ) % #win.winners + 1].ply
		if IsValid( target ) then
			local pos = target:GetPos() + Vector( math.Rand( -160, 160 ), math.Rand( -160, 160 ), math.Rand( 180, 300 ) )
			// not inside a ceiling
			local tr = util.TraceLine( { start = target:EyePos(), endpos = pos, mask = MASK_SOLID_BRUSHONLY } )
			LBR.VictoryFirework( tr.HitPos - ( tr.Normal * 24 ) )
		end
	end
end )

------------------------------------------------------------------------
// Fireworks: a sphere of colored sparks that fall slowly
------------------------------------------------------------------------

local matSpark = Material( "sprites/light_glow02_add" )

function LBR.VictoryFirework( pos )
	local em = ParticleEmitter( pos )
	if not em then return end
	local col = CONFETTI_COLORS[math.random( #CONFETTI_COLORS - 1 )]
	for _ = 1, 48 do
		local p = em:Add( matSpark, pos )
		if p then
			p:SetVelocity( VectorRand():GetNormalized() * math.Rand( 140, 220 ) )
			p:SetDieTime( math.Rand( 1.2, 1.8 ) )
			p:SetStartAlpha( 255 )
			p:SetEndAlpha( 0 )
			p:SetStartSize( math.Rand( 6, 10 ) )
			p:SetEndSize( 1 )
			p:SetColor( col.r, col.g, col.b )
			p:SetGravity( Vector( 0, 0, -120 ) )
			p:SetAirResistance( 90 )
		end
	end
	// the flash in the middle
	local f = em:Add( matSpark, pos )
	if f then
		f:SetDieTime( 0.25 )
		f:SetStartAlpha( 255 )
		f:SetEndAlpha( 0 )
		f:SetStartSize( 90 )
		f:SetEndSize( 10 )
		f:SetColor( 255, 240, 200 )
	end
	em:Finish()
	sound.Play( "garrysmod/balloon_pop_cute.wav", pos, 90, math.random( 85, 110 ), 0.6 )
end

------------------------------------------------------------------------
// Camera: slowly around the winner, a bit from above, starting in front of him
------------------------------------------------------------------------

local CAM_BLEND = 1.2  // seconds to go from the normal view to the orbit
local CAM_SPEED = 10   // degrees per second
local CAM_HULL = Vector( 6, 6, 6 )

hook.Add( "CalcView", "LBR_Victory", function( ply, origin, angles, fov )
	if not win then return end
	local target = camTarget()
	if not target then return end
	local t = RealTime() - win.start

	if not win.camYaw then
		win.camYaw = target:EyeAngles().y + 180 + 30
		win.camFrom = { pos = origin, ang = angles }
	end

	local k = clamp01( t / 6 )
	local dist = Lerp( easeOut( k ), 110, 170 ) // a slow dolly out
	local center = target:GetPos() + Vector( 0, 0, target:Crouching() and 36 or 52 )
	local ang = Angle( 14, win.camYaw + t * CAM_SPEED, 0 )
	local want = center - ang:Forward() * dist
	local tr = util.TraceHull( { start = center, endpos = want, mins = -CAM_HULL, maxs = CAM_HULL, mask = MASK_SOLID_BRUSHONLY } )
	local pos = tr.HitPos

	local b = easeOut( clamp01( t / CAM_BLEND ) )
	if b < 1 then
		pos = LerpVector( b, win.camFrom.pos, pos )
		ang = LerpAngle( b, win.camFrom.ang, ang )
	end
	return { origin = pos, angles = ang, fov = fov - 10 * b, drawviewer = true }
end )

hook.Add( "PreDrawViewModel", "LBR_Victory", function()
	if win and camTarget() then return true end
end )

------------------------------------------------------------------------
// Screen
------------------------------------------------------------------------

local function drawConfetti( t )
	local ft = math.min( RealFrameTime(), 0.05 )
	local g = ScrH() * 1.1
	for _, p in ipairs( win.confetti ) do
		if t >= p.delay and p.y < ScrH() + S( 40 ) then
			p.vy = p.vy + g * ft
			// paper: slowed down by the air, it falls slowly and swings
			p.vx = p.vx * ( 1 - math.min( ft * 1.6, 1 ) )
			if p.vy > 160 then p.vy = Lerp( math.min( ft * 4, 1 ), p.vy, 160 ) end
			p.x = p.x + ( p.vx + math.sin( t * 3 + p.phase ) * 40 ) * ft
			p.y = p.y + p.vy * ft
			// the flip of a piece of paper: the width changes
			local fw = math.max( math.abs( math.sin( t * p.spin + p.phase ) ) * p.size, 1 )
			surface.SetDrawColor( p.col.r, p.col.g, p.col.b, 235 )
			surface.DrawRect( p.x - fw / 2, p.y - p.size * 0.3, fw, p.size * 0.6 )
		end
	end
end

// text scaled around its center
local function scaledText( str, font, x, y, col, s )
	local m = Matrix()
	m:Translate( Vector( x, y, 0 ) )
	m:Scale( Vector( s, s, 1 ) )
	m:Translate( Vector( -x, -y, 0 ) )
	cam.PushModelMatrix( m, true )
	render.PushFilterMag( TEXFILTER.ANISOTROPIC )
	render.PushFilterMin( TEXFILTER.ANISOTROPIC )
	draw.SimpleText( str, font, x + S( 4 ), y + S( 4 ), Color( 0, 0, 0, col.a * 0.6 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
	draw.SimpleText( str, font, x, y, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
	render.PopFilterMin()
	render.PopFilterMag()
	cam.PopModelMatrix()
end

local function statCard( x, y, w, h, label, value, a )
	surface.SetDrawColor( colBg.r, colBg.g, colBg.b, colBg.a * a )
	surface.DrawRect( x, y, w, h )
	surface.SetDrawColor( colGold.r, colGold.g, colGold.b, 255 * a )
	surface.DrawRect( x, y, w, S( 2 ) )
	draw.SimpleText( value, "LBR_WIN_Num", x + w / 2, y + h * 0.42, Color( 255, 255, 255, 255 * a ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
	draw.SimpleText( label, "LBR_WIN_Label", x + w / 2, y + h - S( 14 ), Color( colDim.r, colDim.g, colDim.b, 255 * a ), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM )
end

local function names()
	local list = {}
	for _, w in ipairs( win.winners ) do list[#list + 1] = w.name end
	if #list <= 1 then return list[1] or "" end
	return table.concat( list, ", ", 1, #list - 1 ) .. " & " .. list[#list]
end

hook.Add( "HUDPaint", "LBR_Victory", function()
	if not win then return end
	local t = RealTime() - win.start
	local w, h = ScrW(), ScrH()
	local any = #win.winners > 0
	local cx = w / 2

	// white flash on the last kill
	if any and t < 0.6 then
		surface.SetDrawColor( 255, 255, 255, 170 * ( 1 - t / 0.6 ) )
		surface.DrawRect( 0, 0, w, h )
	end

	// cinematic bars
	local bar = math.floor( h * 0.08 * easeOut( clamp01( t / 0.7 ) ) )
	surface.SetDrawColor( 0, 0, 0, 255 )
	surface.DrawRect( 0, 0, w, bar )
	surface.DrawRect( 0, h - bar, w, bar )

	if any then drawConfetti( t ) end

	// the map vote (cl_mapvote.lua) takes the middle of the screen
	if GetGlobalBool( "LBR_MapVote", false ) then return end

	// title: comes in big and lands with a small bounce
	local title, sub
	if not any then
		title, sub = "ROUND OVER", "NOBODY SURVIVED"
	elseif win.me then
		title = "VICTORY"
		sub = #win.winners > 1 and "LAST SQUAD STANDING" or "LAST ONE STANDING"
	else
		title = string.upper( names() ) .. ( #win.winners > 1 and " WIN" or " WINS" )
		sub = #win.winners > 1 and "LAST SQUAD STANDING" or "LAST ONE STANDING"
	end

	local ty = h * 0.26
	local tk = clamp01( ( t - 0.15 ) / 0.55 )
	if tk > 0 then
		local s = Lerp( easeOutBack( tk ), 2.2, 1 )
		// the name of somebody else can be long: smaller so it fits
		surface.SetFont( "LBR_WIN_Title" )
		local tw = surface.GetTextSize( title )
		local fit = math.min( 1, ( w * 0.9 ) / math.max( tw, 1 ) )
		local col = win.me and colGold or colText
		scaledText( title, "LBR_WIN_Title", cx, ty, Color( col.r, col.g, col.b, 255 * clamp01( tk * 2 ) ), s * fit )

		// gold line that opens from the middle
		local lk = easeOut( clamp01( ( t - 0.5 ) / 0.5 ) )
		local lw = math.floor( math.min( tw * fit, w * 0.9 ) * lk )
		local ly = ty + S( 62 ) * fit
		surface.SetDrawColor( colGold )
		surface.DrawRect( cx - lw / 2, ly, lw, S( 3 ) )

		// subtitle with spaced letters
		local sk = clamp01( ( t - 0.7 ) / 0.4 )
		if sk > 0 then
			local spaced = string.gsub( sub, "(.)", "%1 " ):sub( 1, -2 )
			draw.SimpleText( spaced, "LBR_WIN_Sub", cx, ly + S( 22 ) + ( 1 - easeOut( sk ) ) * S( 12 ), Color( 255, 255, 255, 230 * sk ), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP )
		end

		// the names of the squad under the title, when the title is "VICTORY"
		if win.me and #win.winners > 1 and sk > 0 then
			draw.SimpleText( names(), "LBR_WIN_Label", cx, ly + S( 60 ), Color( colDim.r, colDim.g, colDim.b, 255 * sk ), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP )
		end
	end

	if not any then return end

	// stat cards, one after the other, the numbers count up
	local cards = {
		{ "KILLS", function( k ) return tostring( math.Round( win.kills * k ) ) end },
		{ "MATCH TIME", function( k ) return fmtTime( win.length * k ) end },
	}
	if win.exp > 0 then
		cards[#cards + 1] = { "EXP EARNED", function( k ) return "+" .. math.Round( win.exp * k ) end }
	end
	local cw, ch, gap = S( 170 ), S( 90 ), S( 14 )
	local total = #cards * cw + ( #cards - 1 ) * gap
	local x0 = cx - total / 2
	local cy = h * 0.5
	for i, c in ipairs( cards ) do
		local start = 1.1 + ( i - 1 ) * 0.18
		local a = clamp01( ( t - start ) / 0.35 )
		if a > 0 then
			local count = easeOut( clamp01( ( t - start ) / 1.2 ) )
			local y = cy + ( 1 - easeOut( a ) ) * S( 30 )
			statCard( x0 + ( i - 1 ) * ( cw + gap ), y, cw, ch, c[1], c[2]( count ), a )
		end
	end
end )

// the normal HUD stays out of the way (cl_hud.lua checks LBR.VictoryActive)
