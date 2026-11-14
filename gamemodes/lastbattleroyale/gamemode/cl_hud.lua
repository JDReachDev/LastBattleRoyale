// Client HUD (same look as the menus of cl_ui.lua: dark flat panels, thin gold line on top)
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
local matUser = Material( "icon16/user.png" )
local matGradient = Material( "vgui/gradient-u" )
local matGradientD = Material( "vgui/gradient-d" )
local matGradientL = Material( "vgui/gradient-l" )
local matGradientR = Material( "vgui/gradient-r" )

local colWhite = Color( 255, 255, 255 )
local colShadow = Color( 0, 0, 0, 200 )
local colBg = Color( 10, 14, 24, 205 )
local colBarBg = Color( 0, 0, 0, 140 )
local colHealth = Color( 90, 225, 95 )
local colHealthLow = Color( 235, 70, 60 )
local colShield = Color( 70, 170, 255 )
local colZone = Color( 200, 110, 255 )
local colWarn = Color( 255, 80, 70 )
local colGood = Color( 120, 255, 150 )
local colGold = Color( 255, 210, 70 )
local colDim = Color( 150, 158, 175 )
local colFade = Color( 255, 255, 255 ) // reused, alpha changed per use (no new Color every frame)
local function fade( a ) colFade.a = a return colFade end

local STATE_NONE, STATE_PREPARING, STATE_LIVE, STATE_POST = 1, 2, 3, 4

local function units2m( u ) return math.Round( u * 0.01905 ) end

local function fmtTime( s )
	s = math.max( math.ceil( s ), 0 )
	return string.format( "%d:%02d", math.floor( s / 60 ), s % 60 )
end

// outlined text: only for things drawn over the world (names above teammates, compass)
local function text( str, font, x, y, col, ax, ay )
	draw.SimpleTextOutlined( str, font, x, y, col, ax or TEXT_ALIGN_LEFT, ay or TEXT_ALIGN_TOP, 1, colShadow )
end

// plain text: inside the panels
local function ptext( str, font, x, y, col, ax, ay )
	draw.SimpleText( str, font, x, y, col, ax or TEXT_ALIGN_LEFT, ay or TEXT_ALIGN_TOP )
end

// same look as the menus (cl_ui.lua): dark flat panel, thin gold line on top
local function panel( x, y, w, h, accent )
	surface.SetDrawColor( colBg )
	surface.DrawRect( x, y, w, h )
	surface.SetDrawColor( accent or colGold )
	surface.DrawRect( x, y, w, S( 2 ) )
end

// flat bar with the white "damage taken" ghost
local function bar( x, y, w, h, frac, col, ghostFrac )
	surface.SetDrawColor( colBarBg )
	surface.DrawRect( x, y, w, h )
	if ghostFrac and ghostFrac > frac then
		surface.SetDrawColor( 255, 255, 255, 90 )
		surface.DrawRect( x, y, math.floor( w * math.min( ghostFrac, 1 ) ), h )
	end
	if frac > 0 then
		surface.SetDrawColor( col )
		surface.DrawRect( x, y, math.max( math.floor( w * math.min( frac, 1 ) ), 1 ), h )
		surface.SetDrawColor( 255, 255, 255, 30 )
		surface.DrawRect( x, y, math.max( math.floor( w * math.min( frac, 1 ) ), 1 ), math.max( math.floor( h * 0.35 ), 1 ) )
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

	local low = hp / maxhp <= 0.25
	local col = low and colHealthLow or colHealth
	local w, h = S( 400 ), S( 92 )
	local x, y = S( 24 ), ScrH() - S( 24 ) - h
	panel( x, y, w, h )

	local pad = S( 14 )
	local bx = x + pad + S( 46 )
	local bw = w - pad * 2 - S( 46 ) - S( 70 )

	// health icon: a plain cross in the health color (red when low), dark border
	local cs, ct = S( 30 ), S( 10 )
	local cx, cy = x + pad + S( 17 ), y + S( 57 )
	surface.SetDrawColor( 0, 0, 0, 200 )
	surface.DrawRect( cx - ct / 2 - 2, cy - cs / 2 - 2, ct + 4, cs + 4 )
	surface.DrawRect( cx - cs / 2 - 2, cy - ct / 2 - 2, cs + 4, ct + 4 )
	surface.SetDrawColor( col )
	surface.DrawRect( cx - ct / 2, cy - cs / 2, ct, cs )
	surface.DrawRect( cx - cs / 2, cy - ct / 2, cs, ct )

	// shield
	ptext( "SHIELD", "LBR_HUD_Tiny", bx, y + S( 12 ), colDim )
	bar( bx, y + S( 30 ), bw, S( 10 ), shown.ar / 100, colShield, shown.arGhost / 100 )
	ptext( tostring( ar ), "LBR_HUD_Small", x + w - pad, y + S( 35 ), colShield, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )

	// health
	ptext( "HEALTH", "LBR_HUD_Tiny", bx, y + S( 46 ), colDim )
	bar( bx, y + S( 64 ), bw, S( 16 ), shown.hp / maxhp, col, shown.hpGhost / maxhp )
	ptext( tostring( hp ), "LBR_HUD_Big", x + w - pad, y + S( 72 ), low and colHealthLow or colWhite, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
end

------------------------------------------------------------------------
// Ammo
------------------------------------------------------------------------

// the magazine stores (sh_clips.lua) on top of the ammo panel: one cell per
// color with its magazine icon and count, on a tint of the color; the color of
// the weapon in hand is brighter and underlined
local CLIPS_H = 40
local function drawClips( ply, wep, x, y, w )
	if not LBR.ClipColors then return end
	local mine = LBR.UsesMagazines( wep ) and LBR.ClipColorOf( wep )
	local colors = LBR.ClipColors()
	local gap = S( 4 )
	local cw = math.floor( ( w - gap * ( #colors - 1 ) ) / math.max( #colors, 1 ) )
	local ch = S( CLIPS_H ) - S( 8 )
	local isz = S( 26 )
	for i, id in ipairs( colors ) do
		local t = LBR.TierById[id]
		local c = t.color
		local n = LBR.GetClips( ply, id )
		local on = not mine or mine == id
		local cx = x + ( i - 1 ) * ( cw + gap )
		surface.SetDrawColor( c.r, c.g, c.b, on and 45 or 18 )
		surface.DrawRect( cx, y, cw, ch )
		if mine == id then
			surface.SetDrawColor( c.r, c.g, c.b, 255 )
			surface.DrawRect( cx, y + ch - S( 2 ), cw, S( 2 ) )
		end
		local a = on and 255 or 120
		LBR.DrawClipIcon( cx + S( 4 ), y + math.floor( ( ch - isz ) / 2 ), isz, c, a, n )
		local full = LBR.ClipRoom( ply, id ) < 0.0001
		ptext( "x" .. LBR.ClipText( n ), "LBR_HUD_Small", cx + cw - S( 6 ), y + ch / 2, full and colWarn or Color( c.r, c.g, c.b, a ), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
	end
end

local function drawAmmo( ply )
	if not ply:Alive() then return end
	local wep = ply:GetActiveWeapon()
	if not IsValid( wep ) then return end

	local name = string.upper( wep.GetPrintName and wep:GetPrintName() or wep:GetClass() )
	local clip = wep:Clip1()
	local reserve = ply:GetAmmoCount( LBR.WeaponAmmoID( wep ) )
	local hasAmmo = clip >= 0 or reserve > 0

	local pad = S( 14 )
	surface.SetFont( "LBR_HUD_Small" )
	local nw = surface.GetTextSize( name )
	local w = math.max( S( 250 ), nw + pad * 2 )
	local top = S( CLIPS_H ) // the magazines row on top
	local h = ( hasAmmo and S( 92 ) or S( 40 ) ) + top
	local x, y = ScrW() - S( 24 ) - w, ScrH() - S( 24 ) - h
	panel( x, y, w, h )
	drawClips( ply, wep, x + S( 6 ), y + S( 6 ), w - S( 12 ) )
	surface.SetDrawColor( 255, 255, 255, 25 )
	surface.DrawRect( x + pad, y + top, w - pad * 2, 1 )
	y = y + top
	h = h - top
	ptext( name, "LBR_HUD_Small", x + w - pad, y + S( 12 ), LBR.TierColor( wep, colGold ), TEXT_ALIGN_RIGHT )
	if not hasAmmo then return end

	local by = y + h - S( 10 )
	if clip >= 0 then
		local maxclip = wep:GetMaxClip1()
		local clipCol = ( maxclip > 0 and clip <= maxclip * 0.25 ) and colWarn or colWhite
		surface.SetFont( "LBR_HUD_Med" )
		local rw = surface.GetTextSize( tostring( reserve ) )
		ptext( tostring( reserve ), "LBR_HUD_Med", x + w - pad, by - S( 4 ), colDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM )
		surface.SetDrawColor( 255, 255, 255, 60 )
		surface.DrawRect( x + w - pad - rw - S( 10 ), by - S( 30 ), S( 2 ), S( 24 ) )
		ptext( tostring( clip ), "LBR_HUD_Huge", x + w - pad - rw - S( 18 ), by + S( 4 ), clipCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM )
	else
		ptext( tostring( reserve ), "LBR_HUD_Huge", x + w - pad, by + S( 4 ), colWhite, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM )
	end
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
			draw.SimpleText( dirNames[d], d % 90 == 0 and "LBR_HUD_Med" or "LBR_HUD_Small", px, y + h / 2, fade( alpha ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		else
			surface.SetDrawColor( 255, 255, 255, alpha * 0.6 )
			surface.DrawRect( px - 1, y + h - S( 10 ), 2, S( 8 ) )
			draw.SimpleText( tostring( d ), "LBR_HUD_Tiny", px, y + S( 2 ), fade( alpha * 0.5 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP )
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
	// squad markers placed on the map (cl_map.lua)
	if LBR.Map and LBR.Map.GetPings then
		for _, pg in ipairs( LBR.Map.GetPings() ) do
			marker( pg.pos, pg.col, S( 7 ), units2m( eye:Distance( pg.pos ) ) .. "m" )
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

// centered panel with a big title and an optional line under it
local function centerBox( title, titleFont, col, sub, y )
	surface.SetFont( titleFont )
	local tw, th = surface.GetTextSize( title )
	local sw, sh = 0, 0
	if sub then
		surface.SetFont( "LBR_HUD_Small" )
		sw, sh = surface.GetTextSize( sub )
	end
	local pad = S( 22 )
	local w = math.max( tw, sw ) + pad * 2
	local h = S( 12 ) + th + ( sub and sh + S( 4 ) or 0 ) + S( 12 )
	local x = ScrW() / 2 - w / 2
	panel( x, y, w, h, col )
	ptext( title, titleFont, ScrW() / 2, y + S( 12 ), col, TEXT_ALIGN_CENTER )
	if sub then ptext( sub, "LBR_HUD_Small", ScrW() / 2, y + S( 12 ) + th + S( 4 ), Color( 236, 239, 245 ), TEXT_ALIGN_CENTER ) end
	return h
end

local function drawBanner( lp, spectating, target )
	local state = GetGlobalInt( "state" )
	local now = CurTime()
	local left = GetGlobalFloat( "LBR_PhaseEnd", 0 ) - now
	local title, sub, col

	if state == STATE_NONE then
		if not GetGlobalBool( "LBR_MapReady", true ) then
			title, col = "MAP NOT CONFIGURED", colWarn
			sub = lp:IsAdmin() and "Press F8 to open the map editor, F2 to change map" or "Waiting for an admin to configure this map"
		else
			local need = GetGlobalInt( "LBR_MinPlayers", 2 )
			title, col = "WAITING FOR PLAYERS", colWhite
			sub = #player.GetAll() .. " / " .. need
			if lp:IsAdmin() then
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

	if title then
		centerBox( title, "LBR_HUD_Big", col, sub, S( 96 ) )
	end
	if spectating then
		centerBox( "SPECTATING " .. string.upper( target:Nick() ), "LBR_HUD_Med", colWhite, nil, ScrH() - S( 170 ) )
	end
end

------------------------------------------------------------------------
// Top-right info: alive, kills, zone
------------------------------------------------------------------------

local infoBottom, infoFrame // where the boxes end (the kill feed goes below)

local function drawInfo( lp, ply )
	local x = ScrW() - S( 24 )
	local y = S( 20 )
	local alive = #team.GetPlayers( 2 )
	local kills = ply:GetNW2Int( "LBR_Kills", 0 )

	surface.SetFont( "LBR_HUD_Med" )
	local kw = surface.GetTextSize( tostring( kills ) )
	local aw = surface.GetTextSize( tostring( alive ) )
	local boxH = S( 36 )
	local boxW = S( 24 ) + kw + S( 20 ) + S( 24 ) + aw + S( 30 )
	panel( x - boxW, y, boxW, boxH )

	local my = y + S( 1 ) + boxH / 2
	local cx = x - S( 12 )
	ptext( tostring( kills ), "LBR_HUD_Med", cx, my, colWhite, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
	cx = cx - kw - S( 26 )
	surface.SetDrawColor( colWhite )
	surface.SetMaterial( matSkull )
	surface.DrawTexturedRect( cx, my - S( 11 ), S( 22 ), S( 22 ) )
	cx = cx - S( 12 )
	ptext( tostring( alive ), "LBR_HUD_Med", cx, my, colWhite, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
	cx = cx - aw - S( 24 )
	surface.SetMaterial( matUser )
	surface.DrawTexturedRect( cx, my - S( 9 ), S( 18 ), S( 18 ) )

	y = y + boxH + S( 8 )

	if LBR.IsZoneActive() then
		local radius = LBR.GetZoneRadius()
		local dist = LBR.ZoneDist( ply:GetPos() )
		local toEdge = dist - radius
		local w, h = S( 240 ), S( 62 )
		local zcol = LBR.GetZoneColor and LBR.GetZoneColor() or colZone
		panel( x - w, y, w, h, Color( zcol.r, zcol.g, zcol.b, 255 ) )
		local tl = LBR.GetZoneTimeLeft()
		local wait = LBR.GetZoneStartsIn()
		if wait > 0 then
			ptext( "ZONE STARTS IN", "LBR_HUD_Tiny", x - w + S( 14 ), y + S( 10 ), colDim )
			ptext( fmtTime( wait ), "LBR_HUD_Small", x - S( 14 ), y + S( 8 ), colWhite, TEXT_ALIGN_RIGHT )
		else
			ptext( radius > 0 and "ZONE CLOSING" or "ZONE CLOSED", "LBR_HUD_Tiny", x - w + S( 14 ), y + S( 10 ), colDim )
			if radius > 0 then ptext( fmtTime( tl ), "LBR_HUD_Small", x - S( 14 ), y + S( 8 ), colWhite, TEXT_ALIGN_RIGHT ) end
		end
		if toEdge > 0 then
			ptext( "OUTSIDE: " .. units2m( toEdge ) .. "m to safety", "LBR_HUD_Small", x - w + S( 14 ), y + S( 34 ), colWarn )
		else
			ptext( "SAFE  -  edge " .. units2m( -toEdge ) .. "m", "LBR_HUD_Small", x - w + S( 14 ), y + S( 34 ), colGood )
		end
		y = y + h + S( 8 )
	end

	local ev = GetGlobalFloat( "LBR_EventTime", 0 ) - CurTime()
	if GetGlobalInt( "state" ) == STATE_LIVE and ev > 0 then
		local t = "RANDOM EVENT IN " .. fmtTime( ev )
		surface.SetFont( "LBR_HUD_Tiny" )
		local tw = surface.GetTextSize( t ) + S( 24 )
		panel( x - tw, y, tw, S( 26 ), Color( 255, 140, 40 ) )
		ptext( t, "LBR_HUD_Tiny", x - S( 12 ), y + S( 14 ), colWhite, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
		y = y + S( 26 ) + S( 8 )
	end
	infoBottom, infoFrame = y, FrameNumber()
end

// kill feed (GMod's death notices): under the boxes above, not on top of them
function GM:DrawDeathNotice( x, y )
	if infoBottom and FrameNumber() - ( infoFrame or 0 ) < 5 then
		y = math.max( y, ( infoBottom + S( 6 ) ) / ScrH() )
	end
	return self.BaseClass.DrawDeathNotice( self, x, y )
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
	local x, y = S( 24 ), S( 20 )
	local w, rowH = S( 230 ), S( 40 )
	panel( x, y, w, S( 26 ) + #mates * rowH + S( 4 ) )
	ptext( "SQUAD", "LBR_HUD_Tiny", x + S( 12 ), y + S( 8 ), colGold )
	y = y + S( 26 )
	for _, pl in ipairs( mates ) do
		local alive = pl:Alive() and pl:Team() == 2
		surface.SetDrawColor( 255, 255, 255, 9 )
		surface.DrawRect( x + S( 6 ), y, w - S( 12 ), rowH - S( 4 ) )
		ptext( string.sub( pl:Nick(), 1, 18 ), "LBR_HUD_Tiny", x + S( 14 ), y + S( 4 ), alive and colWhite or colDim )
		if alive then
			local frac = math.Clamp( pl:Health() / math.max( pl:GetMaxHealth(), 1 ), 0, 1 )
			bar( x + S( 14 ), y + S( 22 ), w - S( 28 ), S( 7 ), frac, frac <= 0.25 and colHealthLow or colHealth )
			if pl:Armor() > 0 then
				surface.SetDrawColor( colShield )
				surface.DrawRect( x + S( 14 ), y + S( 30 ), ( w - S( 28 ) ) * math.Clamp( pl:Armor() / 100, 0, 1 ), S( 2 ) )
			end
		elseif pl:Team() == 1 then
			// still in the lobby (round not started, or joined late): not out of the game
			ptext( "IN LOBBY", "LBR_HUD_Tiny", x + w - S( 14 ), y + S( 4 ), colDim, TEXT_ALIGN_RIGHT )
		else
			ptext( "ELIMINATED", "LBR_HUD_Tiny", x + w - S( 14 ), y + S( 4 ), colWarn, TEXT_ALIGN_RIGHT )
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
		centerBox( "YOU ARE OUTSIDE THE SAFE ZONE", "LBR_HUD_Med", colWarn, nil, ScrH() * 0.7 )
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
	local mapOpen = LBR.Map and LBR.Map.open // the map (cl_map.lua) covers the middle of the screen
	if not mapOpen then drawTeamNames( lp ) end
	if not mapOpen then drawCompass( lp ) end
	if not mapOpen then drawBanner( lp, spectating, ply ) end
	drawInfo( lp, ply )
	drawTeam( lp )
	if ( lp:Alive() and lp:Team() ~= 3 ) or spectating then
		drawVitals( ply )
		drawAmmo( ply )
	end
end )

------------------------------------------------------------------------
// Victory sound: a round ends with a winner (the HEV suit jingle of Half-Life 2,
// in the base game), once per round, for everyone
------------------------------------------------------------------------

local winPlayed = false
local winChannel
local WIN_VOLUME = 0.35
hook.Add( "Think", "LBR_WinSound", function()
	if GetGlobalInt( "state", 1 ) ~= STATE_POST then
		winPlayed = false
		return
	end
	if winPlayed or GetGlobalString( "LBR_Winner", "" ) == "" then return end
	winPlayed = true
	// at full volume it was too loud: played as a sound channel at a lower volume
	sound.PlayFile( "sound/music/hl2_song23_suitsong3.mp3", "noplay", function( ch )
		if not IsValid( ch ) then return end
		winChannel = ch // keep a reference, or it can be collected while playing
		ch:SetVolume( WIN_VOLUME )
		ch:Play()
	end )
end )
