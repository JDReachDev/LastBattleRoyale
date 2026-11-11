// Client HUD (battle royale style)
//  bottom-left : shield + health bars
//  bottom-right: weapon name + ammo
//  top-center  : compass with zone center and teammates, match phase banner
//  top-right   : players alive, kills, zone timer and distance
//  top-left    : teammates with health
//  outside the zone: red vignette + direction

LBR = LBR or {}

local scale = 1
local function S( v ) return math.Round( v * scale ) end

local function CreateHUDFonts()
	scale = math.Clamp( ScrH() / 1080, 0.6, 2 )
	surface.CreateFont( "LBR_HUD_Huge",  { font = "Roboto", size = S( 48 ), weight = 900, antialias = true } )
	surface.CreateFont( "LBR_HUD_Big",   { font = "Roboto", size = S( 32 ), weight = 900, antialias = true } )
	surface.CreateFont( "LBR_HUD_Med",   { font = "Roboto", size = S( 22 ), weight = 800, antialias = true } )
	surface.CreateFont( "LBR_HUD_Small", { font = "Roboto", size = S( 17 ), weight = 700, antialias = true } )
	surface.CreateFont( "LBR_HUD_Tiny",  { font = "Roboto", size = S( 14 ), weight = 700, antialias = true } )
end
CreateHUDFonts()
hook.Add( "OnScreenSizeChanged", "LBR_HUDFonts", CreateHUDFonts )

local matSkull = Material( "zpicons/skull.png", "smooth" )
local matHealth = Material( "zpicons/health.png", "smooth" )
local matUser = Material( "icon16/user.png" )
local matGradient = Material( "vgui/gradient-u" )
local matGradientD = Material( "vgui/gradient-d" )
local matGradientL = Material( "vgui/gradient-l" )
local matGradientR = Material( "vgui/gradient-r" )

local colWhite = Color( 255, 255, 255 )
local colShadow = Color( 0, 0, 0, 200 )
local colBg = Color( 10, 14, 24, 170 )
local colBarBg = Color( 0, 0, 0, 140 )
local colHealth = Color( 90, 225, 95 )
local colHealthLow = Color( 235, 70, 60 )
local colShield = Color( 70, 170, 255 )
local colZone = Color( 200, 110, 255 )
local colWarn = Color( 255, 80, 70 )
local colGood = Color( 120, 255, 150 )
local colGold = Color( 255, 210, 70 )

local STATE_NONE, STATE_PREPARING, STATE_LIVE, STATE_POST = 1, 2, 3, 4

local function units2m( u ) return math.Round( u * 0.01905 ) end

local function fmtTime( s )
	s = math.max( math.ceil( s ), 0 )
	return string.format( "%d:%02d", math.floor( s / 60 ), s % 60 )
end

local function text( str, font, x, y, col, ax, ay )
	draw.SimpleTextOutlined( str, font, x, y, col, ax or TEXT_ALIGN_LEFT, ay or TEXT_ALIGN_TOP, 1, colShadow )
end

local function slantPoly( x, y, w, h, sk )
	return {
		{ x = x + sk, y = y },
		{ x = x + w + sk, y = y },
		{ x = x + w, y = y + h },
		{ x = x, y = y + h }
	}
end

local function slantBar( x, y, w, h, frac, col, ghostFrac )
	local sk = h * 0.45
	draw.NoTexture()
	surface.SetDrawColor( colBarBg )
	surface.DrawPoly( slantPoly( x, y, w, h, sk ) )
	if ghostFrac and ghostFrac > frac then
		surface.SetDrawColor( 255, 255, 255, 90 )
		surface.DrawPoly( slantPoly( x, y, math.max( w * ghostFrac, 1 ), h, sk ) )
	end
	if frac > 0 then
		surface.SetDrawColor( col )
		surface.DrawPoly( slantPoly( x, y, math.max( w * math.min( frac, 1 ), 1 ), h, sk ) )
		// light strip on top
		surface.SetDrawColor( 255, 255, 255, 40 )
		surface.DrawPoly( slantPoly( x + sk * 0.6, y, math.max( w * math.min( frac, 1 ) - sk * 0.2, 1 ), h * 0.3, sk * 0.3 ) )
	end
end

// the player whose stats are shown (yourself, or who you spectate)
local function viewTarget()
	local lp = LocalPlayer()
	local obs = lp:GetObserverTarget()
	if IsValid( obs ) and obs:IsPlayer() and obs ~= lp then return obs, true end
	return lp, false
end

------------------------------------------------------------------------
// Vitals
------------------------------------------------------------------------

local shown = { hp = 100, ar = 0, hpGhost = 100, arGhost = 0, ghostTime = 0 }

local function drawVitals( ply )
	if not ply:Alive() then return end
	local hp, maxhp = math.max( ply:Health(), 0 ), math.max( ply:GetMaxHealth(), 1 )
	local ar = math.max( ply:Armor(), 0 )
	local ft = FrameTime()
	shown.hp = Lerp( math.min( ft * 12, 1 ), shown.hp, hp )
	shown.ar = Lerp( math.min( ft * 12, 1 ), shown.ar, ar )
	// white "damage taken" ghost that catches up after a short delay
	if hp < shown.hpGhost or ar < shown.arGhost then
		if CurTime() > shown.ghostTime then
			shown.hpGhost = Lerp( math.min( ft * 4, 1 ), shown.hpGhost, hp )
			shown.arGhost = Lerp( math.min( ft * 4, 1 ), shown.arGhost, ar )
		end
	else
		shown.hpGhost, shown.arGhost = hp, ar
		shown.ghostTime = CurTime() + 0.6
	end

	local x, w = S( 40 ), S( 360 )
	local yHp = ScrH() - S( 70 )
	local yAr = yHp - S( 30 )

	// shield
	slantBar( x + S( 46 ), yAr, w, S( 20 ), shown.ar / 100, colShield, shown.arGhost / 100 )
	text( tostring( ar ), "LBR_HUD_Small", x + S( 46 ) + w + S( 18 ), yAr + S( 10 ), colShield, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )

	// health
	local low = hp / maxhp <= 0.25
	local col = low and colHealthLow or colHealth
	slantBar( x + S( 46 ), yHp, w, S( 28 ), shown.hp / maxhp, col, shown.hpGhost / maxhp )
	text( tostring( hp ), "LBR_HUD_Big", x + S( 46 ) + w + S( 22 ), yHp + S( 14 ), colWhite, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
	surface.SetFont( "LBR_HUD_Big" )
	local hw = surface.GetTextSize( tostring( hp ) )
	text( "/" .. maxhp, "LBR_HUD_Tiny", x + S( 46 ) + w + S( 26 ) + hw, yHp + S( 18 ), Color( 200, 200, 200 ), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )

	surface.SetDrawColor( col )
	surface.SetMaterial( matHealth )
	surface.DrawTexturedRect( x, yHp - S( 4 ), S( 36 ), S( 36 ) )
end

------------------------------------------------------------------------
// Ammo
------------------------------------------------------------------------

local function drawAmmo( ply )
	if not ply:Alive() then return end
	local wep = ply:GetActiveWeapon()
	if not IsValid( wep ) then return end
	local x = ScrW() - S( 40 )
	local y = ScrH() - S( 40 )

	local name = wep.GetPrintName and wep:GetPrintName() or wep:GetClass()
	local clip = wep:Clip1()
	local reserve = ply:GetAmmoCount( wep:GetPrimaryAmmoType() )

	if clip >= 0 then
		local maxclip = wep:GetMaxClip1()
		local clipCol = ( maxclip > 0 and clip <= maxclip * 0.25 ) and colWarn or colWhite
		surface.SetFont( "LBR_HUD_Med" )
		local rw = surface.GetTextSize( tostring( reserve ) )
		text( tostring( reserve ), "LBR_HUD_Med", x, y, Color( 200, 200, 200 ), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM )
		text( tostring( clip ), "LBR_HUD_Huge", x - rw - S( 12 ), y + S( 6 ), clipCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM )
		surface.SetDrawColor( 255, 255, 255, 120 )
		surface.DrawRect( x - rw - S( 7 ), y - S( 30 ), S( 2 ), S( 26 ) )
		y = y - S( 52 )
	elseif reserve > 0 then
		text( tostring( reserve ), "LBR_HUD_Huge", x, y + S( 6 ), colWhite, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM )
		y = y - S( 52 )
	end
	text( string.upper( name ), "LBR_HUD_Small", x, y, colGold, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM )
end

------------------------------------------------------------------------
// Compass
------------------------------------------------------------------------

local dirNames = { [0] = "N", [45] = "NE", [90] = "E", [135] = "SE", [180] = "S", [225] = "SW", [270] = "W", [315] = "NW" }

// Source yaw 90 = +Y, used as north
local function headingOf( yaw ) return ( 90 - yaw ) % 360 end

local function drawCompass( lp )
	local cx, y = ScrW() / 2, S( 18 )
	local w, h = S( 560 ), S( 34 )
	local fov = 180
	local pxPerDeg = w / fov
	local heading = headingOf( EyeAngles().y )

	surface.SetMaterial( matGradientR )
	surface.SetDrawColor( colBg )
	surface.DrawTexturedRect( cx - w / 2, y, w / 2, h )
	surface.SetMaterial( matGradientL )
	surface.DrawTexturedRect( cx, y, w / 2, h )

	render.SetScissorRect( cx - w / 2, y, cx + w / 2, y + h + S( 30 ), true )
	local start = math.floor( ( heading - fov / 2 ) / 15 ) * 15
	for deg = start, heading + fov / 2, 15 do
		local d = deg % 360
		local diff = math.AngleDifference( d, heading )
		local px = cx + diff * pxPerDeg
		local alpha = 255 * ( 1 - math.abs( diff ) / ( fov / 2 ) )
		if dirNames[d] then
			draw.SimpleText( dirNames[d], d % 90 == 0 and "LBR_HUD_Med" or "LBR_HUD_Small", px, y + h / 2, Color( 255, 255, 255, alpha ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		else
			surface.SetDrawColor( 255, 255, 255, alpha * 0.6 )
			surface.DrawRect( px - 1, y + h - S( 10 ), 2, S( 8 ) )
			draw.SimpleText( tostring( d ), "LBR_HUD_Tiny", px, y + S( 2 ), Color( 255, 255, 255, alpha * 0.5 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP )
		end
	end

	local eye = EyePos()
	local function marker( pos, col, size, label )
		local diff = math.AngleDifference( headingOf( ( pos - eye ):Angle().y ), heading )
		diff = math.Clamp( diff, -fov / 2 + 3, fov / 2 - 3 )
		local px = cx + diff * pxPerDeg
		draw.NoTexture()
		surface.SetDrawColor( col )
		surface.DrawPoly( {
			{ x = px, y = y + h + S( 2 ) },
			{ x = px + size, y = y + h + size + S( 4 ) },
			{ x = px - size, y = y + h + size + S( 4 ) }
		} )
		if label then
			draw.SimpleText( label, "LBR_HUD_Tiny", px, y + h + size + S( 6 ), col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP )
		end
	end

	if LBR.IsZoneActive() then
		local zp = LBR.GetZonePos()
		marker( zp, LBR.GetZoneColor and LBR.GetZoneColor() or colZone, S( 9 ), units2m( eye:Distance( zp ) ) .. "m" )
	end
	for _, sid in ipairs( TEAMERSTAB or {} ) do
		local mate = player.GetBySteamID64( sid )
		if IsValid( mate ) and mate ~= lp and mate:Alive() and mate:Team() == 2 then
			marker( mate:GetPos(), colGold, S( 6 ) )
		end
	end
	render.SetScissorRect( 0, 0, 0, 0, false )

	// center notch + heading
	surface.SetDrawColor( colGold )
	surface.DrawRect( cx - 1, y - S( 4 ), 2, S( 8 ) )
	draw.SimpleText( tostring( math.Round( heading ) % 360 ), "LBR_HUD_Tiny", cx, y + h + S( 22 ), colGold, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP )
end

------------------------------------------------------------------------
// Phase banner
------------------------------------------------------------------------

local function drawBanner( lp, spectating, target )
	local state = GetGlobalInt( "state" )
	local now = CurTime()
	local left = GetGlobalFloat( "LBR_PhaseEnd", 0 ) - now
	local title, sub, col

	if state == STATE_NONE then
		if not GetGlobalBool( "LBR_MapReady", true ) then
			title, col = "MAP NOT CONFIGURED", colWarn
			sub = lp:IsAdmin() and "Press F8 to open the map editor" or "Waiting for an admin to configure this map"
		else
			local need = GetGlobalInt( "LBR_MinPlayers", 2 )
			title, col = "WAITING FOR PLAYERS", colWhite
			sub = #player.GetAll() .. " / " .. need
			if lp:IsAdmin() and #player.GetAll() >= 2 then
				sub = sub .. "   -   Admin: TAB > START NOW or type !start"
			end
		end
	elseif state == STATE_PREPARING then
		title, col = "MATCH STARTS IN " .. math.max( math.ceil( left ), 0 ), colGold
		sub = "F3 class  -  F4 team"
	elseif state == STATE_LIVE and not GetGlobalBool( "LBR_CanAttack", true ) and left > 0 then
		title, col = "WEAPONS HOT IN " .. math.ceil( left ), colGold
		sub = "Loot up!"
	elseif state == STATE_POST then
		local winner = GetGlobalString( "LBR_Winner", "" )
		title, col = winner ~= "" and "#1 WINNER" or "ROUND OVER", colGold
		sub = winner ~= "" and winner or nil
	end

	local y = S( 100 )
	if title then
		text( title, "LBR_HUD_Big", ScrW() / 2, y, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP )
		y = y + S( 36 )
		if sub then
			text( sub, "LBR_HUD_Small", ScrW() / 2, y, colWhite, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP )
			y = y + S( 24 )
		end
	end
	if spectating then
		text( "SPECTATING " .. string.upper( target:Nick() ), "LBR_HUD_Med", ScrW() / 2, ScrH() - S( 130 ), colWhite, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP )
	end
end

------------------------------------------------------------------------
// Top-right info: alive, kills, zone
------------------------------------------------------------------------

local function drawInfo( lp, ply )
	local x = ScrW() - S( 30 )
	local y = S( 20 )
	local alive = #team.GetPlayers( 2 )
	local kills = ply:GetNW2Int( "LBR_Kills", 0 )

	surface.SetFont( "LBR_HUD_Med" )
	local kw = surface.GetTextSize( tostring( kills ) )
	local aw = surface.GetTextSize( tostring( alive ) )
	local boxW = S( 24 ) + kw + S( 20 ) + S( 24 ) + aw + S( 30 )
	draw.RoundedBox( S( 6 ), x - boxW, y, boxW, S( 34 ), colBg )

	local cx = x - S( 12 )
	text( tostring( kills ), "LBR_HUD_Med", cx, y + S( 17 ), colWhite, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
	cx = cx - kw - S( 26 )
	surface.SetDrawColor( colWhite )
	surface.SetMaterial( matSkull )
	surface.DrawTexturedRect( cx, y + S( 5 ), S( 22 ), S( 22 ) )
	cx = cx - S( 12 )
	text( tostring( alive ), "LBR_HUD_Med", cx, y + S( 17 ), colWhite, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
	cx = cx - aw - S( 24 )
	surface.SetMaterial( matUser )
	surface.DrawTexturedRect( cx, y + S( 8 ), S( 18 ), S( 18 ) )

	y = y + S( 42 )

	if LBR.IsZoneActive() then
		local radius = LBR.GetZoneRadius()
		local dist = ply:GetPos():Distance( LBR.GetZonePos() )
		local toEdge = dist - radius
		local w = S( 230 )
		draw.RoundedBox( S( 6 ), x - w, y, w, S( 64 ), colBg )
		local zcol = LBR.GetZoneColor and LBR.GetZoneColor() or colZone
		surface.SetDrawColor( zcol.r, zcol.g, zcol.b, 255 )
		surface.DrawRect( x - w, y, S( 4 ), S( 64 ) )
		local tl = LBR.GetZoneTimeLeft()
		text( radius > 0 and ( "ZONE CLOSING  " .. fmtTime( tl ) ) or "ZONE CLOSED", "LBR_HUD_Small", x - w + S( 14 ), y + S( 6 ), colWhite )
		if toEdge > 0 then
			text( "OUTSIDE: " .. units2m( toEdge ) .. "m to safety", "LBR_HUD_Small", x - w + S( 14 ), y + S( 34 ), colWarn )
		else
			text( "SAFE  -  edge " .. units2m( -toEdge ) .. "m", "LBR_HUD_Small", x - w + S( 14 ), y + S( 34 ), colGood )
		end
		y = y + S( 72 )
	end

	local ev = GetGlobalFloat( "LBR_EventTime", 0 ) - CurTime()
	if GetGlobalInt( "state" ) == STATE_LIVE and ev > 0 then
		text( "Random event in " .. fmtTime( ev ), "LBR_HUD_Tiny", x, y, colGold, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP )
	end
end

------------------------------------------------------------------------
// Teammates
------------------------------------------------------------------------

local function drawTeam( lp )
	local mates = {}
	for _, sid in ipairs( TEAMERSTAB or {} ) do
		local pl = player.GetBySteamID64( sid )
		if IsValid( pl ) and pl ~= lp then mates[#mates + 1] = pl end
	end
	if #mates == 0 then return end
	local x, y = S( 20 ), S( 20 )
	local w, rowH = S( 220 ), S( 40 )
	text( "SQUAD", "LBR_HUD_Tiny", x, y, colGold )
	y = y + S( 20 )
	for _, pl in ipairs( mates ) do
		draw.RoundedBox( S( 4 ), x, y, w, rowH - S( 4 ), colBg )
		local alive = pl:Alive() and pl:Team() == 2
		text( string.sub( pl:Nick(), 1, 18 ), "LBR_HUD_Tiny", x + S( 8 ), y + S( 3 ), alive and colWhite or Color( 150, 150, 150 ) )
		if alive then
			local frac = math.Clamp( pl:Health() / math.max( pl:GetMaxHealth(), 1 ), 0, 1 )
			slantBar( x + S( 8 ), y + S( 21 ), w - S( 30 ), S( 8 ), frac, frac <= 0.25 and colHealthLow or colHealth )
			if pl:Armor() > 0 then
				surface.SetDrawColor( colShield )
				surface.DrawRect( x + S( 8 ), y + S( 31 ), ( w - S( 30 ) ) * math.Clamp( pl:Armor() / 100, 0, 1 ), S( 2 ) )
			end
		else
			text( "ELIMINATED", "LBR_HUD_Tiny", x + w - S( 8 ), y + S( 3 ), colWarn, TEXT_ALIGN_RIGHT )
		end
		y = y + rowH
	end
end

local function drawTeamNames( lp )
	local eye = EyePos()
	for _, sid in ipairs( TEAMERSTAB or {} ) do
		local v = player.GetBySteamID64( sid )
		if IsValid( v ) and v ~= lp and v:Alive() and v:Team() == 2 and not v:IsDormant() then
			local dist = eye:Distance( v:GetPos() )
			if dist < 6000 then
				local pos = ( v:GetPos() + Vector( 0, 0, 80 ) ):ToScreen()
				if pos.visible then
					text( v:Nick(), "LBR_HUD_Small", pos.x, pos.y, colGold, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM )
					text( units2m( dist ) .. "m", "LBR_HUD_Tiny", pos.x, pos.y, colWhite, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP )
				end
			end
		end
	end
end

------------------------------------------------------------------------
// Outside zone / low health effects
------------------------------------------------------------------------

local function drawVignette( r, g, b, a )
	local sw, sh = ScrW(), ScrH()
	local d = S( 220 )
	surface.SetDrawColor( r, g, b, a )
	surface.SetMaterial( matGradient )
	surface.DrawTexturedRect( 0, 0, sw, d )
	surface.SetMaterial( matGradientD )
	surface.DrawTexturedRect( 0, sh - d, sw, d )
	surface.SetMaterial( matGradientL )
	surface.DrawTexturedRect( 0, 0, d, sh )
	surface.SetMaterial( matGradientR )
	surface.DrawTexturedRect( sw - d, 0, d, sh )
end

local function drawEffects( lp )
	if not lp:Alive() or lp:Team() ~= 2 then return end
	if GetGlobalInt( "state" ) == STATE_LIVE and LBR.IsZoneActive() and not LBR.IsPosInZone( lp:GetPos() ) then
		local pulse = 90 + math.sin( CurTime() * 4 ) * 40
		drawVignette( 200, 40, 255, pulse )
		text( "YOU ARE OUTSIDE THE SAFE ZONE", "LBR_HUD_Med", ScrW() / 2, ScrH() * 0.72, colWarn, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
	elseif lp:Health() <= 25 then
		drawVignette( 200, 0, 0, 80 + math.sin( CurTime() * 3 ) * 30 )
	end
end

------------------------------------------------------------------------

local hidden = { CHudHealth = true, CHudBattery = true, CHudAmmo = true, CHudSecondaryAmmo = true }
hook.Add( "HUDShouldDraw", "hide hud", function( name )
	if hidden[name] then return false end
end )

hook.Add( "HUDPaint", "LBR_HUD", function()
	local lp = LocalPlayer()
	if not IsValid( lp ) then return end
	if LBR.Editor and LBR.Editor.active then return end

	local ply, spectating = viewTarget()
	drawEffects( lp )
	drawTeamNames( lp )
	drawCompass( lp )
	drawBanner( lp, spectating, ply )
	drawInfo( lp, ply )
	drawTeam( lp )
	if ( lp:Alive() and lp:Team() ~= 3 ) or spectating then
		drawVitals( ply )
		drawAmmo( ply )
	end
end )
